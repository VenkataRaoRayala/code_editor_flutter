import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'flutter_preview_runner.dart';
import 'models.dart';

class FlutterSdkService {
  Future<FlutterSdkSnapshot> inspectFlutterSdk(String path) async {
    final candidate = path.trim();
    if (candidate.isEmpty || !_looksLikeSdk(candidate)) {
      return FlutterSdkSnapshot.missing(
        detail: 'Select the Flutter SDK folder that contains bin/flutter.',
      );
    }
    final version = await _readFlutterVersion(candidate);
    return FlutterSdkSnapshot.detected(
      path: candidate,
      version: version ?? 'Flutter SDK found',
    );
  }

  Future<FlutterSdkSnapshot> detect() async {
    final candidates = <String>{};
    final environmentRoot = Platform.environment['FLUTTER_ROOT'];
    if (environmentRoot != null && environmentRoot.trim().isNotEmpty) {
      candidates.add(environmentRoot.trim());
    }

    final pathRoot = await _flutterRootFromPath();
    if (pathRoot != null) {
      candidates.add(pathRoot);
    }

    candidates.addAll(_commonInstallRoots());

    for (final candidate in candidates) {
      if (_looksLikeSdk(candidate)) {
        final version = await _readFlutterVersion(candidate);
        return FlutterSdkSnapshot.detected(
          path: candidate,
          version: version ?? 'Flutter installed',
        );
      }
    }

    return FlutterSdkSnapshot.missing(
      detail: 'No SDK was found on PATH or in common install locations.',
    );
  }

