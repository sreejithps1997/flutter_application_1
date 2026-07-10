import 'package:flutter/material.dart';

import '../services/user_type_service.dart';
import 'personal_information_screen.dart';
import 'worker_professional_profile_screen.dart';

class EditProfileScreen extends StatelessWidget {
  static const routeName = '/edit-profile';

  const EditProfileScreen({super.key});

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

        final role = snapshot.data?.toLowerCase();
        if (role == 'worker') {
          return const WorkerProfessionalProfileScreen();
        }
        return const PersonalInformationScreen();
      },
    );
  }
}
