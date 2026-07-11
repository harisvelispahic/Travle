import 'package:travle_mobile/models/product.dart';
import 'package:travle_mobile/models/search_result.dart';
import 'package:travle_mobile/providers/cart_provider.dart';
import 'package:travle_mobile/providers/product_provider.dart';
import 'package:travle_mobile/screens/product_details_screen.dart';
import 'package:travle_mobile/utils/utils_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late ProductProvider _productProvider;
  late CartProvider _cartProvider;

  SearchResult<Product>? productResult;

  bool isLoading = true;
  bool hasMore = true;
  int page = 1;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _productProvider = context.read<ProductProvider>();
    _cartProvider = context.read<CartProvider>();

    initData();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoading &&
          hasMore) {
        addNextPageData();
      }
    });
  }

  Future<void> addNextPageData() async {
    try {
      page++;

      var data = await _productProvider.get(
        filter: {
          'page': page,
          'name': _searchController.text,
          'includeAssets': true,
        },
      );

      if (data.items!.isEmpty) {
        hasMore = false;
        return;
      }

      setState(() {
        productResult!.items!.addAll(data.items!);
        isLoading = false;
      });
    } on Exception catch (e) {
      alertBox(context, 'Error', e.toString());
    }
  }

  final ScrollController _scrollController = ScrollController();

  Future<void> initData() async {
    try {
      var data = await _productProvider.get(
        filter: {'name': _searchController.text, 'includeAssets': true},
      );

      //print(data.items?[0].assets[0].base64Content);
      setState(() {
        productResult = data;
        isLoading = false;
      });
    } on Exception catch (e) {
      alertBox(context, 'Error', e.toString());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildSearch(),
          isLoading ? CircularProgressIndicator() : _buildProductsGrid(context),
        ],
      ),
    );
  }

  Expanded _buildProductsGrid(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 0.0),
        child: GridView.builder(
          controller: _scrollController,
          itemCount: productResult?.items?.length ?? 0,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 5,
            childAspectRatio: 0.6,
          ),
          itemBuilder: (_, int index) {
            var product = productResult!.items![index];

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProductDetailsScreen(product: product),
                  ),
                );
              },
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: product.assets.firstOrNull != null
                        ? imageFromBase64String(
                            product.assets[0].base64Content!,
                          )
                        : placeholderImage(),
                  ),
                  SizedBox(height: 8.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name ?? "No name",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${product.price?.toStringAsFixed(2)} \$',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          _cartProvider.addToCart(product);
                        },
                        icon: Icon(Icons.add_shopping_cart),
                        style: IconButton.styleFrom(
                          iconSize: 18,
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.0,
                          ),
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Padding _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 14.0,
                  horizontal: 16.0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[300],
              ),
            ),
          ),
          IconButton(
            onPressed: () async {
              initData();
            },
            icon: Icon(Icons.search),
            style: IconButton.styleFrom(
              iconSize: 20,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                side: BorderSide(width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
