from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase

from customers.models import Customer
from invoices.models import Invoice, InvoiceItem
from products.models import Product


class InvoiceDomainApiTests(APITestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(
            username="invoice-user",
            email="invoice-user@example.com",
            password="StrongPass123!",
            is_active=True,
            is_verified=True,
        )
        self.staff = User.objects.create_user(
            username="invoice-staff",
            email="invoice-staff@example.com",
            password="StrongPass123!",
            is_active=True,
            is_verified=True,
            is_staff=True,
        )
        self.customer = Customer.objects.create(name="Customer")

    def test_product_inventory_fields_are_calculated(self):
        product = Product.objects.create(
            name="Stocked",
            price=Decimal("4.00"),
            stock_quantity=10,
        )
        invoice = Invoice.objects.create(
            customer=self.customer,
            created_by=self.staff,
        )
        InvoiceItem.objects.create(
            invoice=invoice,
            product=product,
            quantity=3,
            unit_price=product.price,
        )

        self.client.force_authenticate(self.user)
        response = self.client.get("/api/v1/products/")
        item = next(
            value for value in response.data["results"] if value["id"] == product.pk
        )
        self.assertEqual(item["sold_quantity"], 3)
        self.assertEqual(item["remaining_quantity"], 7)