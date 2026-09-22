import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'editor_controller.dart';
import 'flutter_preview_runner.dart';
import 'live_preview.dart';
import 'models.dart';

class EditorHomePage extends StatefulWidget {
  const EditorHomePage({
    super.key,
    required this.controller,
    this.bootstrap = true,
  });

  final EditorController controller;
  final bool bootstrap;

  @override
  State<EditorHomePage> createState() => _EditorHomePageState();
}

class _EditorHomePageState extends State<EditorHomePage> {
  late final EditorController _controller;
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _workspacePathController =
      TextEditingController();
  final TextEditingController _installPathController = TextEditingController();
  final TextEditingController _sdkPathController = TextEditingController();
  final TextEditingController _editorController = TextEditingController();
  String? _loadedFilePath;
  String? _setupError;
  bool _setupComplete = false;
  bool _setupBusy = false;
  bool _showPreviewPanel = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.addListener(_syncTextControllers);
    _syncTextControllers();
    if (widget.bootstrap) {
      unawaited(_controller.bootstrap());
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncTextControllers);
    _projectNameController.dispose();
    _workspacePathController.dispose();
    _installPathController.dispose();
    _sdkPathController.dispose();
    _editorController.dispose();
    super.dispose();
  }

  void _syncTextControllers() {
    if (_projectNameController.text != _controller.projectName) {
      _projectNameController.text = _controller.projectName;
      _projectNameController.selection = TextSelection.collapsed(
        offset: _projectNameController.text.length,
      );
    }

    if (_workspacePathController.text != _controller.workspacePath) {
      _workspacePathController.text = _controller.workspacePath;
      _workspacePathController.selection = TextSelection.collapsed(
        offset: _workspacePathController.text.length,
      );
    }

    if (_installPathController.text != _controller.installPath) {
      _installPathController.text = _controller.installPath;
      _installPathController.selection = TextSelection.collapsed(
        offset: _installPathController.text.length,
      );
    }

    final detectedSdkPath = _controller.sdkSnapshot.path;
    if (_sdkPathController.text.isEmpty && detectedSdkPath != null) {
      _sdkPathController.text = detectedSdkPath;
    }

    final activeFile = _controller.activeFile;
    if (activeFile == null) {
      if (_editorController.text.isNotEmpty) {
        _editorController.clear();
      }
      _loadedFilePath = null;
      return;
    }

    final shouldLoadFile =
        _loadedFilePath != activeFile.path ||
        _editorController.text != activeFile.content;
    if (shouldLoadFile) {
      _loadedFilePath = activeFile.path;
      _editorController.value = TextEditingValue(
        text: activeFile.content,
        selection: TextSelection.collapsed(offset: activeFile.content.length),
      );
    }
  }

  Widget _buildStartupSetup(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF171922),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF20222C), Color(0xFF111318)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _SectionShell(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF007ACC),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.code_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Set up your Flutter workspace',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: const Color(0xFFF3F4F6),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Choose your Flutter SDK and project folder to grant the editor access.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF9CA3AF),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _sdkPathController,
                        decoration: InputDecoration(
                          labelText: 'Flutter SDK folder',
                          hintText: '/path/to/flutter',
                          prefixIcon: const Icon(Icons.flutter_dash_rounded),
                          suffixIcon: IconButton(
                            tooltip: 'Choose Flutter SDK folder',
                            onPressed: _setupBusy ? null : _chooseSdkFolder,
                            icon: const Icon(Icons.folder_open_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _workspacePathController,
                        decoration: InputDecoration(
                          labelText: 'Flutter project folder',
                          hintText: '/path/to/project',
                          prefixIcon: const Icon(Icons.folder_rounded),
                          suffixIcon: IconButton(
                            tooltip: 'Choose project folder',
                            onPressed: _setupBusy ? null : _chooseProjectFolder,
                            icon: const Icon(Icons.folder_open_rounded),
                          ),
                        ),
                      ),
                      if (_setupError != null) ...<Widget>[
                        const SizedBox(height: 14),
                        Text(
                          _setupError!,
                          style: const TextStyle(color: Color(0xFFFCA5A5)),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _setupBusy ? null : _completeSetup,
                          icon: _setupBusy
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                          label: Text(
                            _setupBusy ? 'Opening project…' : 'Open project',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseSdkFolder() async {
    final path = await getDirectoryPath(
      initialDirectory: _sdkPathController.text.trim().isEmpty
          ? null
          : _sdkPathController.text.trim(),
      confirmButtonText: 'Use Flutter SDK',
    );
    if (path != null && mounted) {
      setState(() => _sdkPathController.text = path);
    }
  }

  Future<void> _chooseProjectFolder() async {
    final path = await getDirectoryPath(
      initialDirectory: _workspacePathController.text.trim().isEmpty
          ? null
          : _workspacePathController.text.trim(),
      confirmButtonText: 'Open project',
    );
    if (path != null && mounted) {
      setState(() => _workspacePathController.text = path);
    }
  }

  Future<void> _completeSetup() async {
    setState(() {
      _setupBusy = true;
      _setupError = null;
    });
    try {
      await _controller.setFlutterSdkPath(_sdkPathController.text);
      if (!_controller.sdkSnapshot.ready) {
        throw StateError(_controller.sdkSnapshot.detail);
      }
      await _controller.loadWorkspace(_workspacePathController.text);
      if (!mounted) {
        return;
      }
      setState(() => _setupComplete = true);
    } catch (error) {
      if (mounted) {
        setState(() => _setupError = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _setupBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_setupComplete) {
          return _buildStartupSetup(context);
        }
        return Scaffold(
          backgroundColor: const Color(0xFF1E1F26),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF20222C),
                  Color(0xFF171922),
                  Color(0xFF111318),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: <Widget>[
                  _TopCommandBar(
                    controller: _controller,
                    onOpenPreview: _openPreviewWindow,
                    onRunFlow: _controller.runFullFlow,
                    onSaveWorkspace: _controller.saveWorkspace,
                    onAddFile: _openAddFileDialog,
                    onGenerateSample: _controller.generateStarterWorkspace,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 1180;
                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                SizedBox(
                                  width: 60,
                                  child: _ActivityRail(
                                    controller: _controller,
                                    onAddFile: _openAddFileDialog,
                                    onGenerateSample:
                                        _controller.generateStarterWorkspace,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 300,
                                  child: _ExplorerPane(
                                    controller: _controller,
                                    onAddFile: _openAddFileDialog,
                                    onAddFolder: _openAddFolderDialog,
                                    onSelectFile: _selectProjectFile,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      Expanded(
                                        child: _EditorPane(
                                          controller: _controller,
                                          editorController: _editorController,
                                          onEditorChanged: _controller
                                              .updateActiveFileContent,
                                          onSaveWorkspace:
                                              _controller.saveWorkspace,
                                          onGenerateSample: _controller
                                              .generateStarterWorkspace,
                                          onAddFile: _openAddFileDialog,
                                          onSelectTab:
                                              _controller.selectFilePath,
                                          onCloseTab: _controller.closeFileTab,
                                        ),
                                      ),
                                      if (_showPreviewPanel) ...<Widget>[
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          width: constraints.maxWidth >= 1700
                                              ? 420
                                              : 340,
                                          child: _PreviewPanel(
                                            controller: _controller,
                                            onClose: _closePreviewWindow,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }

                          return ListView(
                            padding: EdgeInsets.zero,
                            children: <Widget>[
                              _EditorPane(
                                controller: _controller,
                                editorController: _editorController,
                                onEditorChanged:
                                    _controller.updateActiveFileContent,
                                onSaveWorkspace: _controller.saveWorkspace,
                                onGenerateSample:
                                    _controller.generateStarterWorkspace,
                                onAddFile: _openAddFileDialog,
                                onSelectTab: _controller.selectFilePath,
                                onCloseTab: _controller.closeFileTab,
                              ),
                              if (_showPreviewPanel) ...<Widget>[
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 420,
                                  child: _PreviewPanel(
                                    controller: _controller,
                                    onClose: _closePreviewWindow,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              _ExplorerPane(
                                controller: _controller,
                                onAddFile: _openAddFileDialog,
                                onAddFolder: _openAddFolderDialog,
                                onSelectFile: _selectProjectFile,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPreviewWindow() async {
    await _controller.startLivePreview();
    if (!mounted) {
      return;
    }
    if (_controller.previewRunner.state != PreviewRunnerState.running) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_controller.previewRunner.message)),
      );
      return;
    }
    setState(() {
      _showPreviewPanel = true;
    });
  }

  void _closePreviewWindow() {
    if (!_showPreviewPanel) {
      return;
    }

    setState(() {
      _showPreviewPanel = false;
    });
  }

  Future<void> _openAddFileDialog() async {
    final suggestedPath = _suggestFilePath();
    final draft = await showDialog<WorkspaceFile>(
      context: context,
      builder: (context) {
        return _AddFileDialog(
          defaultPath: suggestedPath,
          defaultContent: _starterSnippetForFile(suggestedPath),
        );
      },
    );

    if (draft != null) {
      _controller.addFile(draft.path, draft.content);
    }
  }

  Future<void> _openAddFolderDialog() async {
    final pathController = TextEditingController(text: 'lib/new_folder');
    final draft = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create folder'),
        content: TextField(
          controller: pathController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder path'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, pathController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    pathController.dispose();
    if (draft == null) return;
    try {
      await _controller.addFolder(draft);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create folder: $error')),
        );
      }
    }
  }

  void _selectProjectFile(String path) {
    if (!_controller.selectFilePath(path)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This file is not editable as text.')),
      );
    }
  }

  String _suggestFilePath() {
    final active = _controller.activeFile;
    if (active != null) {
      final directory = active.path.contains('/')
          ? active.path.substring(0, active.path.lastIndexOf('/'))
          : 'lib';
      if (directory.contains('screens')) {
        return '$directory/new_screen.dart';
      }
      if (directory.contains('widgets')) {
        return '$directory/new_widget.dart';
      }
      return '$directory/new_file.dart';
    }

    return 'lib/screens/new_screen.dart';
  }
}

class _TopCommandBar extends StatelessWidget {
  const _TopCommandBar({
    required this.controller,
    required this.onOpenPreview,
    required this.onRunFlow,
    required this.onSaveWorkspace,
    required this.onAddFile,
    required this.onGenerateSample,
  });

  final EditorController controller;
  final Future<void> Function() onOpenPreview;
  final Future<void> Function() onRunFlow;
  final Future<void> Function() onSaveWorkspace;
  final Future<void> Function() onAddFile;
  final VoidCallback onGenerateSample;

  @override
  Widget build(BuildContext context) {
    final sdk = controller.sdkSnapshot;
    return Container(
      height: 62,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF23242E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF343748)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF007ACC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.code_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Flutter Visual UI Editor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFF3F4F6),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  controller.projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _StatusChip(
            label: sdk.chipLabel,
            icon: sdk.ready ? Icons.check_circle_rounded : Icons.sync_rounded,
            accent: sdk.ready
                ? const Color(0xFF22C55E)
                : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 10),
          TextButton.icon(
            key: const ValueKey<String>('preview-toolbar-button'),
            onPressed: () {
              unawaited(onOpenPreview());
            },
            icon: const Icon(Icons.visibility_rounded, size: 18),
            label: const Text('Preview'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE5E7EB),
              backgroundColor: const Color(0xFF31333F),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {
              unawaited(onRunFlow());
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Run'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE5E7EB),
              backgroundColor: const Color(0xFF31333F),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {
              unawaited(onSaveWorkspace());
            },
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE5E7EB),
              backgroundColor: const Color(0xFF31333F),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Add file',
            onPressed: () {
              unawaited(onAddFile());
            },
            icon: const Icon(Icons.add_rounded, color: Color(0xFFE5E7EB)),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onGenerateSample,
            child: const Text('Reset sample'),
          ),
        ],
      ),
    );
  }
}

class _ActivityRail extends StatelessWidget {
  const _ActivityRail({
    required this.controller,
    required this.onAddFile,
    required this.onGenerateSample,
  });

  final EditorController controller;
  final Future<void> Function() onAddFile;
  final VoidCallback onGenerateSample;

  @override
  Widget build(BuildContext context) {
    final sdk = controller.sdkSnapshot;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF23242E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF343748)),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 14),
          _RailButton(
            icon: Icons.folder_open_rounded,
            tooltip: 'Explorer',
            active: true,
          ),
          _RailButton(
            icon: Icons.add_rounded,
            tooltip: 'Add file',
            onTap: () {
              unawaited(onAddFile());
            },
          ),
          _RailButton(
            icon: Icons.auto_awesome_rounded,
            tooltip: 'Generate sample',
            onTap: onGenerateSample,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(10),
            child: _StatusChip(
              label: sdk.chipLabel,
              icon: sdk.ready
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              accent: sdk.ready
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFF59E0B),
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorPane extends StatelessWidget {
  const _EditorPane({
    required this.controller,
    required this.editorController,
    required this.onEditorChanged,
    required this.onSaveWorkspace,
    required this.onGenerateSample,
    required this.onAddFile,
    required this.onSelectTab,
    required this.onCloseTab,
  });

  final EditorController controller;
  final TextEditingController editorController;
  final ValueChanged<String> onEditorChanged;
  final Future<void> Function() onSaveWorkspace;
  final VoidCallback onGenerateSample;
  final Future<void> Function() onAddFile;
  final ValueChanged<String> onSelectTab;
  final ValueChanged<String> onCloseTab;

  @override
  Widget build(BuildContext context) {
    final activeFile = controller.activeFile;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D26),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF343748)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF303340))),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        activeFile?.name ?? 'No file selected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFFF3F4F6),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activeFile?.path ?? 'Add a file to start editing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label:
                      '${controller.previewStageIndex + 1}/${controller.stages.length}',
                  icon: controller.currentStage.icon,
                  accent: controller.currentStage.accent,
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Save workspace',
                  onPressed: () {
                    unawaited(onSaveWorkspace());
                  },
                  icon: const Icon(
                    Icons.save_outlined,
                    color: Color(0xFFE5E7EB),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (controller.openFiles.isNotEmpty) ...<Widget>[
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: controller.openFiles.map((file) {
                          final selected = file.path == activeFile?.path;
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF292C38)
                                  : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: selected
                                      ? const Color(0xFF4FC1FF)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: InkWell(
                              onTap: () => onSelectTab(file.path),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.code_rounded,
                                      size: 15,
                                      color: selected
                                          ? const Color(0xFF4FC1FF)
                                          : const Color(0xFF9CA3AF),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      file.name,
                                      style: const TextStyle(
                                        color: Color(0xFFD1D5DB),
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (file.dirty)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 5),
                                        child: Icon(
                                          Icons.circle,
                                          size: 6,
                                          color: Color(0xFFF59E0B),
                                        ),
                                      ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => onCloseTab(file.path),
                                      child: const Padding(
                                        padding: EdgeInsets.all(3),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 13,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (activeFile != null) ...<Widget>[
                    _FileHeaderStrip(file: activeFile),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F111A),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF2F3241)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: TextField(
                            key: const ValueKey<String>('active-file-editor'),
                            controller: editorController,
                            onChanged: onEditorChanged,
                            expands: true,
                            maxLines: null,
                            minLines: null,
                            keyboardType: TextInputType.multiline,
                            cursorColor: const Color(0xFF4FC1FF),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontFamily: _monoFontFamily(),
                                  fontSize: 13.5,
                                  height: 1.5,
                                  color: const Color(0xFFE8EAED),
                                ),
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Color(0xFF0F111A),
                              border: InputBorder.none,
                              hintText: 'Edit the active file here...',
                              isCollapsed: true,
                              hintStyle: TextStyle(color: Color(0xFF6B7280)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else ...<Widget>[
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F111A),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF2F3241)),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Icon(
                                  Icons.code_rounded,
                                  color: Color(0xFF9CA3AF),
                                  size: 52,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'No file selected',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: const Color(0xFFF3F4F6),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Pick a file from the explorer on the right or create a new one to start editing.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF9CA3AF),
                                        height: 1.4,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: <Widget>[
                                    FilledButton(
                                      onPressed: () {
                                        unawaited(onAddFile());
                                      },
                                      child: const Text('Add file'),
                                    ),
                                    OutlinedButton(
                                      onPressed: onGenerateSample,
                                      child: const Text('Reset sample'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: <Widget>[
                      _StatusChip(
                        label: 'Dirty ${controller.dirtyCount}',
                        icon: Icons.edit_note_rounded,
                        accent: controller.dirtyCount == 0
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFF59E0B),
                      ),
                      _StatusChip(
                        label: controller.currentStage.title,
                        icon: controller.currentStage.icon,
                        accent: controller.currentStage.accent,
                      ),
                      _StatusChip(
                        label: '${(controller.previewProgress * 100).round()}%',
                        icon: Icons.auto_graph_rounded,
                        accent: const Color(0xFF4FC1FF),
                      ),
                      TextButton(
                        onPressed: onGenerateSample,
                        child: const Text('Reset sample'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplorerPane extends StatelessWidget {
  const _ExplorerPane({
    required this.controller,
    required this.onAddFile,
    required this.onAddFolder,
    required this.onSelectFile,
  });

  final EditorController controller;
  final Future<void> Function() onAddFile;
  final Future<void> Function() onAddFolder;
  final ValueChanged<String> onSelectFile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF23242E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF343748)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        controller.projectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFFF3F4F6),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        '${controller.projectFilePaths.length} files  ·  ${controller.folders.length} folders',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'New file',
                  onPressed: () => unawaited(onAddFile()),
                  icon: const Icon(Icons.note_add_outlined),
                ),
                IconButton(
                  tooltip: 'New folder',
                  onPressed: () => unawaited(onAddFolder()),
                  icon: const Icon(Icons.create_new_folder_outlined),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              controller.workspacePath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: const Color(0xFF6B7280)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _SectionShell(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: _treeChildren(context, null),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _treeChildren(BuildContext context, String? parent) {
    String? parentOf(String path) =>
        path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : null;
    String leaf(String path) => path.split('/').last;
    final folders =
        controller.folders.where((path) => parentOf(path) == parent).toList()
          ..sort();
    final files =
        controller.projectFilePaths
            .where((path) => parentOf(path) == parent)
            .toList()
          ..sort();
    return <Widget>[
      for (final folder in folders)
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey<String>('folder:$folder'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.only(left: 14),
            leading: const Icon(
              Icons.folder_outlined,
              color: Color(0xFF4FC1FF),
              size: 19,
            ),
            title: Text(
              leaf(folder),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
            ),
            children: _treeChildren(context, folder),
          ),
        ),
      for (final path in files)
        Builder(
          builder: (context) {
            final fileIndex = controller.files.indexWhere(
              (file) => file.path == path,
            );
            final editable = fileIndex >= 0;
            final selected = editable && controller.activeFile?.path == path;
            final file = editable ? controller.files[fileIndex] : null;
            final ext = leaf(path).split('.').last.toLowerCase();
            final icon = ext == 'dart'
                ? Icons.code_rounded
                : ext == 'yaml' || ext == 'yml'
                ? Icons.tune_rounded
                : Icons.description_outlined;
            return InkWell(
              onTap: editable ? () => onSelectFile(path) : null,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF2B303B)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      icon,
                      size: 17,
                      color: editable
                          ? (selected
                                ? const Color(0xFF4FC1FF)
                                : const Color(0xFF9CA3AF))
                          : const Color(0xFF555967),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        leaf(path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: editable
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFF737784),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    if (file?.dirty == true)
                      const Icon(
                        Icons.circle,
                        size: 7,
                        color: Color(0xFFF59E0B),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
    ];
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.controller, required this.onClose});

  final EditorController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final stage = controller.currentStage;
    return Column(
      children: <Widget>[
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: const BoxDecoration(
            color: Color(0xFF1B1F2A),
            border: Border(bottom: BorderSide(color: Color(0xFF303340))),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFF4FC1FF),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Flutter web preview',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFFF3F4F6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      controller.activeFile?.path ?? 'No active file',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(
                label: stage.title,
                icon: stage.icon,
                accent: stage.accent,
                compact: true,
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Close preview',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: Color(0xFFE5E7EB)),
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return Container(
                color: const Color(0xFF111827),
                padding: const EdgeInsets.all(12),
                child: _RuntimePreviewSurface(
                  runner: controller.previewRunner,
                  activeFilePath:
                      controller.activeFile?.path ?? 'No file selected',
                  onStart: controller.startLivePreview,
                  onStop: controller.stopLivePreview,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RuntimePreviewSurface extends StatefulWidget {
  const _RuntimePreviewSurface({
    required this.runner,
    required this.activeFilePath,
    required this.onStart,
    required this.onStop,
  });

  final FlutterPreviewRunner runner;
  final String activeFilePath;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;

  @override
  State<_RuntimePreviewSurface> createState() => _RuntimePreviewSurfaceState();
}

class _RuntimePreviewSurfaceState extends State<_RuntimePreviewSurface> {
  late final WebViewController _webController;
  Uri? _loadedUri;
  int _loadedPreviewRevision = -1;
  String? _webError;
  bool _webViewReady = false;

  @override
  void initState() {
    super.initState();
    _webController = WebViewController();
    widget.runner.addListener(_syncPreviewUrl);
    unawaited(_prepareWebView());
  }

  @override
  void didUpdateWidget(covariant _RuntimePreviewSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runner != widget.runner) {
      oldWidget.runner.removeListener(_syncPreviewUrl);
      widget.runner.addListener(_syncPreviewUrl);
      _loadedUri = null;
      _webError = null;
      _webViewReady = false;
      unawaited(_prepareWebView());
    }
  }

  @override
  void dispose() {
    widget.runner.removeListener(_syncPreviewUrl);
    super.dispose();
  }

  void _syncPreviewUrl() {
    final uri = widget.runner.previewUri;
    if (!_webViewReady || uri == null) {
      return;
    }
    final revision = widget.runner.previewRevision;
    if (uri == _loadedUri) {
      if (revision == _loadedPreviewRevision) {
        return;
      }
      _loadedPreviewRevision = revision;
      unawaited(_reloadPreviewPage());
      return;
    }
    _loadedUri = uri;
    _loadedPreviewRevision = revision;
    unawaited(_loadPreview(uri));
  }

  Future<void> _prepareWebView() async {
    try {
      await _webController.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _webController.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _webError = null);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _webError = null);
            }
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame != false) {
              setState(() => _webError = error.description);
            }
          },
        ),
      );
      // Wait for WebViewWidget's platform view to be mounted before navigating.
      await WidgetsBinding.instance.endOfFrame;
      // On macOS the platform view may need another run-loop turn after the
      // first frame. Navigating sooner can silently drop the first request;
      // that is why a manual Reload used to be required on initial preview.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) {
        return;
      }
      _webViewReady = true;
      _syncPreviewUrl();
    } catch (error) {
      if (mounted) {
        setState(() => _webError = 'WebView setup failed: $error');
      }
    }
  }

  Future<void> _loadPreview(Uri uri) async {
    try {
      // Give the native WebView one extra frame when the preview panel was
      // just mounted alongside the Flutter web server.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted || widget.runner.previewUri != uri) {
        return;
      }
      await _webController.loadRequest(uri);
    } catch (error) {
      if (mounted) {
        setState(() => _webError = 'Preview navigation failed: $error');
      }
    }
  }

  Future<void> _reloadPreviewPage() async {
    try {
      await _webController.reload();
    } catch (error) {
      if (mounted) {
        setState(() => _webError = 'Preview refresh failed: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.runner,
      builder: (context, _) {
        final runner = widget.runner;
        final isBusy =
            runner.state == PreviewRunnerState.preparing ||
            runner.state == PreviewRunnerState.starting;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SectionShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    runner.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFE5E7EB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PathRow(label: 'Active file', value: widget.activeFilePath),
                  const SizedBox(height: 6),
                  _PathRow(
                    label: 'Local preview',
                    value:
                        runner.previewUri?.toString() ??
                        'Waiting for Flutter web server',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: isBusy ? null : widget.onStart,
                        icon: Icon(
                          runner.isRunning
                              ? Icons.refresh_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(
                          runner.isRunning ? 'Reload' : 'Run web preview',
                        ),
                      ),
                      if (runner.isRunning)
                        OutlinedButton.icon(
                          onPressed: widget.onStop,
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('Stop'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    WebViewWidget(controller: _webController),
                    if (runner.previewUri == null)
                      ColoredBox(
                        color: const Color(0xFF111318),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (isBusy)
                                  const CircularProgressIndicator(
                                    color: Color(0xFF4FC1FF),
                                  )
                                else
                                  const Icon(
                                    Icons.web_asset_rounded,
                                    color: Color(0xFF4FC1FF),
                                    size: 34,
                                  ),
                                const SizedBox(height: 12),
                                Text(
                                  runner.state == PreviewRunnerState.failed
                                      ? runner.message
                                      : 'Run the Flutter web preview to see this workspace here.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_webError != null)
                      ColoredBox(
                        color: const Color(0xFF111318),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFF59E0B),
                                  size: 32,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Could not load the preview: $_webError',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextButton.icon(
                                  onPressed: () {
                                    final uri = runner.previewUri;
                                    if (uri != null) {
                                      _loadedUri = uri;
                                      _loadedPreviewRevision =
                                          runner.previewRevision;
                                      unawaited(_loadPreview(uri));
                                    }
                                  },
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (runner.output.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                height: 82,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF111318),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    runner.output
                        .skip(
                          runner.output.length > 5
                              ? runner.output.length - 5
                              : 0,
                        )
                        .join('\n'),
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontFamily: 'Menlo',
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFF3F4F6),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF9CA3AF),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        ...?(trailing == null ? null : <Widget>[trailing!]),
      ],
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D26),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF343748)),
      ),
      child: child,
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.tooltip,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF31333F) : const Color(0xFF23242E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? const Color(0xFF4FC1FF)
                    : const Color(0xFF343748),
              ),
            ),
            child: Icon(
              icon,
              color: active ? const Color(0xFF4FC1FF) : const Color(0xFFE5E7EB),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _FileHeaderStrip extends StatelessWidget {
  const _FileHeaderStrip({required this.file});

  final WorkspaceFile file;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF23242E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF343748)),
      ),
      child: Row(
        children: <Widget>[
          Icon(_iconForFile(file), size: 18, color: const Color(0xFF4FC1FF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFF3F4F6),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  file.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          if (file.dirty)
            const _StatusChip(
              label: 'Unsaved',
              icon: Icons.edit_note_rounded,
              accent: Color(0xFFF59E0B),
            )
          else
            const _StatusChip(
              label: 'Clean',
              icon: Icons.check_circle_rounded,
              accent: Color(0xFF22C55E),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.accent,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Color.lerp(accent, Colors.black, 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Color.lerp(accent, Colors.white, 0.25) ?? accent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: compact ? 13 : 14, color: accent),
          if (!compact) ...<Widget>[
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFFF3F4F6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFFF3F4F6),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.file,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  final WorkspaceFile file;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFF4FC1FF)
        : const Color(0xFF343748);
    final background = selected
        ? const Color(0xFF31333F)
        : const Color(0xFF1B1D26);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF0EA5E9)
                    : const Color(0xFF2A2D39),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconForFile(file),
                size: 18,
                color: selected ? Colors.white : const Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFF3F4F6),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    file.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (file.dirty)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.fiber_manual_record,
                  size: 10,
                  color: Color(0xFFF59E0B),
                ),
              ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: const Color(0xFFCBD5E1),
              tooltip: 'Remove file',
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final timeLabel = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(entry.timestamp));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF343748)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Color.lerp(entry.accent, Colors.black, 0.85),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(entry.icon, color: entry.accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFF3F4F6),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFCBD5E1),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddFileDialog extends StatefulWidget {
  const _AddFileDialog({
    required this.defaultPath,
    required this.defaultContent,
  });

  final String defaultPath;
  final String defaultContent;

  @override
  State<_AddFileDialog> createState() => _AddFileDialogState();
}

class _AddFileDialogState extends State<_AddFileDialog> {
  late final TextEditingController _pathController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController(text: widget.defaultPath);
    _contentController = TextEditingController(text: widget.defaultContent);
  }

  @override
  void dispose() {
    _pathController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add file'),
      content: SizedBox(
        width: 640,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _pathController,
              decoration: const InputDecoration(
                labelText: 'File path',
                hintText: 'lib/screens/new_screen.dart',
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _contentController,
                expands: true,
                maxLines: null,
                minLines: null,
                keyboardType: TextInputType.multiline,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: _monoFontFamily(),
                  fontSize: 13.5,
                  height: 1.5,
                ),
                decoration: const InputDecoration(
                  labelText: 'File content',
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              WorkspaceFile(
                path: _pathController.text.trim(),
                content: _contentController.text,
              ),
            );
          },
          child: const Text('Add file'),
        ),
      ],
    );
  }
}

IconData _iconForFile(WorkspaceFile file) {
  switch (file.extension) {
    case 'dart':
      return Icons.code_rounded;
    case 'yaml':
    case 'yml':
      return Icons.tune_rounded;
    case 'md':
      return Icons.description_rounded;
    case 'json':
      return Icons.data_object_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

String _monoFontFamily() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.macOS => 'SF Mono',
    TargetPlatform.windows => 'Consolas',
    _ => 'Roboto Mono',
  };
}

String _starterSnippetForFile(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.yaml') || lower.endsWith('.yml')) {
    return '''
name: starter_flow
description: A new Flutter file generated from Flutter Visual UI Editor.
publish_to: 'none'
''';
  }

  return '''
import 'package:flutter/material.dart';

class NewFeatureScreen extends StatelessWidget {
  const NewFeatureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
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
          child: const Text('New file ready'),
        ),
      ),
    );
  }
}
''';
}
