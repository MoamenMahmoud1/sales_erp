# Sales ERP

A Flutter mobile client for the Sales ERP platform, built for sales representatives and warehouse staff.

The app is the mobile counterpart to the `erp-api` backend and shares the same business workflows as the web client.

## Features

- Authentication and secure session handling
- Sales and customer workflows for field representatives
- Product catalog and carton pricing
- Payment collection workflows
- Sales and inventory operations for warehouse teams
- Coupons and related sales flows
- Local data support and durable offline commands
- Secure storage and device authentication
- Durable synchronization with retry, idempotency, and conflict state

## Architecture

The app uses a feature-based structure:

```text
lib/
├── app/
├── core/
└── features/
    ├── auth/
    ├── customers/
    ├── products/
    ├── sales/
    ├── payment/
    ├── coupons/
    └── car/
```

Networking is handled with **Dio**, with secure session/storage support, local persistence, and background task support where needed.

Retryable write operations are stored in the local outbox before the network request. Replays use the same idempotency key, while HTTP 409 conflicts remain in the outbox for user handling.

## API configuration

The production API URL is provided at build time with Dart defines rather than a tracked environment asset:

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

Debug builds use the local development API. Release builds require an explicit `API_BASE_URL`.

## Tech Stack

- Flutter / Dart
- Dio
- SQLite
- Secure Storage
- Local Authentication
- Background WorkManager
- Flutter testing and linting

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

## Related Repository

**Backend + Web:** [`MoamenMahmoud1/erp-api`](https://github.com/MoamenMahmoud1/erp-api)

Together, `sales_erp` and `erp-api` form the mobile and web/API sides of the same ERP platform.

## License

This repository is **proprietary**. All rights reserved by the copyright holder. No permission is granted to use, copy, modify, distribute, publish, sublicense, or create derivative works from this code without prior written permission. See [`LICENSE`](LICENSE).
