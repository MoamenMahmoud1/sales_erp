from decimal import Decimal

from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APITestCase

from common.exceptions import (
    CouponInvalid,
    InvalidStateTransition,
)
from coupons.models import Coupon
from customers.models import Customer
from invoices.models import Invoice, InvoiceItem
from invoices.services import ApplyCoupon, CancelInvoice, ConfirmInvoice
from products.models import Product


class BaseInvoiceTest(TestCase):
    def setUp(self):
        User = get_user_model()
        self.staff = User.objects.create_user(
            username="inv-staff",
            email="inv-staff@example.com",
            password="StrongPass123!",
            is_active=True,
            is_verified=True,
            is_staff=True,
        )
        self.customer = Customer.objects.create(name="Acme")
        self.product = Product.objects.create(
            name="Widget", price=Decimal("100.00"), stock_quantity=50
        )

    def _make_invoice(self, quantity=1):
        invoice = Invoice.objects.create(
            customer=self.customer, created_by=self.staff
        )
        InvoiceItem.objects.create(
            invoice=invoice,
            product=self.product,
            quantity=quantity,
            unit_price=self.product.price,
        )
        return invoice

    def _make_coupon(
        self,
        code="SAVE10",
        discount_type=Coupon.DiscountType.PERCENTAGE,
        discount_value=Decimal("10"),
        **kwargs,
    ):
        return Coupon.objects.create(
            code=code,
            discount_type=discount_type,
            discount_value=discount_value,
            **kwargs,
        )


class InvoiceLifecycleTests(BaseInvoiceTest):
    def test_new_invoice_is_draft(self):
        invoice = self._make_invoice()
        self.assertEqual(invoice.status, Invoice.Status.DRAFT)

    def test_draft_can_be_confirmed(self):
        invoice = self._make_invoice()
        returned = ConfirmInvoice()(invoice_id=invoice.pk)
        self.assertEqual(returned.status, Invoice.Status.CONFIRMED)
        invoice.refresh_from_db()
        self.assertEqual(invoice.status, Invoice.Status.CONFIRMED)

    def test_draft_can_be_cancelled(self):
        invoice = self._make_invoice()
        CancelInvoice()(invoice_id=invoice.pk)
        invoice.refresh_from_db()
        self.assertEqual(invoice.status, Invoice.Status.CANCELLED)

    def test_confirmed_can_be_cancelled(self):
        invoice = self._make_invoice()
        ConfirmInvoice()(invoice_id=invoice.pk)
        CancelInvoice()(invoice_id=invoice.pk)
        invoice.refresh_from_db()
        self.assertEqual(invoice.status, Invoice.Status.CANCELLED)

    def test_confirm_already_confirmed_rejected(self):
        invoice = self._make_invoice()
        ConfirmInvoice()(invoice_id=invoice.pk)
        with self.assertRaises(InvalidStateTransition):
            ConfirmInvoice()(invoice_id=invoice.pk)

    def test_cancel_cancelled_rejected(self):
        invoice = self._make_invoice()
        CancelInvoice()(invoice_id=invoice.pk)
        with self.assertRaises(InvalidStateTransition):
            CancelInvoice()(invoice_id=invoice.pk)

    def test_cancel_paid_rejected(self):
        invoice = self._make_invoice()
        invoice.status = Invoice.Status.PAID
        invoice.save(update_fields=("status",))
        with self.assertRaises(InvalidStateTransition):
            CancelInvoice()(invoice_id=invoice.pk)

    def test_confirm_after_cancel_rejected(self):
        invoice = self._make_invoice()
        CancelInvoice()(invoice_id=invoice.pk)
        with self.assertRaises(InvalidStateTransition):
            ConfirmInvoice()(invoice_id=invoice.pk)

    def test_concurrent_confirm_only_one_succeeds(self):
        # SQLite serializes writes; on PostgreSQL, SelectForUpdate locks the
        # row. Either way the second operator re-reads the committed state and
        # must be rejected — the state guard is the source of truth.
        invoice = self._make_invoice()
        first = ConfirmInvoice()(invoice_id=invoice.pk)
        self.assertEqual(first.status, Invoice.Status.CONFIRMED)
        with self.assertRaises(InvalidStateTransition):
            ConfirmInvoice()(invoice_id=invoice.pk)
        invoice.refresh_from_db()
        self.assertEqual(invoice.status, Invoice.Status.CONFIRMED)


