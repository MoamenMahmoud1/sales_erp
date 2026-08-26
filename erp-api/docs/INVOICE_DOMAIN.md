# Invoice Domain & Lifecycle

## Scope

The `invoices` app is the authoritative owner of invoice financial state. It
defines the invoice lifecycle, owns all money calculations (via
`InvoiceCalculator`), and exposes business operations (`ConfirmInvoice`,
`CancelInvoice`, `ApplyCoupon`) instead of letting clients mutate state
directly.

## Lifecycle

```
DRAFT
  ├── CONFIRMED   (ConfirmInvoice)
  └── CANCELLED   (CancelInvoice)

CONFIRMED
  ├── CANCELLED   (CancelInvoice)
  └── PAID        (reserved — set by the future payments domain, NOT by the
                   invoice API)
```

- New invoices start `DRAFT`.
- Transitions happen ONLY through the explicit business operations. There is
  no arbitrary `PATCH status`.
- `CANCELLED` and `PAID` are terminal from the invoice API's perspective.
- `PAID` is intentionally not reachable from the invoice domain; the payment
  domain will transition `CONFIRMED -> PAID` in a later phase.

## Authoritative calculation (`invoices/calculator.py`)

There is ONE calculation path (`InvoiceCalculator`). Serializers, views and
model properties all delegate to it — they do not duplicate formulas.

```
items ──> unit_price × quantity ──> subtotal
subtotal ──> (coupon rules) ──> discount ──> total
```

- `subtotal` = Σ(unit_price × quantity), quantized to 2dp (ROUND_HALF_UP).
- `discount` = the persisted `coupon_discount` snapshot.
- `total`   = subtotal − discount (no silent clamping; a negative is a bug).
- percentage discounts: subtotal × value / 100 (value ≤ 100 ⇒ never negative).
- fixed discounts: may not exceed subtotal → raises `InvalidDiscount`.

## Financial immutability

- `InvoiceItem.unit_price` is a historical snapshot taken from
  `Product.price` at creation. Later product price changes never affect it.
- `coupon_discount` is a persisted snapshot written when a coupon is applied.
  Editing or deactivating the coupon afterwards does not change the invoice.
- `status`, `coupon_discount`, `unit_price`, `subtotal`, `total` are all
  read-only in the API; the `InvoiceViewSet` does not expose generic
  update/delete.

## coupon_discount decision (why A, not B)

`coupon_discount` is a persisted **authoritative snapshot** (option A), not a
live derivation from the coupon (option B). Rationale: a coupon is
reference data and may be edited or deactivated after an invoice is finalized.
If totals were derived from the coupon, historical invoices would silently
change. By persisting the discount at the moment it is applied, confirmed
invoices are stable. The client never sets this value.

## Coupon application (`ApplyCoupon`)

Only `DRAFT` invoices can receive/change a coupon. `ApplyCoupon` validates:

- coupon exists, is active
- current time within `valid_from` / `valid_until`
- subtotal ≥ `minimum_invoice_amount`
- discount rules produce a valid non-negative total

The API accepts only a coupon `code`; the backend computes and persists the
discount.

## Concurrency

State transitions run inside `transaction.atomic()` and lock the invoice row
with `select_for_update()`, then re-check the current state. The state guard
(together with row locking on PostgreSQL, DB-level serialization on SQLite)
prevents two operators from confirming/cancelling the same invoice
simultaneously.

## Money

Decimal + ROUND_HALF_UP + no silent clamping (see `docs/MONEY_CONVENTION.md`
and `common/money.py`). No floats anywhere in financial math.