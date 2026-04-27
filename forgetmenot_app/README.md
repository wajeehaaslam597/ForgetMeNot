# ForgetMeNot Flutter Frontend (`forgetmenot_app`)

Flutter application for caregiver/patient interaction with the ForgetMeNot backend APIs.

## Tech Stack

`Flutter` `Dart` `Material UI` `HTTP/REST API` `Docker` `Nginx (web container)` `Android` `iOS` `Web`

## Stack Audit

### Current stack tags

`Flutter` `Dart` `Material UI` `HTTP/REST API` `Docker` `Nginx (web container)` `Android` `iOS` `Web`

### What this means in this project

- `Flutter` + `Dart`: single codebase for mobile/web delivery.
- `Material UI`: consistent components and design language.
- `HTTP/REST API`: backend integration for auth, patient data, reminders, and logs.
- `Docker` + `Nginx`: web build hosting path in containerized environments.

### Professional additions recommended

- Environment profile strategy (`dev/staging/prod`) with explicit API targets.
- Stable state management convention with folder-level architecture guide.
- Centralized API client with retry policy, timeouts, and error mapping.
- Widget/integration testing + CI quality gates.
- Secure token storage strategy and session lifecycle policy.
- Accessibility checklist (contrast, touch targets, semantics, localization).

## Feature coverage

- Authentication screens and flow
- Patient selection and context handling
- Reminder viewing and interaction screens
- Voice assistant interaction screens
- Settings and security screens

## Prerequisites

- Flutter SDK installed and healthy (`flutter doctor`)
- Backend service available (local or compose)

## Local development run

```bash
cd forgetmenot_app
flutter pub get
flutter run
```

## Backend API configuration

Base URL is configured in `lib/services/api_service.dart`.

- Emulator on same machine: `http://127.0.0.1:8000`
- Physical device on LAN: use host IP, e.g. `http://192.168.1.10:8000`

For device testing, ensure backend listens on all interfaces:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## Web container run (optional)

```bash
docker compose up --build -d frontend_flutter
```

Access:

- `http://localhost:8090`

## Quality and release commands

```bash
flutter analyze
flutter test
flutter build apk
flutter build web
```

## Troubleshooting

- **App cannot hit backend:** verify base URL and network reachability from device/emulator.
- **CORS/API errors on web:** verify backend CORS and nginx proxy configuration.
- **Build issues:** run `flutter clean` then `flutter pub get`.
- **Inconsistent behavior across targets:** compare Android/iOS/Web environment values.
