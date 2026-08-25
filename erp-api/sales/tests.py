from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase

from .models import Invoice, InvoiceItem, Product


class SalesApiTests(APITestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(
            username="sales-user",
            email="sales-user@example.com",
            password="StrongPass123!",
            is_active=True,
            is_verified=True,
        )
        self.staff = User.objects.create_user(
            username="sales-staff",
            email="sales-staff@example.com",
            password="StrongPass123!",
            is_active=True,
            is_verified=True,
            is_staff=True,
        )

    def test_authenticated_user_can_read_products(self):
        self.client.force_authenticate(self.user)
        response = self.client.get("/api/v1/sales/products/")
        self.assertEqual(response.status_code, 200)

    def test_regular_user_cannot_create_product(self):
        self.client.force_authenticate(self.user)
        response = self.client.post(
            "/api/v1/sales/products/",
            {"name": "Blocked", "price": "10.00", "stock_quantity": 5},
            format="json",
        )
        self.assertEqual(response.status_code, 403)

    def test_staff_can_create_product_with_inventory(self):
        self.client.force_authenticate(self.staff)
        response = self.client.post(
            "/api/v1/sales/products/",
            {"name": "Widget", "price": "10.00", "stock_quantity": 5},
            format="json",
        )
        self.assertEqual(response.status_code, 201)
        product = Product.objects.get(name="Widget")
        self.assertEqual(product.price, Decimal("10.00"))
        self.assertEqual(product.stock_quantity, 5)

    def test_product_inventory_fields_are_calculated(self):
        product = Product.objects.create(
            name="Stocked",
            price=Decimal("4.00"),
            stock_quantity=10,
        )
        invoice = Invoice.objects.create(
            customer_id=self._customer().pk,
            created_by=self.staff,
        )
        InvoiceItem.objects.create(
            invoice=invoice,
            product=product,
            quantity=3,
            unit_price=product.price,
        )

        self.client.force_authenticate(self.user)
        response = self.client.get("/api/v1/sales/products/")
        item = next(value for value in response.data["results"] if value["id"] == product.pk)
        self.assertEqual(item["sold_quantity"], 3)
        self.assertEqual(item["remaining_quantity"], 7)

    def _customer(self):
        from .models import Customer

        return Customer.objects.create(name="Customer")
