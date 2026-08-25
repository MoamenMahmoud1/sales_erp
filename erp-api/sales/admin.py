from django.contrib import admin

from .models import Coupon, Customer, Invoice, InvoiceItem, Payment, Product


@admin.register(Customer)
class CustomerAdmin(admin.ModelAdmin):
    list_display = ("name", "phone", "created_at")
    search_fields = ("name", "phone")


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ("name", "price", "stock_quantity", "created_at")
    search_fields = ("name",)


@admin.register(Coupon)
class CouponAdmin(admin.ModelAdmin):
    list_display = ("name", "units_per_carton", "carton_price")
    search_fields = ("name",)


class InvoiceItemInline(admin.TabularInline):
    model = InvoiceItem
    extra = 0


@admin.register(Invoice)
class InvoiceAdmin(admin.ModelAdmin):
    list_display = ("id", "customer", "created_by", "created_at", "total")
    list_filter = ("created_at",)
    inlines = (InvoiceItemInline,)


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ("invoice", "amount", "method", "status", "created_at")
    list_filter = ("method", "status")
