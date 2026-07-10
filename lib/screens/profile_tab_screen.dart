import 'package:flutter/material.dart';

import '../services/user_type_service.dart';
import 'account/account_screen_factory.dart';

class ProfileTabScreen extends StatelessWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: UserTypeService.getCurrentUserType(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return AccountScreenFactory.createAccountScreen(
          snapshot.data ?? 'customer',
        );
      },
    );
  }
}
