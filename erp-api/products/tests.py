from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase

from products.models import Product


class ProductApiTests(APITestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(
            username="product-user",
            email="product-user@example.com",
            password="StrongPass123!",
            is_active=True,
            is_verified=True,
        )
        self.staff = User.objects.create_user(
            username="product-staff",
            email="product-staff@example.com",
            password="StrongPass123!",
            is_active=True,
            is_verified=True,
            is_staff=True,
        )

    def test_authenticated_user_can_read_products(self):
        self.client.force_authenticate(self.user)
        response = self.client.get("/api/v1/products/")
        self.assertEqual(response.status_code, 200)

    def test_regular_user_cannot_create_product(self):
        self.client.force_authenticate(self.user)
        response = self.client.post(
            "/api/v1/products/",
            {"name": "Blocked", "price": "10.00", "stock_quantity": 5},
            format="json",
        )
        self.assertEqual(response.status_code, 403)

    def test_staff_can_create_product_with_inventory(self):
        self.client.force_authenticate(self.staff)
        response = self.client.post(
            "/api/v1/products/",
            {"name": "Widget", "price": "10.00", "stock_quantity": 5},
            format="json",
        )
        self.assertEqual(response.status_code, 201)
        product = Product.objects.get(name="Widget")
        self.assertEqual(product.price, Decimal("10.00"))
        self.assertEqual(product.stock_quantity, 5)