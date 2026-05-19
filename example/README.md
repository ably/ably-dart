# Ably Dart SDK — Example App

A Flutter application demonstrating the [ably](https://pub.dev/packages/ably) Dart SDK. Runs on macOS, Linux, Windows, Web, Android, and iOS.

## What it demonstrates

- **Realtime** — connect/disconnect, channel attach/detach, subscribe/publish messages, encryption
- **REST** — publish messages, retrieve message history, presence members and history, encryption
- **Presence** — enter/leave/update presence, subscribe to presence events, get current members
- **Push Notifications** — stub showing this requires [ably-flutter](https://github.com/ably/ably-flutter) for native platform hooks

## Running the app

```sh
cd example
flutter pub get
ABLY_KEY=your-app.key:secret flutter run -d macos  # or chrome, linux, windows, android, ios   # or: linux, windows, chrome, android, ios
```
