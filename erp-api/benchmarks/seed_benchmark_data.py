#!/usr/bin/env python3
"""Populate a disposable benchmark database with realistic ERP data.

All synthetic benchmark data generation lives here. It is not application
runtime code and can be reused for local or CI benchmark databases.

Usage from the repository root:
    python erp-api/benchmarks/seed_benchmark_data.py

Usage from erp-api:
    python benchmarks/seed_benchmark_data.py

Environment variables:
    BENCH_PRODUCTS=2000
    BENCH_INVOICE_ITEMS=5000
"""

import os
import sys
from pathlib import Path

# Make ``core`` importable when this script is launched by a CI job from the
# repository root (or from any other working directory).
ERP_API_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ERP_API_ROOT))
os.chdir(ERP_API_ROOT)
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings.settings_bench")

import django

django.setup()

from django.contrib.auth import get_user_model
from django.db import transaction
from rest_framework_simplejwt.tokens import AccessToken

from customers.models import Customer
from inventory.models import StockBalance, StockLocation
from invoices.models import Invoice, InvoiceItem
from products.models import Product


PRODUCTS = int(os.environ.get("BENCH_PRODUCTS", "2000"))
INVOICE_ITEMS = int(os.environ.get("BENCH_INVOICE_ITEMS", "5000"))


@transaction.atomic
def seed():
    User = get_user_model()
    user, _ = User.objects.get_or_create(
        username="benchmark_user",
        defaults={
            "email": "benchmark_user@example.com",
            "is_active": True,
            "is_verified": True,
        },
    )
    customer, _ = Customer.objects.get_or_create(name="Benchmark Customer")

    products = list(Product.objects.all()[:PRODUCTS])
    if len(products) < PRODUCTS:
        start = len(products)
        products.extend(
            Product.objects.bulk_create(
                [
                    Product(
                        name=f"Benchmark Product {index:05d}",
                        purchase_price="10.00",
                        selling_price="15.00",
                    )
                    for index in range(start, PRODUCTS)
                ],
                batch_size=500,
            )
        )

    location, _ = StockLocation.objects.get_or_create(
        name="Benchmark Warehouse",
        defaults={
            "location_type": StockLocation.LocationType.MAIN_WAREHOUSE,
        },
    )
    StockBalance.objects.bulk_create(
        [
            StockBalance(location=location, product=product, quantity=100)
            for product in products
        ],
        batch_size=500,
        ignore_conflicts=True,
    )

    existing = InvoiceItem.objects.count()
    if existing < INVOICE_ITEMS:
        invoices = Invoice.objects.bulk_create(
            [
                Invoice(
                    customer=customer,
                    created_by=user,
                    status=(
                        Invoice.Status.CONFIRMED
                        if index % 2
                        else Invoice.Status.PAID
                    ),
                )
                for index in range(INVOICE_ITEMS - existing)
            ],
            batch_size=500,
        )
        InvoiceItem.objects.bulk_create(
            [
                InvoiceItem(
                    invoice=invoice,
                    product=products[index % len(products)],
                    quantity=(index % 9) + 1,
                    unit_price="15.00",
                )
                for index, invoice in enumerate(invoices)
            ],
            batch_size=500,
        )

    with open("bench_token.txt", "w", encoding="utf-8") as output:
        output.write(str(AccessToken.for_user(user)))

    print(
        f"seeded benchmark database: products={Product.objects.count()} "
        f"stock_balances={StockBalance.objects.count()} "
        f"invoice_items={InvoiceItem.objects.count()}"
    )


if __name__ == "__main__":
    seed()
