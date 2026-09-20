import 'package:flutter/material.dart';

enum FlutterSdkState {
  unknown,
  detected,
  missing,
  installing,
  error,
}

class FlutterSdkSnapshot {
  const FlutterSdkSnapshot({
    required this.state,
    required this.headline,
    required this.detail,
    this.path,
    this.version,
    this.progress = 0,
  });

  final FlutterSdkState state;
  final String headline;
  final String detail;
  final String? path;
  final String? version;
  final double progress;

  const FlutterSdkSnapshot.unknown()
      : state = FlutterSdkState.unknown,
        headline = 'Checking Flutter',
        detail = 'Scanning the machine for an existing SDK.',
        path = null,
        version = null,
        progress = 0;

  factory FlutterSdkSnapshot.detected({
    required String path,
    required String version,
  }) {
    return FlutterSdkSnapshot(
      state: FlutterSdkState.detected,
      headline: 'Flutter ready',
      detail: 'Found an installed SDK and it is ready to use.',
      path: path,
      version: version,
      progress: 1,
    );
  }

  factory FlutterSdkSnapshot.missing({
    required String detail,
  }) {
    return FlutterSdkSnapshot(
      state: FlutterSdkState.missing,
      headline: 'Flutter not found',
      detail: detail,
      progress: 0,
    );
  }

  factory FlutterSdkSnapshot.installing({
    required String detail,
    double progress = 0.15,
  }) {
    return FlutterSdkSnapshot(
      state: FlutterSdkState.installing,
      headline: 'Installing Flutter',
      detail: detail,
      progress: progress,
    );
  }

  factory FlutterSdkSnapshot.error({
    required String detail,
  }) {
    return FlutterSdkSnapshot(
      state: FlutterSdkState.error,
      headline: 'SDK needs attention',
      detail: detail,
    );
  }

  bool get ready => state == FlutterSdkState.detected;

  String get chipLabel {
    return switch (state) {
      FlutterSdkState.detected => 'Ready',
      FlutterSdkState.installing => 'Installing',
      FlutterSdkState.missing => 'Missing',
      FlutterSdkState.error => 'Needs help',
      FlutterSdkState.unknown => 'Detecting',
    };
  }
}

class WorkspaceFile {
  WorkspaceFile({
    required this.path,
    required this.content,
    this.generated = false,
    this.dirty = false,
  });

  final String path;
  String content;
  final bool generated;
  bool dirty;

  String get name {
    final normalized = path.replaceAll('\\', '/');
    return normalized.split('/').last;
  }

  String get extension {
    final normalized = name;
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex == -1) {
      return '';
    }
    return normalized.substring(dotIndex + 1).toLowerCase();
  }
}

class FlowStage {
  const FlowStage({
    required this.title,
    required this.subtitle,
    required this.note,
    required this.icon,
    required this.accent,
    required this.bullets,
  });

  final String title;
  final String subtitle;
  final String note;
  final IconData icon;
  final Color accent;
  final List<String> bullets;
}

class ActivityEntry {
  const ActivityEntry({
    required this.timestamp,
    required this.message,
    required this.detail,
    required this.icon,
    required this.accent,
  });

  final DateTime timestamp;
  final String message;
  final String detail;
  final IconData icon;
  final Color accent;
}

const List<FlowStage> kDemoFlowStages = [
  FlowStage(
    title: 'Map the journey',
    subtitle: 'Start with a small, calm flow that is easy to follow.',
    note: 'A clear beginning keeps the editor lighter and easier to ship.',
    icon: Icons.route_rounded,
    accent: Color(0xFF0F766E),
    bullets: <String>[
      'Pick the first screen',
      'Keep the first action obvious',
      'Add only the files you need',
    ],
  ),
  FlowStage(
    title: 'Compose the screens',
    subtitle: 'Build the workspace file by file without losing context.',
    note: 'Every file shows up in one place so the flow stays visible.',
    icon: Icons.layers_rounded,
    accent: Color(0xFF2563EB),
    bullets: <String>[
      'Drop in new Dart files',
      'Edit the active file in place',
      'Export the workspace when it feels right',
    ],
  ),
  FlowStage(
    title: 'Preview live',
    subtitle: 'See the current state immediately in a desktop-friendly canvas.',
    note: 'The quick preview keeps feedback fast and the UI uncluttered.',
    icon: Icons.screenshot_monitor_rounded,
    accent: Color(0xFFD97706),
    bullets: <String>[
      'Watch the active screen update',
      'Track progress with one glance',
      'Stay in the same window while you work',
    ],
  ),
  FlowStage(
    title: 'Polish and ship',
    subtitle: 'Finish with a clean export and a simple next step.',
    note: 'The final pass leaves the editor light instead of crowded.',
    icon: Icons.rocket_launch_rounded,
    accent: Color(0xFF7C3AED),
    bullets: <String>[
      'Keep the last review short',
      'Save the generated files to disk',
      'Move straight to the real app',
    ],
  ),
];
