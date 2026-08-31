from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("inventory", "0005_remove_redundant_stockbalance_index"),
    ]

    operations = [
        migrations.AddIndex(
            model_name="stockbalance",
            index=models.Index(
                fields=("product",),
                include=("quantity",),
                name="stock_balance_product_qty_idx",
            ),
        ),
    ]
