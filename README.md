# Sales ERP

A production-oriented **Flutter mobile client** for the Sales ERP platform, built for **sales representatives and warehouse staff**.

The app is the mobile counterpart to the [`erp-api`](https://github.com/MoamenMahmoud1/erp-api) backend and shares the same business workflows used by the ERP web application.

## Features

- Authentication and secure session handling
- Sales and customer workflows for field representatives
- Product catalog and carton pricing
- Payment collection workflows
- Sales and inventory operations for warehouse teams
- Coupons and related sales flows
- Local data support and background work
- Secure storage and device authentication

## Architecture

The app follows a feature-oriented **Clean Architecture** structure:

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
flutter run
```

## Related Repository

**Backend + Web:** [`MoamenMahmoud1/erp-api`](https://github.com/MoamenMahmoud1/erp-api)

Together, `sales_erp` and `erp-api` form the mobile and web/API sides of the same ERP platform.

## License

This repository is **proprietary**. All rights are reserved by the copyright holder. No permission is granted to use, copy, modify, distribute, publish, sublicense, or create derivative works from this code without prior written permission. See [`LICENSE`](LICENSE).
