# Phase 5 — Payment / Collection Domain

## Objective
Replace the monolithic one-to-one `payments.Payment` with a real collection
domain: `PaymentTransaction` + `PaymentAllocation` + `ProcessCollection`.
Backend becomes the financial source of truth for payments, mirroring the
Flutter `PaymentTransaction` / `PaymentAllocation` / `ProcessCollection`
contract.

## Reference behavior (from Flutter)
- A `Payment` is a `(cashAmount, transferAmount)` pair; a transaction is the
  sum across invoices.
- Allocation is greedy / oldest-first: for each of the customer's invoices,
  allocate cash first, then transfer, capped at that invoice's outstanding.
- Reject negative cash/transfer; reject overpayment
  (`totalReceived > totalOutstanding`).
- A zero-amount collection is a no-op (no transaction persisted).
- An invoice becomes PAID when its cumulative allocations reach its total.

## New models (payments app)
- `PaymentTransaction` — customer FK, cash_amount, transfer_amount, created_at.
- `PaymentAllocation` — transaction FK (CASCADE), invoice FK (PROTECT),
  cash_amount, transfer_amount; unique (transaction, invoice).

The old one-to-one `Payment` model is removed; the `"payments"` reverse name
on Invoice is replaced by `payment_allocations`.

## Service (`payments/services.py`)
`ProcessCollection(customer_id, cash_amount, transfer_amount)`:
1. Validate non-negative cash/transfer; reject overpayment against the
   customer's confirmed-invoice outstanding (computed from totals minus
   existing allocations).
2. Lock the confirmed invoices (`select_for_update`) inside
   `transaction.atomic()`.
3. Allocate oldest-first, cash-then-transfer, capped per invoice.
4. Create the transaction + allocation rows.
5. Transition each fully-paid invoice CONFIRMED -> PAID.
6. Return the created transaction and its allocations.

## API
- `POST /api/v1/payments/collections/` — submit `{customer, cash_amount,
  transfer_amount}`; backend computes the allocation (client cannot decide
  the split).
- `GET /api/v1/payments/transactions/` — list transactions (read-only view).
- Old `payments` router removed.

## Concurrency
- Invoice rows are locked with `select_for_update()` during the whole
  collection, so two concurrent collections cannot double-allocate an
  invoice's outstanding.
- Atomic via `transaction.atomic()`: transaction, allocations, and the
  PAID transitions commit as one unit.

## Files
- Create: `payments/services.py`
- Rewrite: `payments/models.py`, `payments/api/serializers.py`,
  `payments/api/views.py`, `payments/urls.py`, `payments/admin.py`
- Modify: `invoices/models.py` (paid_amount/outstanding + drop old reverse),
  `invoices/api/views.py` (remove `payments` prefetch)
- Migration: `payments/0003` (remove Payment, add Transaction + Allocation)
- Tests: `payments/tests.py`