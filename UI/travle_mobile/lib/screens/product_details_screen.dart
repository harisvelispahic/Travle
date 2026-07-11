import 'package:travle_mobile/models/product.dart';
import 'package:travle_mobile/providers/cart_provider.dart';
import 'package:travle_mobile/providers/product_provider.dart';
import 'package:travle_mobile/utils/utils_widgets.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late CartProvider _cartProvider;
  Product? _loaded;
  bool _loadingDetail = false;

  Product get _display => _loaded ?? widget.product;

  @override
  void initState() {
    super.initState();
    _cartProvider = context.read<CartProvider>();
    _refreshProduct();
  }

  Future<void> _refreshProduct() async {
    final id = widget.product.id;
    if (id == null) return;
    setState(() => _loadingDetail = true);
    try {
      final p = await context.read<ProductProvider>().getById(id);
      setState(() {
        _loaded = p;
        _loadingDetail = false;
      });
    } on Exception catch (_) {
      setState(() => _loadingDetail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product details'),
        centerTitle: true,
        actions: [
          if (widget.product.id != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadingDetail ? null : _refreshProduct,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            CarouselSlider(
              items: _display.assets.isNotEmpty
                  ? _display.assets
                        .map(
                          (e) => imageFromBase64String(e.base64Content ?? ""),
                        )
                        .toList()
                  : [placeholderImage()],
              options: CarouselOptions(
                height: 400,
                viewportFraction: 1,
                initialPage: 0,
                enableInfiniteScroll: false,
                scrollDirection: Axis.horizontal,
              ),
            ),
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
              ),
              child: Row(
                children: [
                  SizedBox(width: 16),
                  Text(
                    'Free shipping',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    softWrap: true,
                    maxLines: 3,
                    _display.name ?? 'No name',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 30),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '${_display.price?.toStringAsFixed(2)} \$',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if ((_display.description ?? '').isNotEmpty) ...[
                    SizedBox(height: 20),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _display.description!,
                      style: TextStyle(fontSize: 16, height: 1.4),
                    ),
                  ],
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _cartProvider.addToCart(_display);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${_display.name ?? 'Product'} added to cart',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: Icon(Icons.add_shopping_cart),
                      label: Text(
                        'Add to Cart',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  Row(
                    children: [
                      Text(
                        'Reviews',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (_loadingDetail) ...[
                        SizedBox(width: 12),
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 8),
                  if (_display.reviews.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        'No reviews yet.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  else
                    ..._display.reviews.map(
                      (r) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Row(
                            children: [
                              Text(r.reviewerDisplayName),
                              SizedBox(width: 8),
                              ...List.generate(
                                5,
                                (i) => Icon(
                                  i < r.rating ? Icons.star : Icons.star_border,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(r.comment),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
