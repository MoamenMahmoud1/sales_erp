# Sales ERP

A production-oriented Sales ERP backend built with Django, Django REST Framework and ASGI, with a Flutter client in the same repository.

## Backend

The backend lives in [`erp-api/`](erp-api/).

### Core domains

- Accounts and authentication
- Stateful authentication sessions with stateless JWT access tokens
- Organization, employees and role-based permissions
- Customers and suppliers
- Products and carton pricing
- Purchases with atomic stock intake
- Invoices with immutable price snapshots and lifecycle transitions
- Inventory balances plus an immutable stock-movement ledger
- Payment collections with deterministic invoice allocation
- Database-backed idempotency for financial writes

### Architecture

The API is served through ASGI. Async API endpoints delegate transactional business operations to synchronous service boundaries so Django database transactions remain well-defined. PostgreSQL is the system of record; Redis is used for cache/throttling workloads.

Financial operations use database transactions and row-level locking. Current stock is derived from `StockBalance`, while `StockMovement` records the immutable inventory history.

### Authentication

Access requests use stateless JWT authentication. Authorization claims are embedded in the access token so ordinary API authentication does not require a user-table lookup. Refresh tokens and device/session state are stored in `AuthSession`.

Refresh tokens are kept in an HttpOnly cookie, and sensitive authentication operations use CSRF protection and throttling.

## Local backend setup

```bash
cd erp-api
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

For local PostgreSQL and Redis, the repository includes `erp-api/compose.yaml`.

## Testing

Run the complete suite from `erp-api/`:

```bash
python manage.py test
```

CI runs dependency checks, Django deployment checks, migration checks, the full test suite, Python compilation and Ruff against PostgreSQL and Redis service containers.

## Production

Use the production settings and the checked-in Gunicorn configuration:

```bash
DJANGO_SETTINGS_MODULE=core.settings.settings_prod \
gunicorn core.asgi:application -c gunicorn.conf.py
```

The production container runs as a non-root user and collects static files during image build. See `erp-api/Dockerfile` and `erp-api/gunicorn.conf.py` for deployment configuration.