  Future<FlutterSdkSnapshot> installStable(
    String destination, {
    void Function(String message)? onLog,
  }) async {
    try {
      final target = destination.trim();
      if (target.isEmpty) {
        return FlutterSdkSnapshot.error(
          detail: 'Choose a destination before installing Flutter.',
        );
      }

      final targetDirectory = Directory(target);
      if (!targetDirectory.existsSync()) {
        targetDirectory.createSync(recursive: true);
      }

      onLog?.call('Cloning the stable Flutter channel into $target.');
      final process = await Process.start('git', <String>[
        'clone',
        '--depth',
        '1',
        '--branch',
        'stable',
        'https://github.com/flutter/flutter.git',
        target,
      ], runInShell: true);

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.trim().isNotEmpty) {
              onLog?.call(line.trim());
            }
          });

      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.trim().isNotEmpty) {
              onLog?.call(line.trim());
            }
          });

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        return FlutterSdkSnapshot.error(
          detail: 'Git exited with code $exitCode while cloning Flutter.',
        );
      }

      final detected = await detect();
      if (detected.ready) {
        return detected;
      }

      return FlutterSdkSnapshot.detected(
        path: target,
        version: 'Flutter installed to $target',
      );
    } on ProcessException catch (error) {
      return FlutterSdkSnapshot.error(
        detail:
            'Git is not available or the network request failed: ${error.message}',
      );
    } catch (error) {
      return FlutterSdkSnapshot.error(
        detail: 'Unexpected install failure: $error',
      );
    }
  }

  bool _looksLikeSdk(String root) {
    final flutterExecutable = File(_flutterExecutablePath(root));
    final flutterTools = Directory(
      _joinPath(root, 'packages', 'flutter_tools'),
    );
    return flutterExecutable.existsSync() && flutterTools.existsSync();
  }

  Iterable<String> _commonInstallRoots() {
    final home = _homeDirectory();
    return <String>[
      if (Platform.isMacOS) ...<String>[
        _joinPath(home, 'flutter'),
        _joinPath(home, 'development', 'flutter'),
        '/opt/flutter',
      ],
      if (Platform.isWindows) ...<String>[
        _joinPath(home, 'flutter'),
        _joinPath(home, 'development', 'flutter'),
        r'C:\flutter',
        r'C:\src\flutter',
      ],
      if (!Platform.isMacOS && !Platform.isWindows) ...<String>[
        _joinPath(home, 'flutter'),
        _joinPath(home, 'development', 'flutter'),
      ],
    ];
  }

  Future<String?> _flutterRootFromPath() async {
    try {
      final command = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(command, <String>[
        'flutter',
      ], runInShell: true);

      if (result.exitCode != 0) {
        return null;
      }

      final stdoutText = result.stdout.toString().trim();
      if (stdoutText.isEmpty) {
        return null;
      }

      final firstLine = stdoutText.split(RegExp(r'\r?\n')).first.trim();
      if (firstLine.isEmpty) {
        return null;
      }

      final executable = File(firstLine);
      return executable.parent.parent.path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readFlutterVersion(String root) async {
    final flutterExecutable = _flutterExecutablePath(root);
    if (!File(flutterExecutable).existsSync()) {
      return null;
    }

    try {
      final result = await Process.run(flutterExecutable, <String>[
        '--version',
      ], runInShell: true);

      final output = '${result.stdout}\n${result.stderr}'.trim();
      if (output.isEmpty) {
        return null;
      }

      return output.split(RegExp(r'\r?\n')).first.trim();
    } catch (_) {
      return null;
    }
  }
}

class EditorController extends ChangeNotifier {
  EditorController()
    : _sdkService = FlutterSdkService(),
      _previewRunner = FlutterPreviewRunner(),
      _projectName = 'Starter Flow',
      _workspacePath = _defaultWorkspacePath('Starter Flow'),
      _installPath = _defaultInstallPath() {
    _resetStarterWorkspace();
  }

  final FlutterSdkService _sdkService;
  final FlutterPreviewRunner _previewRunner;
  final List<WorkspaceFile> _files = <WorkspaceFile>[];
  final List<ActivityEntry> _activity = <ActivityEntry>[];
  final Set<String> _folders = <String>{};
  final Set<String> _projectFilePaths = <String>{};
  final List<String> _openFilePaths = <String>[];

  FlutterSdkSnapshot _sdkSnapshot = const FlutterSdkSnapshot.unknown();
  String _projectName;
  String _workspacePath;
  String _installPath;
  int _activeFileIndex = 0;
  int _previewStageIndex = 0;
  double _previewProgress = 0;
  bool _isSimulating = false;
  Timer? _previewSyncTimer;

  FlutterSdkSnapshot get sdkSnapshot => _sdkSnapshot;
  String get projectName => _projectName;
  String get workspacePath => _workspacePath;
  String get installPath => _installPath;
  int get activeFileIndex => _activeFileIndex;
  int get previewStageIndex => _previewStageIndex;
  double get previewProgress => _previewProgress;
  bool get isSimulating => _isSimulating;
  FlutterPreviewRunner get previewRunner => _previewRunner;
  List<WorkspaceFile> get files => List.unmodifiable(_files);
  List<String> get folders => List.unmodifiable(_folders.toList()..sort());
  List<String> get projectFilePaths =>
      List.unmodifiable(_projectFilePaths.toList()..sort());
  List<WorkspaceFile> get openFiles => List.unmodifiable(
    _openFilePaths
        .map((path) => _files.where((file) => file.path == path).firstOrNull)
        .whereType<WorkspaceFile>(),
  );
  List<ActivityEntry> get activity => List.unmodifiable(_activity);
  List<FlowStage> get stages => kDemoFlowStages;
  FlowStage get currentStage =>
      stages[_previewStageIndex.clamp(0, stages.length - 1).toInt()];
  WorkspaceFile? get activeFile {
    if (_files.isEmpty) {
      return null;
    }
    return _files[_activeFileIndex.clamp(0, _files.length - 1).toInt()];
  }

  int get dirtyCount => _files.where((file) => file.dirty).length;

  void setPreviewStage(int index) {
    if (stages.isEmpty) {
      return;
    }

    _previewStageIndex = index.clamp(0, stages.length - 1).toInt();
    _previewProgress = (_previewStageIndex + 1) / stages.length;

    notifyListeners();
  }

  void nextPreviewStage() {
    if (stages.isEmpty) {
      return;
    }

    final nextIndex = (_previewStageIndex + 1) % stages.length;
    setPreviewStage(nextIndex);
  }

  Future<void> bootstrap() async {
    _pushActivity(
      'Searching for Flutter',
      'The editor is checking PATH and common install locations.',
      Icons.manage_search_rounded,
      const Color(0xFF2563EB),
    );
    _sdkSnapshot = const FlutterSdkSnapshot.unknown();
    notifyListeners();

    final detected = await _sdkService.detect();
    _sdkSnapshot = detected;
    _pushActivity(
      detected.ready ? 'Flutter detected' : 'Flutter not found',
      detected.detail,
      detected.ready ? Icons.check_circle_rounded : Icons.info_outline_rounded,
      detected.ready ? const Color(0xFF16A34A) : const Color(0xFFD97706),
    );
    notifyListeners();
  }

  Future<void> setFlutterSdkPath(String path) async {
    _sdkSnapshot = await _sdkService.inspectFlutterSdk(path);
    notifyListeners();
  }

  void setProjectName(String value) {
    final next = value.trim();
    if (next.isEmpty) {
      return;
    }
    _projectName = next;
    notifyListeners();
  }

  void setWorkspacePath(String value) {
    _workspacePath = value.trim();
    notifyListeners();
  }

  void setInstallPath(String value) {
    _installPath = value.trim();
    notifyListeners();
  }

  void selectFile(int index) {
    if (_files.isEmpty) {
      return;
    }
    _activeFileIndex = index.clamp(0, _files.length - 1).toInt();
    _openTab(_files[_activeFileIndex].path);
    notifyListeners();
  }

  void _openTab(String path) {
    if (!_openFilePaths.contains(path)) {
      _openFilePaths.add(path);
    }
  }

  void _registerParentFolders(String filePath) {
    final segments = filePath.split('/');
    var folder = '';
    for (final segment in segments.take(segments.length - 1)) {
      folder = folder.isEmpty ? segment : '$folder/$segment';
      _folders.add(folder);
    }
  }

  bool selectFilePath(String path) {
    final index = _files.indexWhere((file) => file.path == path);
    if (index >= 0) {
      selectFile(index);
      return true;
    }
    return false;
  }

  void closeFileTab(String path) {
    final tabIndex = _openFilePaths.indexOf(path);
    if (tabIndex < 0) {
      return;
    }
    _openFilePaths.removeAt(tabIndex);
    if (_openFilePaths.isEmpty) {
      _activeFileIndex = 0;
    } else if (activeFile?.path == path) {
      final nextIndex = (tabIndex - 1).clamp(0, _openFilePaths.length - 1);
      final nextPath = _openFilePaths[nextIndex];
      _activeFileIndex = _files.indexWhere((file) => file.path == nextPath);
    }
    notifyListeners();
  }

  Future<void> loadWorkspace(String path) async {
    final root = Directory(path.trim()).absolute;
    if (!root.existsSync()) {
      throw StateError('The selected project folder does not exist.');
    }
    if (!File(_joinPath(root.path, 'pubspec.yaml')).existsSync()) {
      throw StateError(
        'Choose a Flutter project folder containing pubspec.yaml.',
      );
    }

    _workspacePath = root.path;
    _projectName = root.uri.pathSegments.where((part) => part.isNotEmpty).last;
    _files.clear();
    _folders.clear();
    _projectFilePaths.clear();
    _openFilePaths.clear();
    final pendingDirectories = <Directory>[root];
    while (pendingDirectories.isNotEmpty) {
      final directory = pendingDirectories.removeLast();
      await for (final entity in directory.list(followLinks: false)) {
        final relative = _relativePath(root.path, entity.path);
        final name = relative.split('/').last;
        if (entity is Directory) {
          if (_ignoredDirectoryNames.contains(name)) {
            continue;
          }
          _folders.add(relative);
          pendingDirectories.add(entity);
        } else if (entity is File && _isEditableTextPath(relative)) {
          _projectFilePaths.add(relative);
          try {
            _files.add(
              WorkspaceFile(
                path: relative,
                content: await entity.readAsString(),
              ),
            );
          } on FileSystemException {
            // Skip files that are not readable as text.
          } on FormatException {
            // Binary or malformed files stay in the project tree, not editor tabs.
          }
        } else if (entity is File) {
          _projectFilePaths.add(relative);
        }
      }
    }
    _files.sort((a, b) => a.path.compareTo(b.path));
    _activeFileIndex = _files.indexWhere(
      (file) => file.path == 'lib/main.dart',
    );
    if (_activeFileIndex < 0) {
      _activeFileIndex = _files.indexWhere(
        (file) => file.path == 'pubspec.yaml',
      );
    }
    if (_activeFileIndex < 0 && _files.isNotEmpty) {
      _activeFileIndex = 0;
    }
    if (activeFile != null) {
      _openTab(activeFile!.path);
    }
    _pushActivity(
      'Project opened',
      '${_files.length} text files loaded from ${root.path}.',
      Icons.folder_open_rounded,
      const Color(0xFF2563EB),
    );
    notifyListeners();
  }

  Future<void> addFolder(String path) async {
    final normalized = _normalizeWorkspaceRelativePath(path);
    if (normalized.isEmpty) {
      throw StateError('Enter a folder name.');
    }
    await Directory(
      _joinPath(_workspacePath, normalized),
    ).create(recursive: true);
    var current = '';
    for (final segment in normalized.split('/')) {
      current = current.isEmpty ? segment : '$current/$segment';
      _folders.add(current);
    }
    notifyListeners();
  }

  void updateActiveFileContent(String content) {
    final file = activeFile;
    if (file == null) {
      return;
    }
    file.content = content;
    file.dirty = true;
    notifyListeners();
    if (_previewRunner.isRunning) {
      _previewSyncTimer?.cancel();
      _previewSyncTimer = Timer(const Duration(milliseconds: 150), () {
        unawaited(
          _previewRunner.syncFiles(
            projectPath: _previewRunner.projectPath ?? _workspacePath,
            files: _files,
          ),
        );
      });
    }
  }

  Future<void> startLivePreview() async {
    await saveWorkspace();
    var sdk = _sdkSnapshot;
    if (!sdk.ready || sdk.path == null) {
      sdk = await _sdkService.detect();
      _sdkSnapshot = sdk;
      notifyListeners();
    }
    final root = sdk.path;
    if (root == null) {
      _previewRunner.fail(sdk.detail);
      return;
    }
    await _previewRunner.start(
      flutterRoot: root,
      projectPath: _workspacePath,
      files: _files,
    );
  }

  Future<void> warmupLivePreview() async {
    if (!_previewRunner.isRunning) return;
    for (var pass = 0; pass < 2; pass++) {
      await _previewRunner.syncFiles(
        projectPath: _previewRunner.projectPath ?? _workspacePath,
        files: _files,
      );
    }
  }

  Future<void> stopLivePreview() => _previewRunner.stop();

  @override
  void dispose() {
    _previewSyncTimer?.cancel();
    _previewRunner.dispose();
    super.dispose();
  }

  void addFile(String path, String content) {
    final cleanedPath = _normalizeWorkspaceRelativePath(path);
    if (cleanedPath.isEmpty) {
      return;
    }

    final existingIndex = _files.indexWhere((file) => file.path == cleanedPath);
    if (existingIndex >= 0) {
      _files[existingIndex]
        ..content = content
        ..dirty = true;
      _activeFileIndex = existingIndex;
    } else {
      _files.add(
        WorkspaceFile(
          path: cleanedPath,
          content: content,
          generated: false,
          dirty: true,
        ),
      );
      _activeFileIndex = _files.length - 1;
    }
    _openTab(cleanedPath);
    _registerParentFolders(cleanedPath);
    _projectFilePaths.add(cleanedPath);

    _pushActivity(
      'Added $cleanedPath',
      'The file is ready for editing and export.',
      Icons.note_add_rounded,
      const Color(0xFF0F766E),
    );
    notifyListeners();
  }

  void removeFileAt(int index) {
    if (index < 0 || index >= _files.length) {
      return;
    }

    final removed = _files.removeAt(index);
    _openFilePaths.remove(removed.path);
    _projectFilePaths.remove(removed.path);
    if (_files.isEmpty) {
      _activeFileIndex = 0;
    } else {
      _activeFileIndex = index.clamp(0, _files.length - 1).toInt();
    }

    _pushActivity(
      'Removed ${removed.path}',
      'The workspace stays light and easier to scan.',
      Icons.delete_outline_rounded,
      const Color(0xFFEF4444),
    );
    notifyListeners();
  }

  void generateStarterWorkspace() {
    _projectName = 'Starter Flow';
    _workspacePath = _defaultWorkspacePath(_projectName);
    _resetStarterWorkspace();
    _pushActivity(
      'Starter workspace loaded',
      'A calm Flutter example is ready for quick edits.',
      Icons.auto_awesome_rounded,
      const Color(0xFF7C3AED),
    );
    notifyListeners();
  }

  Future<void> installFlutter() async {
    if (_installPath.trim().isEmpty) {
      _installPath = _defaultInstallPath();
    }

    _sdkSnapshot = FlutterSdkSnapshot.installing(
      detail: 'Cloning the stable channel into $_installPath.',
      progress: 0.1,
    );
    _pushActivity(
      'Installing Flutter',
      'This may take a little while on the first run.',
      Icons.downloading_rounded,
      const Color(0xFF2563EB),
    );
    notifyListeners();

    final installed = await _sdkService.installStable(
      _installPath,
      onLog: (message) {
        _pushActivity(
          'Flutter install',
          message,
          Icons.terminal_rounded,
          const Color(0xFF64748B),
        );
        notifyListeners();
      },
    );

    _sdkSnapshot = installed;
    if (installed.ready) {
      _installPath = installed.path ?? _installPath;
      _pushActivity(
        'Flutter installed',
        installed.path ?? 'The SDK is ready to use.',
        Icons.check_circle_rounded,
        const Color(0xFF16A34A),
      );
    } else {
      _pushActivity(
        'Flutter install failed',
        installed.detail,
        Icons.error_outline_rounded,
        const Color(0xFFEF4444),
      );
    }
    notifyListeners();
  }

  Future<void> saveWorkspace() async {
    final targetPath = _workspacePath.trim().isEmpty
        ? _defaultWorkspacePath(_projectName)
        : _workspacePath.trim();
    final targetDirectory = Directory(targetPath);
    if (!targetDirectory.existsSync()) {
      targetDirectory.createSync(recursive: true);
    }

    for (final file in _files) {
      final destination = File(_joinPath(targetPath, file.path));
      final parent = destination.parent;
      if (!parent.existsSync()) {
        parent.createSync(recursive: true);
      }
      destination.writeAsStringSync(file.content);
      file.dirty = false;
    }

    _workspacePath = targetPath;
    _pushActivity(
      'Workspace saved',
      'Files were written to disk at $targetPath.',
      Icons.save_outlined,
      const Color(0xFF16A34A),
    );
    notifyListeners();
  }

  Future<void> runFullFlow() async {
    if (_isSimulating) {
      return;
    }

    if (_files.isEmpty) {
      generateStarterWorkspace();
    }

    _isSimulating = true;
    _previewStageIndex = 0;
    _previewProgress = 0;
    _pushActivity(
      'Running the full flow',
      'The editor is stepping through setup, preview, and export.',
      Icons.play_arrow_rounded,
      const Color(0xFF2563EB),
    );
    notifyListeners();

    for (var index = 0; index < stages.length; index++) {
      _previewStageIndex = index;
      _previewProgress = (index + 1) / stages.length;
      _pushActivity(
        stages[index].title,
        stages[index].subtitle,
        stages[index].icon,
        stages[index].accent,
      );
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 720));
    }

    _isSimulating = false;
    _pushActivity(
      'Flow complete',
      'The workspace is ready for one more edit or a clean export.',
      Icons.check_circle_rounded,
      const Color(0xFF16A34A),
    );
    notifyListeners();
  }

  void _resetStarterWorkspace() {
    _files
      ..clear()
      ..addAll(<WorkspaceFile>[
        WorkspaceFile(
          path: 'pubspec.yaml',
          content: _starterPubspec,
          generated: true,
          dirty: false,
        ),
        WorkspaceFile(
          path: 'lib/main.dart',
          content: _starterMainDart,
          generated: true,
          dirty: false,
        ),
        WorkspaceFile(
          path: 'lib/app.dart',
          content: _starterAppDart,
          generated: true,
          dirty: false,
        ),
        WorkspaceFile(
          path: 'lib/screens/flow_home.dart',
          content: _starterFlowHomeDart,
          generated: true,
          dirty: false,
        ),
        WorkspaceFile(
          path: 'lib/widgets/section_card.dart',
          content: _starterSectionCardDart,
          generated: true,
          dirty: false,
        ),
      ]);
    _openFilePaths
      ..clear()
      ..add('lib/screens/flow_home.dart');
    _projectFilePaths
      ..clear()
      ..addAll(_files.map((file) => file.path));
    _folders
      ..clear()
      ..addAll(<String>['lib', 'lib/screens', 'lib/widgets']);
    _activeFileIndex = _files.indexWhere(
      (file) => file.path == 'lib/screens/flow_home.dart',
    );
    if (_activeFileIndex < 0) {
      _activeFileIndex = 0;
    }
    _previewStageIndex = 0;
    _previewProgress = 0;
  }

  void _pushActivity(
    String message,
    String detail,
    IconData icon,
    Color accent,
  ) {
    _activity.insert(
      0,
      ActivityEntry(
        timestamp: DateTime.now(),
        message: message,
        detail: detail,
        icon: icon,
        accent: accent,
      ),
    );
    if (_activity.length > 8) {
      _activity.removeRange(8, _activity.length);
    }
  }
}

