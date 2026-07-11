import 'package:travle_mobile/models/order.dart';
import 'package:travle_mobile/providers/order_provider.dart';
import 'package:travle_mobile/screens/add_review_screen.dart';
import 'package:travle_mobile/utils/utils_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final o = await context.read<OrderProvider>().getById(widget.orderId);
      setState(() {
        _order = o;
        _loading = false;
      });
    } on Exception catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        alertBox(context, 'Error', e.toString());
      }
    }
  }

  String _statusLabel(int status) {
    const names = [
      'Pending',
      'Processing',
      'Shipped',
      'Delivered',
      'Cancelled',
      'Returned',
    ];
    if (status >= 0 && status < names.length) {
      return names[status];
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_order?.orderNumber ?? 'Order'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
          ? const Center(child: Text('Order not found'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Status: ${_statusLabel(_order!.status)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Placed: ${_order!.orderDate.toLocal().toString().split('.').first}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total: \$${_order!.totalAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  Text('Items', style: Theme.of(context).textTheme.titleMedium),
                  const Divider(),
                  ..._order!.orderItems.map(
                    (line) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(line.productName),
                      subtitle: Text(
                        'Qty ${line.quantity} × \$${line.unitPrice.toStringAsFixed(2)}',
                      ),
                      trailing: TextButton(
                        onPressed: _order!.status == 4
                            ? null
                            : () async {
                                final ok = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddReviewScreen(
                                      orderId: _order!.id,
                                      productId: line.productId,
                                      productName: line.productName,
                                    ),
                                  ),
                                );
                                if (ok == true && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Review saved'),
                                    ),
                                  );
                                }
                              },
                        child: const Text('Review'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
