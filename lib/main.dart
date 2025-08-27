import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart'; // 👈 image cache controls
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/worker_onboarding_data.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Core Screens
import 'screens/splash_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/user_type_selection_screen.dart';
import 'screens/customer_auth_screen.dart';
import 'screens/customer_login_screen.dart';
import 'screens/customer_signup_screen.dart';
import 'screens/customer_dashboard_screen.dart';
import 'screens/customer_bookings_screen.dart';
import 'screens/customer_booking_confirmation_screen.dart';
import 'screens/customer_booking_review_screen.dart';
import 'screens/customer_booking_detail_screen.dart';
import 'screens/customer_reschedule_screen.dart';
import 'screens/customer_payment_screen.dart';
import 'screens/customer_reviews_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/report_issue_screen.dart';
import 'screens/search_screen.dart';

// Worker Auth & Flow
import 'screens/worker_auth_screen.dart';
import 'screens/worker_login_screen.dart';
import 'screens/worker_signup_screen.dart';
import 'screens/worker_dashboard_screen.dart';
import 'screens/worker_job_details_screen.dart';
import 'screens/worker_profile_screen.dart';
import 'screens/worker_profile_update_screen.dart';
import 'screens/worker_edit_profile_screen.dart';
import 'screens/worker_change_password_screen.dart';
import 'screens/worker_settings_screen.dart';
import 'screens/worker_reviews_screen.dart';
import 'screens/worker_signup/step1_profile_screen.dart';
import 'screens/worker_signup/step2_skills_screen.dart';
import 'screens/worker_signup/step3_pricing_screen.dart';
import 'screens/worker_signup/step4_schedule_screen.dart';
import 'screens/worker_signup/step5_verify_screen.dart';

// Shared Features
import 'screens/help_support_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/terms_conditions_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/withdrawal_screen.dart';
import 'screens/view_earnings_screen.dart';
import 'screens/ratings_reviews_screen.dart';
import 'screens/location_permission_screen.dart';
import 'screens/add_skills_screen.dart';

// Dynamic Routing
import 'screens/worker_list_screen.dart';
import 'screens/booking_form_screen.dart';
import 'screens/booking_detail_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/recent_chats_screen.dart';

import 'screens/my_account_screen.dart';
import '../screens/personal_information_screen.dart';
import '../screens/address_management_screen.dart';
import '../screens/identity_verification_screen.dart';
import '../screens/booking_history_screen.dart';
import '../screens/ongoing_services_screen.dart';
import '../screens/favorite_workers_screen.dart';
import 'screens/payment_methods_screen.dart';
import 'screens/wallet_credits_screen.dart';
import 'screens/transaction_history_screen.dart';
import 'screens/help_support_screen.dart'; // (dup ok)
import 'screens/app_settings_screen.dart';
import 'screens/security_privacy_screen.dart';
import 'screens/referral_programme_screen.dart';
import 'screens/become_worker_screen.dart';
import 'screens/add_new_address_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/my_reviews_screen.dart';
import 'screens/address_verification_screen.dart';
import 'screens/selfie_verification_screen.dart';
import 'screens/phone_verification_screen.dart';
import 'screens/background_check_screen.dart';
import 'screens/government_id_verification_screen.dart';
import 'screens/pan_card_verification_screen.dart';
import 'screens/map_picker_screen.dart';

import 'dart:async';
import 'package:flutter/foundation.dart';

// NEW Modular Account Architecture
import 'screens/account/customer_account_screen.dart';
import 'screens/account/worker_account_screen.dart';
import 'screens/account/account_screen_factory.dart';
import 'services/user_type_service.dart';
import 'services/user_type_service.dart'; // (dup ok)
import 'screens/repeat_booking_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const bool kShowPerfOverlay = false;

/// ✅ Minimal background handler (no App Check)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📩 BG message: ${message.messageId}');
}

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 🧹 Limit image cache memory usage
      PaintingBinding.instance.imageCache.maximumSize = 50;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 20 << 20;

      await Firebase.initializeApp();

      // System UI styling
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );

      // 🔔 Notifications
      await FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      // Reset any logged in user for testing
      await FirebaseAuth.instance.signOut();

      runApp(const WorkableApp());
    },
    (Object error, StackTrace stack) {
      debugPrint('💥 Uncaught zone error: $error');
      debugPrint(stack.toString());
    },
  );
}

