import 'package:flutter/material.dart';

import 'models.dart';

enum LivePreviewKind {
  screen,
  component,
  appShell,
  generic,
  empty,
}

class LivePreviewSpec {
  const LivePreviewSpec({
    required this.kind,
    required this.kindLabel,
    required this.fileName,
    required this.filePath,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.accent,
    required this.icon,
    required this.cardRadius,
    required this.cardPadding,
    required this.avatarRadius,
    required this.panelPadding,
    required this.surfaceWidth,
    required this.shadowBlur,
    required this.chips,
    required this.helperText,
    required this.fingerprint,
  });

  final LivePreviewKind kind;
  final String kindLabel;
  final String fileName;
  final String filePath;
  final String title;
  final String subtitle;
  final String actionLabel;
  final Color accent;
  final IconData icon;
  final double cardRadius;
  final double cardPadding;
  final double avatarRadius;
  final double panelPadding;
  final double surfaceWidth;
  final double shadowBlur;
  final List<String> chips;
  final String helperText;
  final String fingerprint;
}

class LivePreviewCanvas extends StatelessWidget {
  const LivePreviewCanvas({
    super.key,
    required this.stage,
    required this.previewProgress,
    required this.projectName,
    required this.activeFile,
    required this.isSimulating,
    required this.onTap,
  });

