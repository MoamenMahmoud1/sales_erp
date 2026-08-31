from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("products", "0005_remove_product_stock_quantity"),
    ]

    operations = [
        migrations.RemoveIndex(
            model_name="product",
            name="products_product_name_idx",
        ),
        migrations.AddIndex(
            model_name="product",
            index=models.Index(
                fields=("name", "pk"),
                name="products_product_name_pk_idx",
            ),
        ),
    ]
