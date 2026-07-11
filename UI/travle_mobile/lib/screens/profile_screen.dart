import 'package:travle_mobile/providers/auth_provider.dart';
import 'package:travle_mobile/screens/change_password_screen.dart';
import 'package:travle_mobile/screens/orders_list_screen.dart';
import 'package:travle_mobile/screens/profile_settings_screen.dart';
import 'package:travle_mobile/screens/user_review_screen.dart';
import 'package:travle_mobile/utils/utils_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart' hide alertBox;
import '../models/user.dart';
import '../providers/user_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserProvider _userProvider;

  late User user;

  bool isLoading = true;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _userProvider = context.read<UserProvider>();

    initData();
  }

  Future<void> initData() async {
    try {
      var result = await _userProvider.getById(
        int.tryParse(AuthProvider.accessTokenDecoded?['Id'] ?? '0') ?? 0,
      );

      setState(() {
        user = result;
        isLoading = false;
      });
    } on Exception catch (e) {
      alertBox(context, 'Error', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: isLoading
            ? CircularProgressIndicator()
            : Column(
                children: [
                  SizedBox(height: 40),
                  _buildProfileInfo(),
                  SizedBox(height: 40),
                  _buildProfileMenu(),
                ],
              ),
      ),
    );
  }

  Row _buildProfileInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            CircleAvatar(
              backgroundImage: user.profileImageBase64 != null
                  ? ImageFromBase64StringWithoutDimnesions(
                      user.profileImageBase64!,
                    )
                  : AssetImage("assets/images/no_profile.png"),
              radius: 70,
            ),
            const SizedBox(height: 20),
            // add user name
            Text(
              "${user.firstName} ${user.lastName}",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              user.username ?? "No username",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Padding _buildProfileMenu() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26.0, 0, 26.0, 0),
      child: Card(
        elevation: 10,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: Icon(Icons.shopping_bag),
              title: Text("Your orders"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrdersListScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.reviews),
              title: Text("Your reviews"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserReviewScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.pending),
              title: Text("Edit profile"),
              onTap: () async {
                var refresh = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileSettingsScreen(user: user),
                  ),
                );

                if (refresh == 'reload') {
                  initData();
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text("Change password"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChangePasswordScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text("Log out"),
              onTap: () async {
                final leave = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text("Log out"),
                    content: Text("Are you sure you want to log out?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text("Log out"),
                      ),
                    ],
                  ),
                );
                if (leave != true || !mounted) return;
                context.read<AuthProvider>().logout();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => LoginPage()),
                  (route) => route.isFirst,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
