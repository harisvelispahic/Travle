import 'package:travle_mobile/models/order.dart';
import 'package:travle_mobile/providers/order_provider.dart';
import 'package:travle_mobile/screens/order_detail_screen.dart';
import 'package:travle_mobile/utils/utils_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  List<Order>? _orders;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<OrderProvider>().fetchMyOrders();
      setState(() {
        _orders = list;
        _loading = false;
      });
    } on Exception catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        alertBox(context, 'Error', e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your orders'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _orders == null || _orders!.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No orders yet')),
                ],
              )
            : ListView.builder(
                itemCount: _orders!.length,
                itemBuilder: (context, index) {
                  final o = _orders![index];
                  return ListTile(
                    title: Text(o.orderNumber),
                    subtitle: Text(
                      '${o.orderDate.toLocal().toString().split('.').first} · ${o.orderItems.length} item(s)',
                    ),
                    trailing: Text('\$${o.totalAmount.toStringAsFixed(2)}'),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              OrderDetailScreen(orderId: o.id),
                        ),
                      );
                      _load();
                    },
                  );
                },
              ),
      ),
    );
  }
}