String _homeDirectory() {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home != null && home.trim().isNotEmpty) {
    return home.trim();
  }
  return Directory.current.path;
}

String _defaultInstallPath() {
  return _joinPath(_homeDirectory(), 'flutter');
}

String _defaultWorkspacePath(String projectName) {
  return _joinPath(
    _homeDirectory(),
    'Documents',
    'flutter-visual-ui-editor',
    _slugify(projectName),
  );
}

const Set<String> _ignoredDirectoryNames = <String>{
  '.dart_tool',
  '.git',
  'build',
  'node_modules',
  'Pods',
  'ephemeral',
  'DerivedData',
};

const Set<String> _editableTextExtensions = <String>{
  'arb',
  'c',
  'cc',
  'cmake',
  'cpp',
  'css',
  'dart',
  'gradle',
  'h',
  'html',
  'java',
  'js',
  'json',
  'kt',
  'lock',
  'md',
  'm',
  'mm',
  'plist',
  'properties',
  'sh',
  'sql',
  'swift',
  'toml',
  'ts',
  'txt',
  'xml',
  'yaml',
  'yml',
};

bool _isEditableTextPath(String path) {
  final fileName = path.split('/').last;
  if (fileName == '.gitignore' ||
      fileName == '.metadata' ||
      fileName == '.flutter-version' ||
      fileName == 'Dockerfile' ||
      fileName == 'Makefile') {
    return true;
  }
  final dot = fileName.lastIndexOf('.');
  return dot >= 0 &&
      _editableTextExtensions.contains(
        fileName.substring(dot + 1).toLowerCase(),
      );
}