class InvoiceMoneyTests(BaseInvoiceTest):
    def test_subtotal_and_total(self):
        invoice = self._make_invoice(quantity=3)
        self.assertEqual(invoice.subtotal, Decimal("300.00"))
        self.assertEqual(invoice.discount, Decimal("0.00"))
        self.assertEqual(invoice.total, Decimal("300.00"))

    def test_fixed_discount_rounding_and_total(self):
        invoice = self._make_invoice(quantity=3)  # subtotal 300
        coupon = self._make_coupon(
            code="FIXED",
            discount_type=Coupon.DiscountType.FIXED,
            discount_value=Decimal("25.00"),
        )
        ApplyCoupon()(invoice_id=invoice.pk, code=coupon.code)
        invoice.refresh_from_db()
        self.assertEqual(invoice.coupon_discount, Decimal("25.00"))
        self.assertEqual(invoice.total, Decimal("275.00"))

    def test_percentage_discount(self):
        invoice = self._make_invoice(quantity=3)  # subtotal 300
        coupon = self._make_coupon(
            code="PCT",
            discount_type=Coupon.DiscountType.PERCENTAGE,
            discount_value=Decimal("33.33"),
        )
        ApplyCoupon()(invoice_id=invoice.pk, code=coupon.code)
        invoice.refresh_from_db()
        # 300 * 33.33 / 100 = 99.99
        self.assertEqual(invoice.coupon_discount, Decimal("99.99"))
        self.assertEqual(invoice.total, Decimal("200.01"))

    def test_percentage_discount_rounds_half_up(self):
        # Product priced 0.09; 1 unit = 0.09 subtotal.
        product = Product.objects.create(
            name="Odd", price=Decimal("0.09"), stock_quantity=1
        )
        invoice = Invoice.objects.create(
            customer=self.customer, created_by=self.staff
        )
        InvoiceItem.objects.create(
            invoice=invoice,
            product=product,
            quantity=1,
            unit_price=Decimal("0.09"),
        )
        # 0.09 * 50 / 100 = 0.045 -> ROUND_HALF_UP -> 0.05 (not 0.04).
        coupon = self._make_coupon(code="HALF", discount_value=Decimal("50"))
        ApplyCoupon()(invoice_id=invoice.pk, code=coupon.code)
        invoice.refresh_from_db()
        self.assertEqual(invoice.coupon_discount, Decimal("0.05"))
        self.assertEqual(invoice.total, Decimal("0.04"))

    def test_one_hundred_percent_discount_allowed(self):
        invoice = self._make_invoice(quantity=1)
        coupon = self._make_coupon(
            code="FREE", discount_value=Decimal("100")
        )
        ApplyCoupon()(invoice_id=invoice.pk, code=coupon.code)
        invoice.refresh_from_db()
        self.assertEqual(invoice.coupon_discount, Decimal("100.00"))
        self.assertEqual(invoice.total, Decimal("0.00"))

    def test_fixed_discount_exceeding_subtotal_rejected(self):
        invoice = self._make_invoice(quantity=1)  # subtotal 100
        coupon = self._make_coupon(
            code="BIGFIX",
            discount_type=Coupon.DiscountType.FIXED,
            discount_value=Decimal("150.00"),
        )
        from common.exceptions import InvalidDiscount

        with self.assertRaises(InvalidDiscount):
            ApplyCoupon()(invoice_id=invoice.pk, code=coupon.code)

    def test_percentage_over_100_rejected_at_model(self):
        with self.assertRaises(ValidationError):
            self._make_coupon(
                code="OVER", discount_value=Decimal("150")
            ).full_clean()


