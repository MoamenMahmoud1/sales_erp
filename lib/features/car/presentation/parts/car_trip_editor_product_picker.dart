part of '../car_trip_editor_page.dart';

enum _CreateProductAction { create }

class _CarProductPicker extends StatefulWidget {
  final List<Product> products;
  final Set<int> selectedIds;

  const _CarProductPicker({required this.products, required this.selectedIds});

  @override
  State<_CarProductPicker> createState() => _CarProductPickerState();
}

class _CarProductPickerState extends State<_CarProductPicker> {
  final _searchController = TextEditingController();
  late final Set<int> _selectedIds = {...widget.selectedIds};
  final Set<String> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchController.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  List<Product> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.products;
    return widget.products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  Map<String, List<Product>> get _groups {
    final result = <String, List<Product>>{};
    for (final product in _filteredProducts) {
      result.putIfAbsent(product.category, () => []).add(product);
    }
    final entries = result.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return {for (final entry in entries) entry.key: entry.value};
  }

  void _toggleCategory(String category, bool expanded) {
    setState(() {
      if (expanded) {
        _expandedCategories.add(category);
      } else {
        _expandedCategories.remove(category);
      }
    });
  }

  void _toggleProduct(Product product) {
    setState(() {
      if (_selectedIds.contains(product.id)) {
        _selectedIds.remove(product.id);
      } else {
        _selectedIds.add(product.id);
      }
    });
  }

  void _selectCategory(List<Product> products) {
    setState(() {
      final ids = products.map((p) => p.id).toSet();
      if (ids.every(_selectedIds.contains)) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds.addAll(ids);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = _groups;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .82,
          minChildSize: .55,
          maxChildSize: .96,
          builder: (context, scrollController) {
            return Material(
              color: scheme.surface,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add products',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_selectedIds.length} selected · choose by category',
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search products or categories',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: _searchController.clear,
                                icon: const Icon(Icons.clear_rounded),
                              ),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: groups.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No products found.'),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            itemCount: groups.length + 1,
                            itemBuilder: (context, index) {
                              if (index == groups.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                                  child: ListTile(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    tileColor: scheme.surfaceContainerHighest,
                                    leading: const Icon(Icons.inventory_2_outlined),
                                    title: const Text('Create a new product', style: TextStyle(fontWeight: FontWeight.w800)),
                                    subtitle: const Text('Add it to the local catalog'),
                                    trailing: const Icon(Icons.chevron_right_rounded),
                                    onTap: () => Navigator.of(context).pop(_CreateProductAction.create),
                                  ),
                                );
                              }

                              final entry = groups.entries.elementAt(index);
                              final category = entry.key;
                              final products = entry.value;
                              final selectedCount = products.where((product) => _selectedIds.contains(product.id)).length;
                              final allSelected = selectedCount == products.length && products.isNotEmpty;
                              final isExpanded = _searchController.text.trim().isNotEmpty || _expandedCategories.contains(category);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                clipBehavior: Clip.antiAlias,
                                child: ExpansionTile(
                                  initiallyExpanded: isExpanded,
                                  onExpansionChanged: (expanded) => _toggleCategory(category, expanded),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(category, style: const TextStyle(fontWeight: FontWeight.w900)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: selectedCount > 0 ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '$selectedCount/${products.length}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: selectedCount > 0 ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        tooltip: allSelected ? 'Clear category' : 'Select category',
                                        onPressed: () => _selectCategory(products),
                                        icon: Icon(
                                          allSelected
                                              ? Icons.check_box_rounded
                                              : Icons.check_box_outline_blank_rounded,
                                          size: 21,
                                        ),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    for (final product in products)
                                      _PickerProductTile(
                                        product: product,
                                        selected: _selectedIds.contains(product.id),
                                        onTap: () => _toggleProduct(product),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      border: Border(top: BorderSide(color: scheme.outlineVariant)),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _selectedIds.isEmpty ? null : () => setState(_selectedIds.clear),
                            child: const Text('Clear selection'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _selectedIds.isEmpty
                                ? null
                                : () {
                                    final products = widget.products
                                        .where((p) => _selectedIds.contains(p.id))
                                        .toList(growable: false);
                                    Navigator.of(context).pop(products);
                                  },
                            icon: const Icon(Icons.playlist_add_rounded),
                            label: Text(
                              'Add ${_selectedIds.length} product${_selectedIds.length == 1 ? '' : 's'}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PickerProductTile extends StatelessWidget {
  final Product product;
  final bool selected;
  final VoidCallback onTap;

  const _PickerProductTile({
    required this.product,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 10, 2),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Buy ${product.purchasePrice.toStringAsFixed(2)} · Sell ${product.sellingPrice.toStringAsFixed(2)} EGP/carton',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (selected)
              Icon(Icons.done_rounded, color: scheme.primary, size: 19),
          ],
        ),
      ),
    );
  }
}