String _relativePath(String root, String path) {
  final normalizedRoot = Directory(root).absolute.path;
  final normalizedPath = File(path).absolute.path;
  final prefix = normalizedRoot.endsWith(Platform.pathSeparator)
      ? normalizedRoot
      : '$normalizedRoot${Platform.pathSeparator}';
  if (!normalizedPath.startsWith(prefix)) {
    throw StateError('The selected file is outside the project folder.');
  }
  return normalizedPath.substring(prefix.length).replaceAll('\\', '/');
}

String _normalizeWorkspaceRelativePath(String path) {
  final normalized = path.trim().replaceAll('\\', '/');
  final segments = normalized.split('/');
  if (normalized.startsWith('/') ||
      segments.any((segment) => segment == '..' || segment.isEmpty)) {
    throw StateError('Use a relative path inside the project folder.');
  }
  return segments.where((segment) => segment != '.').join('/');
}

String _slugify(String value) {
  final cleaned = value.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '-',
  );
  return cleaned.replaceAll(RegExp(r'^-+|-+$'), '');
}

String _joinPath(
  String first, [
  String? second,
  String? third,
  String? fourth,
]) {
  final parts = <String>[first];
  if (second != null) {
    parts.add(second);
  }
  if (third != null) {
    parts.add(third);
  }
  if (fourth != null) {
    parts.add(fourth);
  }
  final separator = Platform.pathSeparator;
  return parts
      .map(
        (part) => part.replaceAll('/', separator).replaceAll('\\', separator),
      )
      .join(separator)
      .replaceAll(RegExp('${RegExp.escape(separator)}+'), separator);
}

String _flutterExecutablePath(String root) {
  final executableName = Platform.isWindows ? 'flutter.bat' : 'flutter';
  return _joinPath(root, 'bin', executableName);
}

const String _starterPubspec = '''
name: starter_flow
description: A lightweight Flutter starter generated by Flutter Visual UI Editor.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter

flutter:
  uses-material-design: true
''';

const String _starterMainDart = '''
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  runApp(const FlowDemoApp());
}
''';

const String _starterAppDart = '''
import 'package:flutter/material.dart';

import 'screens/flow_home.dart';

class FlowDemoApp extends StatelessWidget {
  const FlowDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flow Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF116D6E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const FlowHomeScreen(),
    );
  }
}
''';

const String _starterFlowHomeDart = '''
import 'package:flutter/material.dart';

import '../widgets/section_card.dart';

class FlowHomeScreen extends StatelessWidget {
  const FlowHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SectionCard(
                    title: 'Build the flow',
                    subtitle: 'A calm starter page for your first preview.',
                    icon: Icons.auto_awesome_rounded,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
''';

const String _starterSectionCardDart = '''
import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14223A4B),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE7F6F2),
            child: Icon(icon, color: const Color(0xFF116D6E)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
''';
