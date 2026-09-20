# Flutter Visual UI Editor

A lightweight desktop editor for shaping Flutter flows on macOS and Windows.

## What is in place

- Flutter SDK detection with common install-path scanning
- A guided install entry point for cloning the stable Flutter channel
- Starter workspace generation with sample Dart files
- In-app editing for the active file
- A quick preview canvas that steps through a full flow
- Workspace export to disk

## Run it

```bash
flutter run -d macos
```

or on Windows:

```bash
flutter run -d windows
```

## Notes

- The app starts with a small starter workspace so you can try the flow immediately.
- Use the left rail to detect or install Flutter, rename the workspace, and add files.
- Use the center editor to modify the active file.
- Use the right rail to run the full flow simulation and watch the preview move.
