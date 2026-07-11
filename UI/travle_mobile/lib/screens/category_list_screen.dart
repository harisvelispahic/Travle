import 'package:travle_mobile/models/category.dart';
import 'package:travle_mobile/models/product.dart';
import 'package:travle_mobile/providers/category_provider.dart';
import 'package:travle_mobile/providers/product_provider.dart';
import 'package:travle_mobile/screens/product_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  late CategoryProvider _categoryProvider;
  late ProductProvider _productProvider;

  List<Category> _categories = [];
  // categoryId -> list of products loaded for that category
  final Map<int, List<Product>> _categoryProducts = {};
  // categoryId -> loading state
  final Map<int, bool> _loadingProducts = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _categoryProvider = context.read<CategoryProvider>();
    _productProvider = context.read<ProductProvider>();
    print("Loading categories...");
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final result = await _categoryProvider.get();
      setState(() {
        _categories = result.items ?? [];
        _isLoading = false;
      });
      print("Loaded ${_categories.length} categories");
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load categories: $e')),
        );
      }
    }
  }

  Future<void> _loadProductsForCategory(int categoryId) async {
    if (_categoryProducts.containsKey(categoryId)) return;
    setState(() => _loadingProducts[categoryId] = true);
    try {
      final result = await _productProvider.get(
        filter: {'categoryId': categoryId},
      );
      setState(() {
        _categoryProducts[categoryId] = result.items ?? [];
        _loadingProducts[categoryId] = false;
      });
    } catch (e) {
      setState(() => _loadingProducts[categoryId] = false);
    }
  }

  List<Category> _rootCategories() {
    return _categories
        .where((c) => c.parentCategoryId == null || c.parentCategoryId == 1)
        .toList();
  }

  List<Category> _childrenOf(int parentId) {
    return _categories.where((c) => c.parentCategoryId == parentId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _categories.isEmpty
                ? Center(child: Text('No categories found.'))
                : ListView(
                    children: _rootCategories()
                        .map(
                          (cat) =>
                              _buildCategoryTile(cat, depth: 0, visited: {}),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categories',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Browse products by category',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    Category category, {
    required int depth,
    required Set<int> visited,
  }) {
    final nextVisited = {...visited, category.id};
    final children = _childrenOf(
      category.id,
    ).where((c) => !visited.contains(c.id)).toList();

    return ExpansionTile(
      tilePadding: EdgeInsets.only(left: 16.0 + depth * 16.0, right: 16.0),
      leading: Icon(
        depth == 0 ? Icons.category : Icons.subdirectory_arrow_right,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        category.name ?? '',
        style: TextStyle(
          fontWeight: depth == 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: category.description != null && category.description!.isNotEmpty
          ? Text(
              category.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            )
          : null,
      onExpansionChanged: (expanded) {
        if (expanded) _loadProductsForCategory(category.id);
      },
      children: [
        ...children.map(
          (child) =>
              _buildCategoryTile(child, depth: depth + 1, visited: nextVisited),
        ),
        _buildProductsSection(category.id),
      ],
    );
  }

  Widget _buildProductsSection(int categoryId) {
    if (_loadingProducts[categoryId] == true) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final products = _categoryProducts[categoryId];
    if (products == null) return SizedBox.shrink();
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Text(
          'No products in this category.',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Column(
      children: products
          .map(
            (p) => ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 32.0),
              leading: Icon(Icons.shopping_bag_outlined),
              title: Text(p.name ?? ''),
              trailing: Text(
                '\$${p.price?.toStringAsFixed(2) ?? '-'}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailsScreen(product: p),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
