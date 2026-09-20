import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_visual_ui_editor/src/editor_app.dart';
import 'package:flutter_visual_ui_editor/src/editor_controller.dart';

void main() {
  testWidgets('App shows the editor shell', (WidgetTester tester) async {
    final controller = EditorController();
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      FlutterVisualUiEditorApp(
        bootstrap: false,
        controller: controller,
      ),
    );
    await tester.pump();

    expect(find.text('Flutter Visual UI Editor'), findsOneWidget);
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('preview-toolbar-button')),
        findsOneWidget);
    final previewCanvas = find.byKey(const ValueKey<String>('preview-canvas'));
    expect(previewCanvas, findsOneWidget);

    final liveTitle = find.descendant(
      of: previewCanvas,
      matching: find.byKey(const ValueKey<String>('live-preview-title')),
    );
    expect(tester.widget<Text>(liveTitle).data, 'Build the flow');

    expect(
      find.descendant(
        of: previewCanvas,
        matching: find.text('Map the journey'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('preview-toolbar-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('preview-canvas')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('preview-toolbar-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('preview-canvas')), findsOneWidget);

    await tester.tap(previewCanvas);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: previewCanvas,
        matching: find.text('Compose the screens'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Editing the active file updates the live preview',
      (WidgetTester tester) async {
    final controller = EditorController();
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      FlutterVisualUiEditorApp(
        bootstrap: false,
        controller: controller,
      ),
    );
    await tester.pump();

    final previewCanvas = find.byKey(const ValueKey<String>('preview-canvas'));
    expect(previewCanvas, findsOneWidget);

    final editorField = find.byKey(const ValueKey<String>('active-file-editor'));
    final liveTitle = find.descendant(
      of: previewCanvas,
      matching: find.byKey(const ValueKey<String>('live-preview-title')),
    );
    expect(tester.widget<Text>(liveTitle).data, 'Build the flow');

    final updatedSource = controller.activeFile!.content.replaceFirst(
      'Build the flow',
      'Design the flow',
    );

    await tester.enterText(editorField, updatedSource);
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(liveTitle).data, 'Design the flow');
  });
}