class InvoiceCouponTests(BaseInvoiceTest):
    def test_valid_coupon_applies(self):
        invoice = self._make_invoice(quantity=2)  # 200
        coupon = self._make_coupon(code="VALID", discount_value=Decimal("10"))
        ApplyCoupon()(invoice_id=invoice.pk, code=coupon.code)
        invoice.refresh_from_db()
        self.assertEqual(invoice.coupon.pk, coupon.pk)
        self.assertEqual(invoice.coupon_discount, Decimal("20.00"))

    def test_inactive_coupon_rejected(self):
        invoice = self._make_invoice()
        coupon = self._make_coupon(code="INAC", is_active=False)
        with self.assertRaises(CouponInvalid):
            ApplyCoupon()(invoice_id=invoice.pk, code=coupon.code)

    def test_expired_coupon_rejected(self):
        invoice = self._make_invoice()
        coupon = self._make_coupon(
            code="EXP",
            valid_from=timezone.now() - timezone.timedelta(days=10),
            valid_until=timezone.now() - timezone.timedelta(days=1),
        )
        with self.assertRaises(CouponInvalid):
            ApplyCoupon()(invoice_id=invoice.pk, code=coupon.code)

    def test_not_yet_valid_coupon_rejected(self):
        invoice = self._make_invoice()
        coupon = self._make_coupon(
            code="FUTURE",
            valid_from=timezone.now() + timezone.timedelta(days=1),
            valid_until=timezone.now() + timezone.timedelta(days=10),
        )
        with self.assertRaises(CouponInvalid):
            ApplyCoupon()(invoice_id=invoice.pk, code=coupon.code)

    def test_minimum_invoice_amount_rejected(self):
        invoice = self._make_invoice(quantity=1)  # 100
        coupon = self._make_coupon(
            code="MIN",
            minimum_invoice_amount=Decimal("500.00"),
        )
        with self.assertRaises(CouponInvalid):
            ApplyCoupon()(invoice_id=invoice.pk, code=coupon.code)

    def test_minimum_invoice_amount_satisfied(self):
        invoice = self._make_invoice(quantity=10)  # 1000
        coupon = self._make_coupon(
            code="MINOK", minimum_invoice_amount=Decimal("500.00")
        )
        ApplyCoupon()(invoice_id=invoice.pk, code=coupon.code)
        invoice.refresh_from_db()
        self.assertEqual(invoice.coupon.pk, coupon.pk)

    def test_unknown_coupon_rejected(self):
        invoice = self._make_invoice()
        with self.assertRaises(CouponInvalid):
            ApplyCoupon()(invoice_id=invoice.pk, code="nope")

    def test_coupon_cannot_be_applied_after_confirm(self):
        invoice = self._make_invoice()
        ConfirmInvoice()(invoice_id=invoice.pk)
        coupon = self._make_coupon(code="LATE")
        with self.assertRaises(InvalidStateTransition):
            ApplyCoupon()(invoice_id=invoice.pk, code=coupon.code)

    def test_confirmed_invoice_frozen_against_coupon_changes(self):
        invoice = self._make_invoice(quantity=2)  # 200
        coupon = self._make_coupon(code="FIRST", discount_value=Decimal("10"))
        ApplyCoupon()(invoice_id=invoice.pk, code=coupon.code)
        ConfirmInvoice()(invoice_id=invoice.pk)
        invoice.refresh_from_db()
        self.assertEqual(invoice.coupon_discount, Decimal("20.00"))
        self.assertEqual(invoice.total, Decimal("180.00"))

        # Edit the coupon afterwards; the invoice must remain unchanged.
        coupon.discount_value = Decimal("50")
        coupon.save()
        invoice.refresh_from_db()
        self.assertEqual(invoice.coupon_discount, Decimal("20.00"))
        self.assertEqual(invoice.total, Decimal("180.00"))


