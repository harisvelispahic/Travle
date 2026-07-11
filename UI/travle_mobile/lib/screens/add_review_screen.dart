import 'package:travle_mobile/providers/product_review_provider.dart';
import 'package:travle_mobile/utils/utils_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddReviewScreen extends StatefulWidget {
  final int orderId;
  final int productId;
  final String productName;

  const AddReviewScreen({
    super.key,
    required this.orderId,
    required this.productId,
    required this.productName,
  });

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  int _rating = 5;
  final _comment = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await context.read<ProductReviewProvider>().insert({
        'orderId': widget.orderId,
        'productId': widget.productId,
        'rating': _rating,
        'comment': _comment.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on Exception catch (e) {
      if (mounted) {
        alertBox(context, 'Error', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Write a review'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.productName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Text('Rating', style: Theme.of(context).textTheme.titleSmall),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = star),
                  icon: Icon(
                    star <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 36,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _comment,
              decoration: const InputDecoration(
                labelText: 'Comment',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              maxLength: 1000,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
