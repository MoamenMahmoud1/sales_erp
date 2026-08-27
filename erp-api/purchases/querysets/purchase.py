from django.db import models


class PurchaseQuerySet(models.QuerySet):

    def for_list(self):
        return self.select_related("supplier").only(
            "id",
            "supplier",
            "status",
            "reference",
            "created_at",
        )

    def for_detail(self):
        return self.select_related(
            "supplier",
            "created_by",
        ).prefetch_related(
            "items__product",
        )

    def visible_to(self, user):
        return self.filter(created_by=user)