# Frontend

This folder contains a minimal Flutter scaffold for the music school app.

To fully initialize the Flutter project locally (if Flutter is installed), run:

```bash
flutter create frontend
```

Or open this folder in an IDE with Flutter support.

## API base URL

The frontend reads `API_BASE_URL` from a Flutter compile-time define.

Examples:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

```bash
flutter build web --dart-define=API_BASE_URL=https://api.tkazantsev.org
```

If `API_BASE_URL` is not provided, it falls back to `assets/config.json`.
