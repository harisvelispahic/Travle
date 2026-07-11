import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  static String? _accesstoken;
  String? _refreshtoken;

  static String? get accesstoken => _accesstoken;
  String? get refreshtoken => _refreshtoken;

  String _baseUrl = "";

  AuthProvider() {
    _baseUrl = const String.fromEnvironment("BASE_URL", defaultValue: "http://localhost:5126/Access");
  }



  bool get isAuthenticated => _isAuthenticated;

  Future login(String username, String password) async {
    var url = "$_baseUrl/login";
    print("Login url: $url");
    var uri = Uri.parse(url);
    var headers = createHeaders();
    //todo: refactor this into a proper class. Not a good practice but for sample purposes it's ok
    var body = jsonEncode({
      "username": username,
      "password": password
    });

    http.Response response = await http.post(uri, headers: headers, body: body);

    if (isValidResponse(response)) {
      var data = jsonDecode(response.body);
      _accesstoken = data['accesstoken'];
      _refreshtoken = data['refreshtoken'];
      _isAuthenticated = true;
      notifyListeners();
    } else {
      throw Exception("Unknown error");
    }
  
  }


    bool isValidResponse(http.Response response) {
    if (response.statusCode < 299) {
      return true;
    } else if (response.statusCode == 401) {
      throw new Exception("Unauthorized");
    } else {
      print(response.body);
      throw new Exception("Something bad happened please try again");
    }
  }

  void logout() {
    _isAuthenticated = false;
    _accesstoken = null;
    _refreshtoken = null;
    notifyListeners();
  }


  Map<String, String> createHeaders() {

    var headers = {
      "Content-Type": "application/json",
    };

    return headers;
  }
  
}