class WorkableApp extends StatelessWidget {
  const WorkableApp({super.key});

  Future<Widget> _getInitialScreen() async {
    await Future.delayed(const Duration(seconds: 2));
    return const UserTypeSelectionScreen();
  }

  @override
  Widget build(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'workable_channel',
              'Workable Notifications',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    return MaterialApp(
      title: 'Workable App',
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: kShowPerfOverlay,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            textStyle: TextStyle(fontSize: 16),
          ),
        ),
      ),

      home: FutureBuilder<Widget>(
        future: _getInitialScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          return snapshot.data ?? const UserTypeSelectionScreen();
        },
      ),

      routes: {
        SplashScreen.routeName: (_) => const SplashScreen(),
        LanguageSelectionScreen.routeName: (_) =>
            const LanguageSelectionScreen(),
        UserTypeSelectionScreen.routeName: (_) =>
            const UserTypeSelectionScreen(),

        // Customer Routes
        CustomerAuthScreen.routeName: (_) => const CustomerAuthScreen(),
        CustomerLoginScreen.routeName: (_) => const CustomerLoginScreen(),
        CustomerSignupScreen.routeName: (_) => const CustomerSignupScreen(),
        CustomerDashboardScreen.routeName: (_) =>
            const CustomerDashboardScreen(),
        CustomerBookingsScreen.routeName: (context) =>
            const CustomerBookingsScreen(),
        CustomerBookingsScreen.bookingHistoryRoute: (context) =>
            const CustomerBookingsScreen(),
        CustomerBookingConfirmationScreen.routeName: (_) =>
            const CustomerBookingConfirmationScreen(),
        CustomerReviewsScreen.routeName: (_) => const CustomerReviewsScreen(),
        SearchScreen.routeName: (_) => const SearchScreen(),

        // Worker Routes
        WorkerAuthScreen.routeName: (_) => const WorkerAuthScreen(),
        WorkerLoginScreen.routeName: (_) => const WorkerLoginScreen(),
        WorkerSignupScreen.routeName: (_) => const WorkerSignupScreen(),
        WorkerDashboardScreen.routeName: (_) => const WorkerDashboardScreen(),
        WorkerProfileUpdateScreen.routeName: (_) =>
            const WorkerProfileUpdateScreen(),
        WorkerEditProfileScreen.routeName: (_) =>
            const WorkerEditProfileScreen(),
        WorkerChangePasswordScreen.routeName: (_) =>
            const WorkerChangePasswordScreen(),
        WorkerSettingsScreen.routeName: (_) => const WorkerSettingsScreen(),
        WorkerReviewsScreen.routeName: (_) => const WorkerReviewsScreen(),

        // Shared Routes
        HelpSupportScreen.routeName: (_) => const HelpSupportScreen(),
        SettingsScreen.routeName: (_) => const SettingsScreen(),
        TermsConditionsScreen.routeName: (_) => const TermsConditionsScreen(),
        PrivacyPolicyScreen.routeName: (_) => const PrivacyPolicyScreen(),
        EditProfileScreen.routeName: (_) => const EditProfileScreen(),
        ChangePasswordScreen.routeName: (_) => const ChangePasswordScreen(),
        SubscriptionScreen.routeName: (_) => const SubscriptionScreen(),
        WithdrawalScreen.routeName: (_) => const WithdrawalScreen(),
        ViewEarningsScreen.routeName: (_) => const ViewEarningsScreen(),
        RatingsReviewsScreen.routeName: (_) => const RatingsReviewsScreen(),
        LocationPermissionScreen.routeName: (_) =>
            const LocationPermissionScreen(),
        ReportIssueScreen.routeName: (_) => const ReportIssueScreen(),
        AddSkillsScreen.routeName: (_) => const AddSkillsScreen(),
        BookingFormScreen.routeName: (_) => const BookingFormScreen(),

        '/account': (context) => FutureBuilder<String>(
          future: UserTypeService.getCurrentUserType(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Scaffold(
                body: Center(child: Text("Error loading account")),
              );
            }
            return AccountScreenFactory.createAccountScreen(snapshot.data!);
          },
        ),
        CustomerAccountScreen.routeName: (context) =>
            const CustomerAccountScreen(),
        WorkerAccountScreen.routeName: (context) => const WorkerAccountScreen(),

        PersonalInformationScreen.routeName: (context) =>
            const PersonalInformationScreen(),
        AddressManagementScreen.routeName: (_) =>
            const AddressManagementScreen(),
        IdentityVerificationScreen.routeName: (_) =>
            const IdentityVerificationScreen(),
        BookingHistoryScreen.routeName: (_) => const BookingHistoryScreen(),
        OngoingServicesScreen.routeName: (context) => OngoingServicesScreen(),
        FavoriteWorkersScreen.routeName: (context) =>
            const FavoriteWorkersScreen(),
        PaymentMethodsScreen.routeName: (_) => const PaymentMethodsScreen(),
        WalletCreditsScreen.routeName: (_) => const WalletCreditsScreen(),
        TransactionHistoryScreen.routeName: (_) =>
            const TransactionHistoryScreen(),
        HelpSupportScreen.routeName: (context) => const HelpSupportScreen(),
        AppSettingsScreen.routeName: (context) => const AppSettingsScreen(),
        LanguageSelectionScreen.routeName: (_) =>
            const LanguageSelectionScreen(),
        SecurityPrivacyScreen.routeName: (_) => const SecurityPrivacyScreen(),
        ReferralProgrammeScreen.routeName: (context) =>
            const ReferralProgrammeScreen(),
        BecomeWorkerScreen.routeName: (context) => const BecomeWorkerScreen(),
        AddNewAddressScreen.routeName: (context) => const AddNewAddressScreen(),
        MessagesScreen.routeName: (context) => const MessagesScreen(),
        MyReviewsScreen.routeName: (context) => const MyReviewsScreen(),
        PhoneVerificationScreen.routeName: (context) =>
            const PhoneVerificationScreen(),
        AddressVerificationScreen.routeName: (context) =>
            const AddressVerificationScreen(),
        SelfieVerificationScreen.routeName: (context) =>
            const SelfieVerificationScreen(),
        BackgroundCheckScreen.routeName: (context) =>
            const BackgroundCheckScreen(),
        GovernmentIdVerificationScreen.routeName: (context) =>
            const GovernmentIdVerificationScreen(),
        PANCardVerificationScreen.routeName: (context) =>
            const PANCardVerificationScreen(),
        MapPickerScreen.routeName: (ctx) => const MapPickerScreen(),

        CustomerBookingReviewScreen.routeName: (ctx) {
          final args =
              ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>;
          return CustomerBookingReviewScreen(
            bookingId: args['bookingId']!,
            workerId: args['workerId']!,
          );
        },

        '/customer/booking-history': (context) => const BookingHistoryScreen(),
        '/customer/ongoing-services': (context) => OngoingServicesScreen(),
        '/customer/favorite-workers': (context) =>
            const FavoriteWorkersScreen(),
        '/customer/payment-methods': (context) => const PaymentMethodsScreen(),
        '/customer/wallet-credits': (context) => const WalletCreditsScreen(),
        '/customer/transaction-history': (context) =>
            const TransactionHistoryScreen(),
        '/customer/messages': (context) => const MessagesScreen(),
        '/customer/my-reviews': (context) => const MyReviewsScreen(),
        '/customer/help-support': (context) => const HelpSupportScreen(),
        '/customer/personal-information': (context) =>
            const PersonalInformationScreen(),
        '/customer/address-management': (context) =>
            const AddressManagementScreen(),
        '/customer/identity-verification': (context) =>
            const IdentityVerificationScreen(),
        '/customer/app-settings': (context) => const AppSettingsScreen(),
        '/customer/referral-program': (context) =>
            const ReferralProgrammeScreen(),
        '/customer/repeat-booking': (context) => const BookingFormScreen(),
        '/book-service': (context) => const BookingFormScreen(),
        '/terms-privacy': (context) => const TermsConditionsScreen(),
        '/become-worker': (context) => const BecomeWorkerScreen(),

        '/repeat-booking': (ctx) => RepeatBookingScreen(),

        '/worker/active-jobs': (_) =>
            Scaffold(body: Center(child: Text("Active Jobs"))),
        '/worker/job-history': (_) =>
            Scaffold(body: Center(child: Text("Job History"))),
        '/worker/schedule': (_) =>
            Scaffold(body: Center(child: Text("Schedule"))),
        '/worker/service-areas': (_) =>
            Scaffold(body: Center(child: Text("Service Areas"))),
        '/worker/earnings-overview': (_) =>
            Scaffold(body: Center(child: Text("Earnings Overview"))),
        '/worker/payout-methods': (_) =>
            Scaffold(body: Center(child: Text("Payout Methods"))),
        '/worker/transaction-history': (_) => const TransactionHistoryScreen(),
        '/worker/earnings-analytics': (_) =>
            Scaffold(body: Center(child: Text("Earnings Analytics"))),
        '/worker/customer-reviews': (_) => const CustomerReviewsScreen(),
        '/worker/messages': (_) => const MessagesScreen(),
        '/worker/portfolio': (_) =>
            Scaffold(body: Center(child: Text("Portfolio"))),
        '/worker/training-center': (_) =>
            Scaffold(body: Center(child: Text("Training Center"))),
        '/worker/professional-profile': (_) =>
            Scaffold(body: Center(child: Text("Professional Profile"))),
        '/worker/verification-status': (_) =>
            const IdentityVerificationScreen(),

        '/worker/notification-settings': (_) =>
            Scaffold(body: Center(child: Text("Notification Settings"))),
        '/worker/app-settings': (_) => const AppSettingsScreen(),
      },

      onGenerateRoute: (settings) {
        switch (settings.name) {
          case ChatScreen.routeName:
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatWithId: args['chatWithId'] ?? '',
                chatWithName: args['chatWithName'] ?? '',
                userRole: args['userRole'] ?? '',
              ),
            );

          case BookingDetailScreen.routeName:
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => BookingDetailScreen(booking: args),
            );

          case CustomerBookingDetailScreen.routeName:
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => CustomerBookingDetailScreen(booking: args),
            );

          case CustomerRescheduleScreen.routeName:
            final bookingId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => CustomerRescheduleScreen(bookingId: bookingId),
            );

          case CustomerPaymentScreen.routeName:
            final bookingId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => CustomerPaymentScreen(bookingId: bookingId),
            );

          case WorkerListScreen.routeName:
            final results = settings.arguments as List<Map<String, dynamic>>;
            return MaterialPageRoute(
              builder: (_) => WorkerListScreen(results: results),
            );

          case WorkerProfileScreen.routeName:
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => WorkerProfileScreen(
                workerId: args['workerId'] ?? '',
                name: args['name'] ?? '',
              ),
            );

          case CustomerBookingReviewScreen.routeName:
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => CustomerBookingReviewScreen(
                bookingId: args['bookingId']!,
                workerId: args['workerId']!,
              ),
            );

          case Step1ProfileScreen.routeName:
            final onboardingData = settings.arguments as WorkerOnboardingData;
            return MaterialPageRoute(
              builder: (_) =>
                  Step1ProfileScreen(onboardingData: onboardingData),
            );

          case Step2SkillsScreen.routeName:
            final onboardingData = settings.arguments as WorkerOnboardingData;
            return MaterialPageRoute(
              builder: (_) => Step2SkillsScreen(onboardingData: onboardingData),
            );

          case Step3PricingScreen.routeName:
            final onboardingData = settings.arguments as WorkerOnboardingData;
            return MaterialPageRoute(
              builder: (_) =>
                  Step3PricingScreen(onboardingData: onboardingData),
            );

          case Step4ScheduleScreen.routeName:
            final onboardingData = settings.arguments as WorkerOnboardingData;
            return MaterialPageRoute(
              builder: (_) =>
                  Step4ScheduleScreen(onboardingData: onboardingData),
            );

          case Step5VerifyScreen.routeName:
            final onboardingData = settings.arguments as WorkerOnboardingData;
            return MaterialPageRoute(
              builder: (_) => Step5VerifyScreen(onboardingData: onboardingData),
            );

          case WorkerJobDetailsScreen.routeName:
            final bookingId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => WorkerJobDetailsScreen(bookingId: bookingId),
            );

          case RecentChatsScreen.routeName:
            final args = settings.arguments as Map<String, String>;
            return MaterialPageRoute(
              builder: (_) =>
                  RecentChatsScreen(userRole: args['userRole'] ?? ''),
            );

          default:
            return null;
        }
      },
    );
  }
}
