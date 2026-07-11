import 'dart:convert';

import 'package:travle_mobile/models/order.dart';
import 'package:travle_mobile/providers/base_provider.dart';
import 'package:http/http.dart' as http;

class OrderProvider extends BaseProvider<Order> {
  OrderProvider() : super('Orders');

  @override
  Order fromJson(data) => Order.fromJson(data as Map<String, dynamic>);

  Future<Order> checkout(List<Map<String, dynamic>> items) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Orders/Checkout');
    final headers = createHeaders();
    final body = jsonEncode({'items': items});
    final response = await http.post(uri, headers: headers, body: body);
    validateResponse(response);
    return Order.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<Order>> fetchMyOrders() async {
    final result = await get(filter: {'page': 1, 'pageSize': 100});
    return result.items ?? [];
  }
}