class InvoiceSnapshotTests(BaseInvoiceTest):
    def test_product_price_change_does_not_alter_unit_price(self):
        invoice = self._make_invoice(quantity=1)
        item = invoice.items.get()
        self.assertEqual(item.unit_price, Decimal("100.00"))

        self.product.price = Decimal("150.00")
        self.product.save()
        item.refresh_from_db()
        self.assertEqual(item.unit_price, Decimal("100.00"))
        self.assertEqual(invoice.subtotal, Decimal("100.00"))


class InvoiceAPITests(APITestCase):
    def setUp(self):
        User = get_user_model()
        self.staff = User.objects.create_user(
            username="api-staff",
            email="api-staff@example.com",
            password="StrongPass123!",
            is_active=True,
            is_verified=True,
            is_staff=True,
        )
        self.user = User.objects.create_user(
            username="api-user",
            email="api-user@example.com",
            password="StrongPass123!",
            is_active=True,
            is_verified=True,
        )
        self.customer = Customer.objects.create(name="Chris")
        self.product = Product.objects.create(
            name="Gadget", price=Decimal("80.00"), stock_quantity=30
        )
        self.coupon = Coupon.objects.create(
            code="SAVE",
            discount_type=Coupon.DiscountType.PERCENTAGE,
            discount_value=Decimal("10"),
        )

    def _create(self):
        resp = self.client.post(
            "/api/v1/invoices/",
            {
                "customer": self.customer.pk,
                "items": [
                    {"product": self.product.pk, "quantity": 1}
                ],
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 201)
        return resp.data["id"]

    def test_confirm_endpoint(self):
        self.client.force_authenticate(self.staff)
        pk = self._create()
        resp = self.client.post(f"/api/v1/invoices/{pk}/confirm/")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data["status"], Invoice.Status.CONFIRMED)

    def test_cancel_endpoint(self):
        self.client.force_authenticate(self.staff)
        pk = self._create()
        resp = self.client.post(f"/api/v1/invoices/{pk}/cancel/")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data["status"], Invoice.Status.CANCELLED)

    def test_apply_coupon_endpoint(self):
        self.client.force_authenticate(self.staff)
        pk = self._create()
        resp = self.client.post(
            f"/api/v1/invoices/{pk}/apply-coupon/", {"code": "SAVE"},
            format="json",
        )
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data["coupon_discount"], "8.00")
        self.assertEqual(resp.data["total"], "72.00")

    def test_client_cannot_set_status(self):
        self.client.force_authenticate(self.staff)
        pk = self._create()
        self.client.post(f"/api/v1/invoices/{pk}/confirm/")
        resp = self.client.patch(
            f"/api/v1/invoices/{pk}/",
            {"status": "cancelled"},
            format="json",
        )
        # Not allowed because InvoiceViewSet is read+create only.
        self.assertIn(resp.status_code, (403, 405))
        self.assertTrue(
            Invoice.objects.get(pk=pk).status == Invoice.Status.CONFIRMED
        )

    def test_invalid_transition_returns_409(self):
        self.client.force_authenticate(self.staff)
        pk = self._create()
        self.client.post(f"/api/v1/invoices/{pk}/cancel/")
        resp = self.client.post(f"/api/v1/invoices/{pk}/confirm/")
        self.assertEqual(resp.status_code, 409)

    def test_invalid_coupon_returns_400(self):
        self.client.force_authenticate(self.staff)
        pk = self._create()
        resp = self.client.post(
            f"/api/v1/invoices/{pk}/apply-coupon/", {"code": "missing"},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)

    def test_application_cannot_happen_via_serializer(self):
        # A client-provided status is rejected, not applied.
        self.client.force_authenticate(self.staff)
        resp = self.client.post(
            "/api/v1/invoices/",
            {
                "customer": self.customer.pk,
                "status": "paid",
                "coupon_discount": "999",
                "items": [{"product": self.product.pk, "quantity": 1}],
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 201)
        invoice = Invoice.objects.get(pk=resp.data["id"])
        self.assertEqual(invoice.status, Invoice.Status.DRAFT)
        self.assertEqual(invoice.coupon_discount, Decimal("0.00"))
