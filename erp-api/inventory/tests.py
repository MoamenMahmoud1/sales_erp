from django.contrib.auth import get_user_model
from django.test import TestCase

from products.models import Product

from .models import StockLocation, StockMovement, StockMovementItem


User = get_user_model()


class StockLocationTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
    username="stock-user",
    email="stock-user@example.com",
    password="test-password",
)

    def test_create_main_warehouse(self):
        location = StockLocation.objects.create(
            name="Main Warehouse",
            location_type=StockLocation.LocationType.MAIN_WAREHOUSE,
        )

        self.assertEqual(
            location.location_type,
            StockLocation.LocationType.MAIN_WAREHOUSE,
        )
        self.assertTrue(location.is_active)

    def test_sales_vehicle_can_be_assigned_to_employee(self):
        location = StockLocation.objects.create(
            name="Van 01",
            location_type=StockLocation.LocationType.SALES_VEHICLE,
            employee=self.user,
        )

        self.assertEqual(location.employee, self.user)
        self.assertEqual(
            location.location_type,
            StockLocation.LocationType.SALES_VEHICLE,
        )


class StockMovementTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
    username="stock-user",
    email="stock-user@example.com",
    password="test-password",
)

        self.warehouse = StockLocation.objects.create(
            name="Main Warehouse",
            location_type=StockLocation.LocationType.MAIN_WAREHOUSE,
        )

        self.vehicle = StockLocation.objects.create(
            name="Van 01",
            location_type=StockLocation.LocationType.SALES_VEHICLE,
            employee=self.user,
        )

        self.product = Product.objects.create(
            name="Test Product",
            price="100.00",
        )

    def test_transfer_movement(self):
        movement = StockMovement.objects.create(
            movement_type=StockMovement.MovementType.TRANSFER,
            source_location=self.warehouse,
            destination_location=self.vehicle,
            created_by=self.user,
            reference="TRANSFER-001",
        )

        item = StockMovementItem.objects.create(
            movement=movement,
            product=self.product,
            quantity=20,
        )

        self.assertEqual(movement.source_location, self.warehouse)
        self.assertEqual(movement.destination_location, self.vehicle)
        self.assertEqual(item.product, self.product)
        self.assertEqual(item.quantity, 20)

    def test_movement_can_have_multiple_products(self):
        second_product = Product.objects.create(
            name="Second Product",
            price="50.00",
        )

        movement = StockMovement.objects.create(
            movement_type=StockMovement.MovementType.PURCHASE,
            destination_location=self.warehouse,
            created_by=self.user,
        )

        StockMovementItem.objects.create(
            movement=movement,
            product=self.product,
            quantity=10,
        )

        StockMovementItem.objects.create(
            movement=movement,
            product=second_product,
            quantity=5,
        )

        self.assertEqual(movement.items.count(), 2)