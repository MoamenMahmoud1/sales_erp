"""Business permissions for invoice operations."""

from rest_framework.permissions import BasePermission


class InvoicePermission(BasePermission):
    """Read for any authenticated user; writes require a business permission."""

    ACTION_PERMISSIONS = {
        "create": "invoices.add_invoice",
        "acreate": "invoices.add_invoice",
        "confirm": "invoices.confirm_invoice",
        "cancel": "invoices.cancel_invoice",
        "apply_coupon": "invoices.apply_invoice_coupon",
    }

    async def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False

        if request.method in ("GET", "HEAD", "OPTIONS"):
            return True

        if request.user.is_staff or request.user.is_superuser:
            return True

        codename = self.ACTION_PERMISSIONS.get(getattr(view, "action", None))
        if not codename:
            return False

        return await request.user.ahas_perm(codename)
