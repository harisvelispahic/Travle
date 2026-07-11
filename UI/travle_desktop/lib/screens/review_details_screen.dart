import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/product_review.dart';
import '../providers/product_provider.dart';
import '../utils/utils_widgets.dart';

class ReviewDetailsScreen extends StatefulWidget {
  final ProductReview review;

  const ReviewDetailsScreen({super.key, required this.review});

  @override
  State<ReviewDetailsScreen> createState() => _ReviewDetailsScreenState();
}

class _ReviewDetailsScreenState extends State<ReviewDetailsScreen> {
  late ProductProvider _productProvider;

  Product? product;

  bool isLoading = true;

  late final TextEditingController _controller;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _productProvider = context.read<ProductProvider>();

    _controller = TextEditingController(text: widget.review.comment);

    initProduct();
  }

  Future<void> initProduct() async {
    try {
      var data = await _productProvider.getById(widget.review.productId ?? 0);

      setState(() {
        product = data;
        isLoading = false;
      });
    } on Exception catch (e) {
      alertBox(context, 'Error', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Review Details"), centerTitle: true),
      body: SingleChildScrollView(
        child: 
          Column(
            children: [
              isLoading
                  ? CircularProgressIndicator()
                  : Text(
                      "Product Name: ${product?.name}",
                      style: TextStyle(fontSize: 24),
                    ),
              SizedBox(height: 20),
              Text(
                  "Reviewer: ${widget.review.reviewerDisplayName}",
                  style: TextStyle(fontSize: 24),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return Icon(
                      index < widget.review.rating
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber,
                      size: 24,
                    );
                     }),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: 600,
                  child: TextField(
                      controller: _controller,
                      readOnly: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      maxLength: 1000,
                    ),
                ),
                
            ],
        ),
      ),
    );
  }
}
