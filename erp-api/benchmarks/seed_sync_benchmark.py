#!/usr/bin/env python3
import os, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
os.chdir(ROOT)
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

@transaction.atomic
def seed():
    User = get_user_model()
    user, _ = User.objects.get_or_create(username="benchmark_user", defaults={"email":"benchmark@example.com", "is_active":True, "is_verified":True})
    customer, _ = Customer.objects.get_or_create(name="Benchmark Customer")
    count = int(os.getenv("BENCH_PRODUCTS", "2000"))
    products = list(Product.objects.all()[:count])
    if len(products) < count:
        products.extend(Product.objects.bulk_create([Product(name=f"Benchmark Product {i:05d}", purchase_price="10.00", selling_price="15.00") for i in range(len(products), count)], batch_size=500))
    location, _ = StockLocation.objects.get_or_create(name="Benchmark Warehouse", defaults={"location_type":StockLocation.LocationType.MAIN_WAREHOUSE})
    StockBalance.objects.bulk_create([StockBalance(location=location, product=p, quantity=100) for p in products], batch_size=500, ignore_conflicts=True)
    target = int(os.getenv("BENCH_INVOICE_ITEMS", "5000"))
    existing = InvoiceItem.objects.count()
    if existing < target:
        invoices = Invoice.objects.bulk_create([Invoice(customer=customer, created_by=user, status=Invoice.Status.CONFIRMED if i % 2 else Invoice.Status.PAID) for i in range(target-existing)], batch_size=500)
        InvoiceItem.objects.bulk_create([InvoiceItem(invoice=inv, product=products[i % len(products)], quantity=(i % 9)+1, unit_price="15.00") for i, inv in enumerate(invoices)], batch_size=500)
    Path("bench_token.txt").write_text(str(AccessToken.for_user(user)), encoding="utf-8")
    print(f"products={Product.objects.count()} invoice_items={InvoiceItem.objects.count()}")

if __name__ == "__main__":
    seed()
