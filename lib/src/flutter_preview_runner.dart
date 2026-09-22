import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'models.dart';

enum PreviewRunnerState { stopped, preparing, starting, running, failed }

class FlutterPreviewRunner extends ChangeNotifier {
  Process? _process;
  PreviewRunnerState _state = PreviewRunnerState.stopped;
  String _message = 'Start the web preview to render this workspace inline.';
  final List<String> _output = <String>[];
  String? _projectPath;
  Uri? _previewUri;
  int _previewRevision = 0;
  bool _syncing = false;
  bool _syncPending = false;
  Completer<void>? _pendingReload;

  PreviewRunnerState get state => _state;
  String get message => _message;
  List<String> get output => List.unmodifiable(_output);
  bool get isRunning => _process != null;
  Uri? get previewUri => _previewUri;
  String? get projectPath => _projectPath;
  int get previewRevision => _previewRevision;

  void fail(String message) {
    _state = PreviewRunnerState.failed;
    _message = message;
    _appendOutput(message);
    notifyListeners();
  }

  Future<void> start({
    required String flutterRoot,
    required String projectPath,
    required List<WorkspaceFile> files,
  }) async {
    if (_state == PreviewRunnerState.preparing ||
        _state == PreviewRunnerState.starting) {
      return;
    }
    if (_process != null) {
      if (_projectPath == projectPath) {
        await syncFiles(projectPath: projectPath, files: files);
        return;
      }
      await stop();
    }

    _state = PreviewRunnerState.preparing;
    _message = 'Saving workspace and preparing Flutter web…';
    _projectPath = projectPath;
    _previewUri = null;
    _output.clear();
    notifyListeners();

    try {
      await _writeFiles(projectPath, files);
      final webDirectory = Directory(_join(projectPath, 'web'));
      if (!webDirectory.existsSync()) {
        final create = await Process.run(
          _flutterExecutable(flutterRoot),
          <String>[
            'create',
            '--platforms=web',
            '--project-name',
            _projectNameFrom(projectPath),
            '.',
          ],
          workingDirectory: projectPath,
          runInShell: Platform.isWindows,
        );
        _appendCommandResult(create);
        if (create.exitCode != 0) {
          throw StateError(
            'Flutter could not prepare web support (exit ${create.exitCode}).',
          );
        }
        await _writeFiles(projectPath, files);
      }

      final port = await _choosePort();
      final uri = Uri(scheme: 'http', host: '127.0.0.1', port: port);
      _state = PreviewRunnerState.starting;
      _message = 'Building the Flutter web preview…';
      notifyListeners();

      final process = await Process.start(
        _flutterExecutable(flutterRoot),
        <String>[
          'run',
          '-d',
          'web-server',
          '--web-hostname=127.0.0.1',
          '--web-port=$port',
        ],
        workingDirectory: projectPath,
        runInShell: Platform.isWindows,
      );
      _process = process;
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleOutput);
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleOutput);
      process.exitCode.then((code) {
        if (_process == process) {
          _process = null;
          _previewUri = null;
          _pendingReload?.completeError(
            StateError('Flutter web server exited with code $code.'),
          );
          _pendingReload = null;
          _state = code == 0
              ? PreviewRunnerState.stopped
              : PreviewRunnerState.failed;
          _message = code == 0
              ? 'Web preview stopped.'
              : 'Flutter web server exited with code $code.';
          notifyListeners();
        }
      });
      await _waitForServer(process, uri);
    } catch (error) {
      _state = PreviewRunnerState.failed;
      _message = error.toString();
      _appendOutput(error.toString());
      notifyListeners();
    }
  }

  Future<void> syncFiles({
    required String projectPath,
    required List<WorkspaceFile> files,
  }) async {
    if (_process == null) {
      return;
    }
    if (_syncing) {
      _syncPending = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncPending = false;
        await _writeFiles(projectPath, files);
        final process = _process;
        if (process == null) {
          return;
        }
        final reload = Completer<void>();
        _pendingReload = reload;
        _state = PreviewRunnerState.starting;
        _message = 'Applying edits with Flutter web hot reload…';
        notifyListeners();
        process.stdin.writeln('r');
        await process.stdin.flush();
        await reload.future.timeout(const Duration(seconds: 90));
        if (_pendingReload == reload) {
          _pendingReload = null;
        }
        _previewRevision++;
        _state = PreviewRunnerState.running;
        _message = 'Flutter recompiled the app; refreshing the inline preview.';
        notifyListeners();
      } while (_syncPending);
    } catch (error) {
      _pendingReload = null;
      _state = PreviewRunnerState.failed;
      _message = error.toString();
      _appendOutput(error.toString());
      notifyListeners();
    } finally {
      _syncing = false;
    }
  }

  Future<void> stop() async {
    final process = _process;
    if (process == null) {
      return;
    }
    _message = 'Stopping web preview…';
    notifyListeners();
    try {
      process.stdin.writeln('q');
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
    } catch (_) {
      process.kill();
    }
    if (_process == process) {
      _process = null;
      _previewUri = null;
      _state = PreviewRunnerState.stopped;
      _message = 'Web preview stopped.';
      notifyListeners();
    }
  }

  Future<void> _waitForServer(Process process, Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      for (var attempt = 0; attempt < 180; attempt++) {
        if (_process != process) {
          return;
        }
        try {
          final request = await client
              .getUrl(uri)
              .timeout(const Duration(seconds: 2));
          final response = await request.close().timeout(
            const Duration(seconds: 2),
          );
          final contentType = response.headers.contentType?.mimeType;
          final body = await response.transform(utf8.decoder).join();
          if (response.statusCode == HttpStatus.ok &&
              contentType == 'text/html' &&
              body.toLowerCase().contains('<html')) {
            _previewUri = uri;
            _previewRevision++;
            _state = PreviewRunnerState.running;
            _message = 'Flutter web preview is ready in this panel.';
            notifyListeners();
            return;
          }
        } catch (_) {
          // Keep polling until the initial Flutter web build is available.
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (_process == process) {
        _state = PreviewRunnerState.failed;
        _message = 'Timed out waiting for the Flutter web preview build.';
        notifyListeners();
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<int> _choosePort() async {
    final random = math.Random.secure();
    for (var attempt = 0; attempt < 32; attempt++) {
      final port = 30000 + random.nextInt(10000);
      try {
        final socket = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          port,
        );
        await socket.close();
        return port;
      } on SocketException {
        continue;
      }
    }
    throw StateError('Could not find an available localhost preview port.');
  }

  void _handleOutput(String line) {
    final trimmed = line.trimRight();
    if (trimmed.isEmpty) {
      return;
    }
    final normalized = trimmed.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
    final lower = normalized.toLowerCase();

    if (lower.contains('recompile complete. no client connected') ||
        lower.contains('recompile complete. page requires refresh') ||
        lower.contains('reloaded ')) {
      final pending = _pendingReload;
      if (pending != null && !pending.isCompleted) {
        pending.complete();
      }
      return;
    }
    if (lower.contains('failed to recompile application')) {
      final pending = _pendingReload;
      if (pending != null && !pending.isCompleted) {
        pending.completeError(StateError(normalized));
      }
    }

    _appendOutput(normalized);
    if (lower.contains('error') &&
        !lower.contains('0 error') &&
        !lower.contains('0 errors')) {
      _message = normalized;
    }
    notifyListeners();
  }

  void _appendCommandResult(ProcessResult result) {
    _appendOutput('${result.stdout}\n${result.stderr}');
  }

  void _appendOutput(String value) {
    for (final line in const LineSplitter().convert(value)) {
      final cleaned = line.trimRight();
      if (cleaned.isNotEmpty) {
        _output.add(cleaned);
      }
    }
    if (_output.length > 80) {
      _output.removeRange(0, _output.length - 80);
    }
  }

  Future<void> _writeFiles(
    String projectPath,
    List<WorkspaceFile> files,
  ) async {
    final root = Directory(projectPath).absolute;
    await root.create(recursive: true);
    for (final workspaceFile in files) {
      final relative = workspaceFile.path.replaceAll('\\', '/');
      final parts = relative.split('/');
      if (relative.startsWith('/') ||
          parts.any((part) => part == '..' || part.isEmpty)) {
        throw StateError('Invalid workspace file path: ${workspaceFile.path}');
      }
      final destination = File(
        _join(root.path, parts.join(Platform.pathSeparator)),
      );
      await destination.parent.create(recursive: true);
      await destination.writeAsString(workspaceFile.content);
    }
  }

  @override
  void dispose() {
    _process?.kill();
    _process = null;
    super.dispose();
  }
}

String _flutterExecutable(String root) =>
    _join(root, 'bin', Platform.isWindows ? 'flutter.bat' : 'flutter');

String _projectNameFrom(String path) {
  final leaf = path
      .split(Platform.pathSeparator)
      .where((part) => part.isNotEmpty)
      .last;
  final name = leaf.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  return RegExp(r'^[a-z]').hasMatch(name) ? name : 'preview_$name';
}

String _join(String first, String second, [String? third]) => <String>[
  first,
  second,
  ?third,
].join(Platform.pathSeparator);
