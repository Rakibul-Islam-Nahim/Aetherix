# Aetherix Flutter app

Cross-platform client (Android + Windows). State management: **Riverpod**,
networking: **Dio**, navigation: **go_router**.

## Run

The repository assumes you use **FVM** (Flutter Version Management). On a
fresh machine:

```bash
fvm install stable
fvm global stable
cd flutter/Aetherix_app
fvm flutter pub get
fvm flutter run                       # picks your default device
fvm flutter run -d windows            # Windows desktop
fvm flutter run -d emulator-5554      # specific Android device
```

## Build

```bash
# Android APK
fvm flutter build apk --release \
  --dart-define=AETHERIX_API_BASE_URL=https://news.cybersentinel.top/api/v1

# Windows
fvm flutter build windows --release \
  --dart-define=AETHERIX_API_BASE_URL=https://news.cybersentinel.top/api/v1
```

## Layout

```
lib/
├── main.dart                  # runApp(ProviderScope(...))
├── app/
│   └── app.dart               # MaterialApp + GoRouter shell + nav bar
├── core/
│   ├── network/dio_config.dart
│   └── theme/app_theme.dart
├── features/
│   ├── home/home_page.dart
│   ├── news/{latest_page,article_page}.dart
│   ├── categories/categories_page.dart
│   ├── bookmarks/bookmarks_page.dart
│   ├── search/search_page.dart
│   └── settings/settings_page.dart
├── models/article.dart
└── services/news_service.dart
```

## Auth

For V1 there is no login flow. On first launch the app registers a
device against the backend (`POST /api/v1/auth/register-device`) and stores
the returned JWT in shared_preferences. The Dio interceptor adds
`Authorization: Bearer <token>` automatically.