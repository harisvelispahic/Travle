import 'package:travle_mobile/layouts/master_screen.dart';
import 'package:travle_mobile/utils/utils_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormBuilderState>();

  late UserProvider _userProvider = UserProvider();

  @override
  void initState() {
    super.initState();
    _userProvider = context.read<UserProvider>();
  }

  @override
  Widget build(BuildContext context) {
    return MasterScreen(
      title: "Change password",
      child: SingleChildScrollView(
        child: FormBuilder(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 65, 40, 50),
            child: Card(
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    FormBuilderTextField(
                      name: "password",
                      decoration: InputDecoration(labelText: "Password"),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return mField;
                        } else {
                          return null;
                        }
                      },
                    ),
                    FormBuilderTextField(
                      name: "newPassword",
                      decoration: InputDecoration(labelText: "New Password"),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return mField;
                        } else {
                          return null;
                        }
                      },
                    ),
                    FormBuilderTextField(
                      name: "confirmPassword",
                      decoration: InputDecoration(
                        labelText: "Confirm password",
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return mField;
                        } else if (value !=
                            _formKey.currentState?.value['newPassword']) {
                          return "New password doesn't match";
                        } else {
                          return null;
                        }
                      },
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () async {
                        _formKey.currentState?.save();

                        try {
                          if (_formKey.currentState!.validate()) {
                            await _userProvider.changePassword({
                              'id': AuthProvider.accessTokenDecoded?['Id'],
                              'password':
                                  _formKey.currentState?.value['password'],
                              'newPassword':
                                  _formKey.currentState?.value['newPassword'],
                              'confirmNewPassword': _formKey
                                  .currentState
                                  ?.value['confirmPassword'],
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Password successfully changed"),
                              ),
                            );
                            Navigator.pop(context);
                          }
                        } on Exception catch (e) {
                          alertBox(context, "Error", e.toString());
                        }
                      },
                      child: Text("Save"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
