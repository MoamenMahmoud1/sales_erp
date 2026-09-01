"""Business permissions for payment operations."""

from rest_framework.permissions import BasePermission


class CollectionPermission(BasePermission):
    """Processing a collection requires the ``payments.process_collection`` perm."""

    async def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.user.is_staff or request.user.is_superuser:
            return True
        return await request.user.ahas_perm("payments.process_collection")


class TransactionReadPermission(BasePermission):
    """List/retrieve collections requires the view permission (or admin fallback)."""

    async def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.user.is_staff or request.user.is_superuser:
            return True
        return await request.user.ahas_perm("payments.view_paymenttransaction")
