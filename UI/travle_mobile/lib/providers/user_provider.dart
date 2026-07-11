import 'dart:convert';

import 'package:travle_mobile/providers/base_provider.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';

class UserProvider extends BaseProvider<User> {
  UserProvider() : super("Users");

  @override
  User fromJson(data) {
    return User.fromJson(data);
  }

  Future<dynamic> changePassword(dynamic object) async {
    var url = "${BaseProvider.baseUrl}$endpoint/ChangePassword";

    var uri = Uri.parse(url);

    var jsonRequest = jsonEncode(object);
    var headers = createHeaders();

    http.Response response = await http.put(
      uri,
      headers: headers,
      body: jsonRequest,
    );

    validateResponse(response);
  }
}
