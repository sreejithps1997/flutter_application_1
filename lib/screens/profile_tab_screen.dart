import 'package:flutter/material.dart';

import 'tabs/home_tab.dart';
import 'tabs/personal_info_tab.dart';
import 'tabs/security_tab.dart';
import 'tabs/privacy_data_tab.dart';

class ProfileTabScreen extends StatelessWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("User Account"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.black,
            indicatorColor: Colors.deepPurple,
            tabs: [
              Tab(text: 'Home'),
              Tab(text: 'Personal info'),
              Tab(text: 'Security'),
              Tab(text: 'Privacy & Data'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            HomeTab(),
            PersonalInfoTab(),
            SecurityTab(),
            PrivacyAndDataTab(),
          ],
        ),
      ),
    );
  }
}
