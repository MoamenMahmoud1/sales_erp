import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../data/local_product_repository.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';
import 'product_form_page.dart';

class ProductsPage extends StatefulWidget {
  final ProductRepository? repository;
  final bool carMode;

  const ProductsPage({
    super.key,
    this.repository,
    this.carMode = false,
  });

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _repository = LocalProductRepository();
  final _searchController = TextEditingController();

  List<Product> _allProducts = [];
  List<Product> _products = [];
  bool _isLoading = true;
  String? _errorMessage;

  ProductRepository get _dataSource => widget.repository ?? _repository;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _allProducts
        : _allProducts.where((product) {
            return product.name.toLowerCase().contains(query);
          }).toList();

    if (!mounted) return;
    setState(() => _products = filtered);
  }

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final products = await _dataSource.getProducts();
      if (!mounted) return;
      setState(() {
        _allProducts = products;
        _isLoading = false;
      });
      _onSearchChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load products.';
      });
    }
  }

  Future<void> _openProductForm({Product? product}) async {
    final saved = await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) => ProductFormPage(
          product: product,
          repository: _dataSource,
          carMode: widget.carMode,
        ),
      ),
    );

    if (saved != null && mounted) {
      await _loadProducts();
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete product?'),
          content: Text('Delete ${product.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _dataSource.deleteProduct(product.id);
      if (!mounted) return;
      await _loadProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete product: $error')),
      );
    }
  }

  Widget _buildHeader(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Products', style: AppTextStyles.headline(context)),
                const SizedBox(height: 4),
                Text(
                  '${_products.length} ${_products.length == 1 ? 'product' : 'products'}',
                  style: AppTextStyles.caption(context).copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          FilledButton.icon(
            onPressed: _openProductForm,
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('Add product'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search products',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: _searchController.clear,
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }

  Widget _buildProductRow(BuildContext context, Product product) {
    final colors = AppColors.of(context);
    final subtitle = widget.carMode
        ? 'Buy ${product.purchasePrice.toStringAsFixed(2)} EGP · Sell ${product.sellingPrice.toStringAsFixed(2)} EGP'
        : '${product.price.toStringAsFixed(2)} EGP';
    final initial = product.name.trim().isEmpty
        ? '?'
        : product.name.trim()[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: AppRadius.mdAll,
            ),
            child: Text(
              initial,
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title(context).copyWith(fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(context).copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PopupMenuButton<String>(
            tooltip: 'Product actions',
            onSelected: (value) {
              if (value == 'edit') {
                _openProductForm(product: product);
              } else if (value == 'delete') {
                _deleteProduct(product);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 42,
                color: AppColors.of(context).error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _loadProducts,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadProducts,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            88,
            AppSpacing.lg,
            120,
          ),
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 52,
              color: AppColors.of(context).textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _searchController.text.trim().isEmpty
                  ? 'No products yet'
                  : 'No products found',
              textAlign: TextAlign.center,
              style: AppTextStyles.title(context),
            ),
            const SizedBox(height: 6),
            Text(
              _searchController.text.trim().isEmpty
                  ? 'Add a product to start building your catalog.'
                  : 'Try a different product name.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(context).copyWith(
                color: AppColors.of(context).textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          120,
        ),
        itemCount: 1,
        itemBuilder: (context, _) {
          return AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < _products.length; index++) ...[
                  _buildProductRow(context, _products[index]),
                  if (index < _products.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          _buildSearch(context),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }
}