  final FlowStage stage;
  final double previewProgress;
  final String projectName;
  final WorkspaceFile? activeFile;
  final bool isSimulating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spec = buildLivePreviewSpec(
      file: activeFile,
      stage: stage,
      projectName: projectName,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 360,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFDFF),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: <Widget>[
              _PreviewTopBar(
                spec: spec,
                stage: stage,
                isSimulating: isSimulating,
                projectName: projectName,
              ),
              const SizedBox(height: 14),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: _PreviewBody(
                    key: ValueKey<String>(spec.fingerprint),
                    spec: spec,
                    stage: stage,
                    previewProgress: previewProgress,
                    isSimulating: isSimulating,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

LivePreviewSpec buildLivePreviewSpec({
  required WorkspaceFile? file,
  required FlowStage stage,
  required String projectName,
}) {
  if (file == null) {
    return LivePreviewSpec(
      kind: LivePreviewKind.empty,
      kindLabel: 'Empty state',
      fileName: 'No file selected',
      filePath: 'Select a file to begin.',
      title: 'Open a Dart file',
      subtitle: 'The preview mirrors the active file and updates as you type.',
      actionLabel: 'Pick a file',
      accent: stage.accent,
      icon: Icons.description_outlined,
      cardRadius: 24,
      cardPadding: 20,
      avatarRadius: 22,
      panelPadding: 18,
      surfaceWidth: 480,
      shadowBlur: 20,
      chips: <String>[
        'same file live',
        'instant feedback',
        'lightweight preview',
      ],
      helperText: 'Generate a starter workspace or select a file to start.',
      fingerprint: 'empty|${stage.title}|$projectName',
    );
  }

  final path = file.path.toLowerCase();
  final source = file.content;
  final kind = _kindForPath(path);
  final fileName = file.name;
  final cleanName = _humanizeIdentifier(fileName.replaceAll('.dart', ''));
  final accent = _extractAccentColor(
    source,
    fallback: stage.accent,
    kind: kind,
  );
  final icon = _extractIconData(
    source,
    fallback: switch (kind) {
      LivePreviewKind.component => Icons.view_quilt_rounded,
      LivePreviewKind.appShell => Icons.auto_awesome_rounded,
      LivePreviewKind.screen => stage.icon,
      LivePreviewKind.generic => Icons.description_outlined,
      LivePreviewKind.empty => Icons.description_outlined,
    },
  );
  final title = _extractTitle(
    source: source,
    kind: kind,
    projectName: projectName,
    fileName: fileName,
    fallback: cleanName,
  );
  final subtitle = _extractSubtitle(
    source: source,
    kind: kind,
    projectName: projectName,
    fileName: fileName,
  );
  final actionLabel = _extractActionLabel(
        source,
        kind,
      ) ??
      switch (kind) {
        LivePreviewKind.component => 'Tweak the card',
        LivePreviewKind.appShell => 'Continue',
        LivePreviewKind.screen => 'Preview flow',
        LivePreviewKind.generic => 'Keep editing',
        LivePreviewKind.empty => 'Pick a file',
      };

  final cardRadius = _extractDouble(
        source,
        RegExp(r'BorderRadius\.circular\((\d+(?:\.\d+)?)\)'),
      ) ??
      switch (kind) {
        LivePreviewKind.component => 24,
        LivePreviewKind.appShell => 28,
        LivePreviewKind.screen => 24,
        LivePreviewKind.generic => 20,
        LivePreviewKind.empty => 24,
      };
  final cardPadding = _extractDouble(
        source,
        RegExp(r'padding:\s*const\s+EdgeInsets\.all\((\d+(?:\.\d+)?)\)'),
      ) ??
      switch (kind) {
        LivePreviewKind.component => 20,
        LivePreviewKind.appShell => 24,
        LivePreviewKind.screen => 24,
        LivePreviewKind.generic => 18,
        LivePreviewKind.empty => 20,
      };
  final avatarRadius = _extractDouble(
        source,
        RegExp(r'CircleAvatar\(\s*radius:\s*(\d+(?:\.\d+)?)'),
      ) ??
      switch (kind) {
        LivePreviewKind.component => 22,
        LivePreviewKind.appShell => 24,
        LivePreviewKind.screen => 22,
        LivePreviewKind.generic => 20,
        LivePreviewKind.empty => 22,
      };
  final panelPadding = _extractDouble(
        source,
        RegExp(r'EdgeInsets\.all\((\d+(?:\.\d+)?)\)'),
      ) ??
      switch (kind) {
        LivePreviewKind.component => 20,
        LivePreviewKind.appShell => 20,
        LivePreviewKind.screen => 18,
        LivePreviewKind.generic => 18,
        LivePreviewKind.empty => 18,
      };
  final surfaceWidth = _extractDouble(
        source,
        RegExp(r'maxWidth:\s*(\d+(?:\.\d+)?)'),
      ) ??
      switch (kind) {
        LivePreviewKind.component => 420,
        LivePreviewKind.appShell => 560,
        LivePreviewKind.screen => 520,
        LivePreviewKind.generic => 440,
        LivePreviewKind.empty => 480,
      };
  final shadowBlur = _extractDouble(
        source,
        RegExp(r'blurRadius:\s*(\d+(?:\.\d+)?)'),
      ) ??
      switch (kind) {
        LivePreviewKind.component => 24,
        LivePreviewKind.appShell => 22,
        LivePreviewKind.screen => 20,
        LivePreviewKind.generic => 16,
        LivePreviewKind.empty => 20,
      };

  final kindLabel = switch (kind) {
    LivePreviewKind.component => 'Component',
    LivePreviewKind.appShell => 'App shell',
    LivePreviewKind.screen => 'Live screen',
    LivePreviewKind.generic => 'Code summary',
    LivePreviewKind.empty => 'Empty state',
  };

  final chips = <String>{
    cleanName,
    kindLabel,
    'radius ${cardRadius.round()}',
    'padding ${cardPadding.round()}',
    'width ${surfaceWidth.round()}',
    'accent #${_colorHex(accent)}',
  }.toList();

  return LivePreviewSpec(
    kind: kind,
    kindLabel: kindLabel,
    fileName: fileName,
    filePath: file.path,
    title: title,
    subtitle: subtitle,
    actionLabel: actionLabel,
    accent: accent,
    icon: icon,
    cardRadius: cardRadius,
    cardPadding: cardPadding,
    avatarRadius: avatarRadius,
    panelPadding: panelPadding,
    surfaceWidth: surfaceWidth,
    shadowBlur: shadowBlur,
    chips: chips,
    helperText: 'Edits in $fileName update the live preview immediately.',
    fingerprint:
        '$kind|$fileName|$title|$subtitle|$actionLabel|${accent.toARGB32()}|$cardRadius|$cardPadding|$avatarRadius|$panelPadding|$surfaceWidth|$shadowBlur|${chips.join("|")}|${stage.title}',
  );
}

class _PreviewTopBar extends StatelessWidget {
  const _PreviewTopBar({
    required this.spec,
    required this.stage,
    required this.isSimulating,
    required this.projectName,
  });

  final LivePreviewSpec spec;
  final FlowStage stage;
  final bool isSimulating;
  final String projectName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: spec.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.filePath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF64748B),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _LivePill(
                label: stage.title,
                icon: stage.icon,
                background: _fade(stage.accent, 0.14),
                foreground: stage.accent,
              ),
              _LivePill(
                label: isSimulating ? 'Simulating' : spec.kindLabel,
                icon: isSimulating
                    ? Icons.radar_rounded
                    : Icons.auto_awesome_rounded,
                background: isSimulating
                    ? const Color(0xFFE0F2FE)
                    : _fade(spec.accent, 0.12),
                foreground: isSimulating
                    ? const Color(0xFF075985)
                    : spec.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({
    super.key,
    required this.spec,
    required this.stage,
    required this.previewProgress,
    required this.isSimulating,
  });

  final LivePreviewSpec spec;
  final FlowStage stage;
  final double previewProgress;
  final bool isSimulating;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: spec.surfaceWidth),
          child: Container(
            padding: EdgeInsets.all(spec.panelPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(spec.cardRadius + 10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  _fade(spec.accent, 0.10),
                  const Color(0xFFF8FAFC),
                  const Color(0xFFFFFFFF),
                ],
              ),
              border: Border.all(color: _fade(spec.accent, 0.14)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x0F17324D),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        spec.title,
                        key: const ValueKey<String>('live-preview-title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _LivePill(
                      label: spec.kindLabel,
                      icon: _iconForKind(spec.kind),
                      background: _fade(spec.accent, 0.14),
                      foreground: spec.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  spec.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF475569),
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 14),
                _buildCoreVisual(context),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: spec.chips
                      .map(
                        (chip) => _LivePill(
                          label: chip,
                          icon: Icons.bolt_rounded,
                          background: const Color(0xFFF8FAFC),
                          foreground: const Color(0xFF334155),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _ActionTile(
                      label: spec.actionLabel,
                      accent: spec.accent,
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _LivePill(
                        label: isSimulating
                            ? 'Flow live'
                            : 'Stage ${stage.title}',
                        icon: isSimulating
                            ? Icons.radar_rounded
                            : stage.icon,
                        background: _fade(stage.accent, 0.12),
                        foreground: stage.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: previewProgress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      spec.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  spec.helperText,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF64748B),
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoreVisual(BuildContext context) {
    return switch (spec.kind) {
      LivePreviewKind.component => _ComponentPreview(spec: spec),
      LivePreviewKind.appShell => _AppShellPreview(spec: spec),
      LivePreviewKind.screen => _ScreenPreview(spec: spec),
      LivePreviewKind.generic => _GenericPreview(spec: spec),
      LivePreviewKind.empty => _GenericPreview(spec: spec),
    };
  }
}

class _ScreenPreview extends StatelessWidget {
  const _ScreenPreview({required this.spec});

  final LivePreviewSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(spec.cardPadding),
      decoration: BoxDecoration(
        color: _withOpacity(Colors.white, 0.94),
        borderRadius: BorderRadius.circular(spec.cardRadius + 8),
        border: Border.all(color: _fade(spec.accent, 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          CircleAvatar(
            radius: spec.avatarRadius,
            backgroundColor: _fade(spec.accent, 0.16),
            child: Icon(spec.icon, color: spec.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  spec.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  spec.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF475569),
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

class _ComponentPreview extends StatelessWidget {
  const _ComponentPreview({required this.spec});

  final LivePreviewSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(spec.cardPadding),
      decoration: BoxDecoration(
        color: _withOpacity(Colors.white, 0.90),
        borderRadius: BorderRadius.circular(spec.cardRadius + 10),
        border: Border.all(color: _fade(spec.accent, 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.view_quilt_rounded,
                  color: spec.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    spec.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                _LivePill(
                  label: 'Component',
                  icon: Icons.layers_rounded,
                  background: _fade(spec.accent, 0.14),
                  foreground: spec.accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(spec.cardPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  _fade(spec.accent, 0.12),
                  const Color(0xFFFFFFFF),
                ],
              ),
              borderRadius: BorderRadius.circular(spec.cardRadius),
              border: Border.all(color: _fade(spec.accent, 0.16)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _fade(spec.accent, 0.12),
                  blurRadius: spec.shadowBlur,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: spec.avatarRadius,
                  backgroundColor: _fade(spec.accent, 0.14),
                  child: Icon(spec.icon, color: spec.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        spec.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        spec.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF475569),
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: spec.chips
                .map(
                  (chip) => _LivePill(
                    label: chip,
                    icon: Icons.bolt_rounded,
                    background: const Color(0xFFF8FAFC),
                    foreground: const Color(0xFF334155),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AppShellPreview extends StatelessWidget {
  const _AppShellPreview({required this.spec});

  final LivePreviewSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(spec.cardPadding),
      decoration: BoxDecoration(
        color: _withOpacity(Colors.white, 0.92),
        borderRadius: BorderRadius.circular(spec.cardRadius + 12),
        border: Border.all(color: _fade(spec.accent, 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: spec.avatarRadius,
                backgroundColor: _fade(spec.accent, 0.16),
                child: Icon(Icons.phone_iphone_rounded, color: spec.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      spec.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spec.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF475569),
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              _LivePill(
                label: 'Theme',
                icon: Icons.color_lens_rounded,
                background: _fade(spec.accent, 0.14),
                foreground: spec.accent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 168,
            padding: EdgeInsets.all(spec.cardPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  _fade(spec.accent, 0.14),
                  const Color(0xFFFFFFFF),
                ],
              ),
              borderRadius: BorderRadius.circular(spec.cardRadius),
              border: Border.all(color: _fade(spec.accent, 0.16)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _fade(spec.accent, 0.10),
                  blurRadius: spec.shadowBlur,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: spec.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Preview driven by ${spec.fileName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Material theme uses the same file values that you are editing.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF475569),
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _ActionTile(
                          label: spec.actionLabel,
                          accent: spec.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: spec.chips
                .map(
                  (chip) => _LivePill(
                    label: chip,
                    icon: Icons.bolt_rounded,
                    background: const Color(0xFFF8FAFC),
                    foreground: const Color(0xFF334155),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _GenericPreview extends StatelessWidget {
  const _GenericPreview({required this.spec});

  final LivePreviewSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(spec.cardPadding),
      decoration: BoxDecoration(
        color: _withOpacity(Colors.white, 0.90),
        borderRadius: BorderRadius.circular(spec.cardRadius + 8),
        border: Border.all(color: _fade(spec.accent, 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(spec.icon, color: spec.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  spec.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              _LivePill(
                label: spec.kindLabel,
                icon: Icons.description_rounded,
                background: _fade(spec.accent, 0.14),
                foreground: spec.accent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            spec.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            spec.subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF475569),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: spec.chips
                .map(
                  (chip) => _LivePill(
                    label: chip,
                    icon: Icons.bolt_rounded,
                    background: const Color(0xFFF8FAFC),
                    foreground: const Color(0xFF334155),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent,
            _fade(accent, 0.14),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _fade(accent, 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

LivePreviewKind _kindForPath(String path) {
  if (path.contains('flow_home.dart')) {
    return LivePreviewKind.screen;
  }
  if (path.contains('section_card.dart')) {
    return LivePreviewKind.component;
  }
  if (path.endsWith('app.dart') || path.endsWith('main.dart')) {
    return LivePreviewKind.appShell;
  }
  if (path.isEmpty) {
    return LivePreviewKind.empty;
  }
  return LivePreviewKind.generic;
}

String _extractTitle({
  required String source,
  required LivePreviewKind kind,
  required String projectName,
  required String fileName,
  required String fallback,
}) {
  final title =
      _extractString(source, RegExp(r"title:\s*'([^']+)'")) ??
      _extractString(source, RegExp(r'title:\s*"([^"]+)"'));
  if (title != null && title.isNotEmpty) {
    return title;
  }

  return switch (kind) {
    LivePreviewKind.screen => projectName,
    LivePreviewKind.appShell => _humanizeIdentifier(fileName.replaceAll('.dart', '')),
    LivePreviewKind.component => fallback,
    LivePreviewKind.generic => fallback,
    LivePreviewKind.empty => 'Open a file',
  };
}

String _extractSubtitle({
  required String source,
  required LivePreviewKind kind,
  required String projectName,
  required String fileName,
}) {
  final subtitle =
      _extractString(source, RegExp(r"subtitle:\s*'([^']+)'")) ??
      _extractString(source, RegExp(r'subtitle:\s*"([^"]+)"'));
  if (subtitle != null && subtitle.isNotEmpty) {
    return subtitle;
  }

  return switch (kind) {
    LivePreviewKind.screen =>
      'Edit $fileName and watch the preview move with the same file.',
    LivePreviewKind.appShell =>
      'Theme and navigation values update as you adjust the source.',
    LivePreviewKind.component =>
      'Card padding, radius, and shadow are reflected live.',
    LivePreviewKind.generic =>
      'Live code summary for $fileName in $projectName.',
    LivePreviewKind.empty =>
      'The preview mirrors the active file and updates as you type.',
  };
}

String? _extractActionLabel(String source, LivePreviewKind kind) {
  final buttonMatch = RegExp(
    r"(?:FilledButton|ElevatedButton|TextButton)[\s\S]{0,240}?Text\(\s*'([^']+)'\s*\)",
  ).firstMatch(source);
  if (buttonMatch != null) {
    final value = buttonMatch.group(1)?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  final textMatch = RegExp(r"Text\(\s*'([^']+)'\s*\)").allMatches(source);
  if (textMatch.isNotEmpty) {
    final value = textMatch.last.group(1)?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return switch (kind) {
    LivePreviewKind.screen => 'Preview flow',
    LivePreviewKind.component => 'Tweak the card',
    LivePreviewKind.appShell => 'Continue',
    LivePreviewKind.generic => 'Keep editing',
    LivePreviewKind.empty => 'Pick a file',
  };
}

double? _extractDouble(String source, RegExp pattern) {
  final match = pattern.firstMatch(source);
  if (match == null) {
    return null;
  }

  final raw = match.group(1);
  if (raw == null) {
    return null;
  }

  return double.tryParse(raw);
}

String? _extractString(String source, RegExp pattern) {
  final match = pattern.firstMatch(source);
  return match?.group(1)?.trim();
}

Color _extractAccentColor(
  String source, {
  required Color fallback,
  required LivePreviewKind kind,
}) {
  final patterns = <RegExp>[
    RegExp(r'seedColor:\s*const\s+Color\(0x([0-9A-Fa-f]{8})\)'),
    RegExp(r'primary:\s*const\s+Color\(0x([0-9A-Fa-f]{8})\)'),
    RegExp(r'backgroundColor:\s*const\s+Color\(0x([0-9A-Fa-f]{8})\)'),
    RegExp(r'color:\s*const\s+Color\(0x([0-9A-Fa-f]{8})\)'),
    RegExp(r'Color\(0x([0-9A-Fa-f]{8})\)'),
  ];

  for (final pattern in patterns) {
    final hex = _extractString(source, pattern);
    if (hex != null) {
      return _colorFromHex(hex);
    }
  }

  return switch (kind) {
    LivePreviewKind.component => _fade(fallback, 0.06),
    LivePreviewKind.appShell => fallback,
    LivePreviewKind.screen => fallback,
    LivePreviewKind.generic => fallback,
    LivePreviewKind.empty => fallback,
  };
}

IconData _extractIconData(
  String source, {
  required IconData fallback,
}) {
  final match = RegExp(r'Icons\.([a-zA-Z0-9_]+)').firstMatch(source);
  final iconName = match?.group(1);
  if (iconName == null || iconName.isEmpty) {
    return fallback;
  }

  return _iconFromName(iconName, fallback: fallback);
}

IconData _iconFromName(
  String name, {
  required IconData fallback,
}) {
  return switch (name) {
    'auto_awesome_rounded' => Icons.auto_awesome_rounded,
    'auto_graph_rounded' => Icons.auto_graph_rounded,
    'check_circle_rounded' => Icons.check_circle_rounded,
    'delete_outline_rounded' => Icons.delete_outline_rounded,
    'description_outlined' => Icons.description_outlined,
    'description_rounded' => Icons.description_rounded,
    'downloading_rounded' => Icons.downloading_rounded,
    'edit_note_rounded' => Icons.edit_note_rounded,
    'folder_copy_rounded' => Icons.folder_copy_rounded,
    'folder_rounded' => Icons.folder_rounded,
    'hourglass_top_rounded' => Icons.hourglass_top_rounded,
    'info_outline_rounded' => Icons.info_outline_rounded,
    'inventory_2_rounded' => Icons.inventory_2_rounded,
    'layers_rounded' => Icons.layers_rounded,
    'lock_open_rounded' => Icons.lock_open_rounded,
    'manage_search_rounded' => Icons.manage_search_rounded,
    'note_add_rounded' => Icons.note_add_rounded,
    'play_arrow_rounded' => Icons.play_arrow_rounded,
    'radar_rounded' => Icons.radar_rounded,
    'rocket_launch_rounded' => Icons.rocket_launch_rounded,
    'route_rounded' => Icons.route_rounded,
    'save_outlined' => Icons.save_outlined,
    'screenshot_monitor_rounded' => Icons.screenshot_monitor_rounded,
    'sync_rounded' => Icons.sync_rounded,
    'terminal_rounded' => Icons.terminal_rounded,
    'view_quilt_rounded' => Icons.view_quilt_rounded,
    _ => fallback,
  };
}

String _humanizeIdentifier(String value) {
  final withSpaces = value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (withSpaces.isEmpty) {
    return value;
  }
  return withSpaces
      .split(' ')
      .map((segment) {
        if (segment.isEmpty) {
          return segment;
        }
        return '${segment[0].toUpperCase()}${segment.substring(1)}';
      })
      .join(' ');
}

String _colorHex(Color color) {
  final hex = color.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0');
  return hex.substring(2);
}

Color _colorFromHex(String hex) {
  final normalized = hex.toUpperCase();
  return Color(int.parse(normalized, radix: 16));
}

Color _fade(Color color, double amount) {
  return Color.lerp(color, Colors.white, amount) ?? color;
}

Color _withOpacity(Color color, double opacity) {
  return color.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}

IconData _iconForKind(LivePreviewKind kind) {
  return switch (kind) {
    LivePreviewKind.component => Icons.view_quilt_rounded,
    LivePreviewKind.appShell => Icons.phone_iphone_rounded,
    LivePreviewKind.screen => Icons.auto_awesome_rounded,
    LivePreviewKind.generic => Icons.description_outlined,
    LivePreviewKind.empty => Icons.description_outlined,
  };
}
