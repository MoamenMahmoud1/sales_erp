from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("invoices", "0004_alter_invoice_options"),
    ]

    operations = [
        migrations.AddIndex(
            model_name="invoiceitem",
            index=models.Index(
                fields=("product", "invoice"),
                include=("quantity",),
                name="invoice_item_product_inv_idx",
            ),
        ),
    ]
