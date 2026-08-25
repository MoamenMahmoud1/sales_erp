from django.contrib import admin

from .models import CartonPricing, Product


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ("name", "price", "stock_quantity", "created_at")
    search_fields = ("name",)


@admin.register(CartonPricing)
class CartonPricingAdmin(admin.ModelAdmin):
    list_display = ("name", "units_per_carton", "carton_price")
    search_fields = ("name",)