# StrawHut

A cross-platform encrypted card application built with Flutter.

## Project Structure

```
lib/
├── domain/
│   ├── entities/      # Data models
│   ├── services/      # Service interfaces
│   └── usecases/      # Business logic interfaces
├── data/
│   ├── services/      # Service implementations
│   └── usecases/      # Business logic implementations
└── presentation/
    ├── navigation/    # Routing configuration
    ├── screens/       # UI screens
    ├── widgets/       # Reusable widgets
    └── theme/         # Theme configuration
```

## Getting Started

1. Install Flutter SDK
2. Run `flutter pub get`
3. Run `flutter run -d windows` (Windows)
4. Run `flutter run -d android` (Android)

## Architecture

Clean Architecture with three layers:
- **Domain Layer**: Core business logic, entities, and interfaces
- **Data Layer**: Implementations of interfaces, data sources
- **Presentation Layer**: UI, state management, navigation
