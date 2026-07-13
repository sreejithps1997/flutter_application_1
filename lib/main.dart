import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'screens/generic_help_request_screen.dart';
import 'features/admin_control/presentation/admin_control_center_screen.dart';
import 'features/admin_control/presentation/admin_dispute_center_screen.dart';
import 'features/admin_demand/presentation/admin_demand_review_screen.dart';
import 'features/admin_referrals/presentation/admin_referral_reward_screen.dart';
import 'features/community_campaigns/presentation/admin_campaign_calendar_screen.dart';
import 'features/help_requests/presentation/customer_help_request_detail_screen.dart';
import 'features/help_requests/presentation/customer_help_requests_screen.dart';
import 'features/help_requests/presentation/worker_help_requests_screen.dart';
import 'features/help_requests/presentation/worker_help_request_detail_screen.dart';
import 'features/smart_booking/presentation/smart_booking_assistant_screen.dart';
import 'features/worker_badges/presentation/worker_achievement_history_screen.dart';
import 'features/worker_badges/presentation/worker_badge_criteria_screen.dart';
import 'features/worker_badges/presentation/worker_experience_certificate_screen.dart';
import 'features/worker_opportunities/presentation/worker_opportunity_feed_screen.dart';

// Worker Auth & Flow
import 'screens/worker_auth_screen.dart';
import 'screens/worker_login_screen.dart';
import 'screens/worker_signup_screen.dart';
import 'screens/worker_dashboard_screen.dart';
import 'screens/worker_active_jobs_screen.dart';
import 'screens/worker_job_history_screen.dart';
import 'screens/worker_earnings_screen.dart';
import 'screens/worker_payout_methods_screen.dart';
import 'screens/worker_portfolio_screen.dart';
import 'screens/worker_job_details_screen.dart';
import 'screens/worker_professional_profile_screen.dart';
import 'screens/worker_profile_screen.dart';
import 'screens/worker_profile_update_screen.dart';
import 'screens/worker_edit_profile_screen.dart';
import 'screens/worker_change_password_screen.dart';
import 'screens/worker_reviews_screen.dart';
import 'screens/worker_signup/step1_profile_screen.dart';
import 'screens/worker_signup/step2_skills_screen.dart';
import 'screens/worker_signup/step3_pricing_screen.dart';
import 'screens/worker_signup/step4_schedule_screen.dart';
import 'screens/worker_signup/step5_verify_screen.dart';

// Shared Features
import 'screens/help_support_screen.dart';
import 'screens/terms_conditions_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/ratings_reviews_screen.dart';
import 'screens/location_permission_screen.dart';
import 'screens/add_skills_screen.dart';

// Dynamic Routing
import 'screens/worker_list_screen.dart';
import 'screens/booking_form_screen.dart';
import 'screens/booking_detail_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/recent_chats_screen.dart';
import '../screens/personal_information_screen.dart';
import '../screens/address_management_screen.dart';
import '../screens/identity_verification_screen.dart';
import '../screens/ongoing_services_screen.dart';
import '../screens/favorite_workers_screen.dart';
import 'screens/payment_methods_screen.dart';
import 'screens/wallet_credits_screen.dart';
import 'screens/transaction_history_screen.dart';
import 'screens/app_settings_screen.dart';
import 'screens/security_privacy_screen.dart';
import 'screens/referral_programme_screen.dart';
import 'screens/referral_invite_landing_screen.dart';
import 'screens/become_worker_screen.dart';
import 'screens/add_new_address_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/my_reviews_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/address_verification_screen.dart';
import 'screens/selfie_verification_screen.dart';
import 'screens/phone_verification_screen.dart';
import 'screens/background_check_screen.dart';
import 'screens/government_id_verification_screen.dart';
import 'screens/pan_card_verification_screen.dart';
import 'screens/map_picker_screen.dart';

import 'dart:async';
import 'dart:convert';

// NEW Modular Account Architecture
import 'screens/account/customer_account_screen.dart';
import 'screens/account/worker_account_screen.dart';
import 'screens/account/account_screen_factory.dart';
import 'services/user_type_service.dart';
import 'services/app_preferences_service.dart';
import 'services/notification_service.dart';
import 'services/notification_navigation_service.dart';
import 'services/referral_link_service.dart';
import 'screens/repeat_booking_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/admin/admin_payout_review_screen.dart';
import 'screens/admin/admin_payment_review_screen.dart';
import 'screens/admin/admin_verification_dashboard.dart';
import 'screens/admin/admin_work_start_override_screen.dart';
import 'screens/police_certificate_screen.dart';
import 'core/theme/workable_design.dart';

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
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
      await AppPreferencesService.init();

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
      if (AppPreferencesService.notifications) {
        await NotificationService.requestNotificationPermission();
        await NotificationService.saveFcmTokenToFirestore();
      }
      NotificationService.startTokenRefreshListener();
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          NotificationNavigationService.handlePayloadString(response.payload);
        },
      );

      // Reset any logged in user for testing
      await FirebaseAuth.instance.signOut();

      runApp(const ProviderScope(child: WorkableApp()));
    },
    (Object error, StackTrace stack) {
      debugPrint('💥 Uncaught zone error: $error');
      debugPrint(stack.toString());
    },
  );
}

class WorkableApp extends StatelessWidget {
  const WorkableApp({super.key});

  static bool _notificationTapHandlersReady = false;
  static bool _foregroundNotificationHandlerReady = false;

  Future<Widget> _getInitialScreen() async {
    await Future.delayed(const Duration(seconds: 2));
    return const UserTypeSelectionScreen();
  }

  void _configureNotificationTapHandlers() {
    if (_notificationTapHandlersReady) return;
    _notificationTapHandlersReady = true;

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      NotificationNavigationService.handleData(message.data);
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationNavigationService.handleData(message.data);
      });
    });
  }

  void _configureForegroundNotificationHandler() {
    if (_foregroundNotificationHandlerReady) return;
    _foregroundNotificationHandlerReady = true;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null &&
          android != null &&
          AppPreferencesService.notifications) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'workable_updates',
              'Workable Updates',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _configureNotificationTapHandlers();
    _configureForegroundNotificationHandler();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppPreferencesService.themeMode,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<int>(
          valueListenable: AppPreferencesService.accessibilityVersion,
          builder: (context, _, __) {
            final highContrast = AppPreferencesService.highContrast;
            return MaterialApp(
              navigatorKey: appNavigatorKey,
              title: 'Workable App',
              debugShowCheckedModeBanner: false,
              showPerformanceOverlay: kShowPerfOverlay,
              themeMode: themeMode,
              theme: WorkableDesign.lightTheme(highContrast: highContrast),
              darkTheme: WorkableDesign.darkTheme(highContrast: highContrast),
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(
                      AppPreferencesService.textScaleFactor,
                    ),
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },

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
                CustomerLoginScreen.routeName: (_) =>
                    const CustomerLoginScreen(),
                CustomerSignupScreen.routeName: (_) =>
                    const CustomerSignupScreen(),
                CustomerDashboardScreen.routeName: (_) =>
                    const CustomerDashboardScreen(),
                CustomerBookingsScreen.routeName: (context) =>
                    const CustomerBookingsScreen(),
                CustomerBookingConfirmationScreen.routeName: (_) =>
                    const CustomerBookingConfirmationScreen(),
                CustomerReviewsScreen.routeName: (_) =>
                    const CustomerReviewsScreen(),
                SearchScreen.routeName: (_) => const SearchScreen(),
                SmartBookingAssistantScreen.routeName: (_) =>
                    const SmartBookingAssistantScreen(),
                GenericHelpRequestScreen.routeName: (_) =>
                    const GenericHelpRequestScreen(),
                CustomerHelpRequestsScreen.routeName: (_) =>
                    const CustomerHelpRequestsScreen(),
                CustomerHelpRequestDetailScreen.routeName: (_) =>
                    const CustomerHelpRequestDetailScreen(),

                // Worker Routes
                WorkerAuthScreen.routeName: (_) => const WorkerAuthScreen(),
                WorkerLoginScreen.routeName: (_) => const WorkerLoginScreen(),
                WorkerSignupScreen.routeName: (_) => const WorkerSignupScreen(),
                WorkerDashboardScreen.routeName: (_) =>
                    const WorkerDashboardScreen(),
                WorkerProfileUpdateScreen.routeName: (_) =>
                    const WorkerProfileUpdateScreen(),
                WorkerEditProfileScreen.routeName: (_) =>
                    const WorkerEditProfileScreen(),
                WorkerChangePasswordScreen.routeName: (_) =>
                    const WorkerChangePasswordScreen(),
                '/worker-settings': (_) => const AppSettingsScreen(),
                WorkerReviewsScreen.routeName: (_) =>
                    const WorkerReviewsScreen(),
                WorkerAchievementHistoryScreen.routeName: (_) =>
                    const WorkerAchievementHistoryScreen(),
                WorkerBadgeCriteriaScreen.routeName: (_) =>
                    const WorkerBadgeCriteriaScreen(),
                WorkerExperienceCertificateScreen.routeName: (_) =>
                    const WorkerExperienceCertificateScreen(),

                // Shared Routes
                HelpSupportScreen.routeName: (_) => const HelpSupportScreen(),
                '/settings': (_) => const AppSettingsScreen(),
                TermsConditionsScreen.routeName: (_) =>
                    const TermsConditionsScreen(),
                PrivacyPolicyScreen.routeName: (_) =>
                    const PrivacyPolicyScreen(),
                EditProfileScreen.routeName: (_) => const EditProfileScreen(),
                ChangePasswordScreen.routeName: (_) =>
                    const ChangePasswordScreen(),
                SubscriptionScreen.routeName: (_) => const SubscriptionScreen(),
                '/withdraw': (_) => const WorkerPayoutMethodsScreen(),
                '/view-earnings': (_) => const WorkerEarningsScreen(),
                RatingsReviewsScreen.routeName: (_) =>
                    const RatingsReviewsScreen(),
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
                    return AccountScreenFactory.createAccountScreen(
                      snapshot.data!,
                    );
                  },
                ),
                CustomerAccountScreen.routeName: (context) =>
                    const CustomerAccountScreen(),
                WorkerAccountScreen.routeName: (context) =>
                    const WorkerAccountScreen(),

                PersonalInformationScreen.routeName: (context) =>
                    const PersonalInformationScreen(),
                AddressManagementScreen.routeName: (_) =>
                    const AddressManagementScreen(),
                IdentityVerificationScreen.routeName: (_) =>
                    const IdentityVerificationScreen(),
                '/booking-history': (_) =>
                    const CustomerBookingsScreen(initialTab: 2),
                OngoingServicesScreen.routeName: (context) =>
                    OngoingServicesScreen(),
                FavoriteWorkersScreen.routeName: (context) =>
                    const FavoriteWorkersScreen(),
                PaymentMethodsScreen.routeName: (_) =>
                    const PaymentMethodsScreen(),
                WalletCreditsScreen.routeName: (_) =>
                    const WalletCreditsScreen(),
                TransactionHistoryScreen.routeName: (_) =>
                    const TransactionHistoryScreen(),
                AppSettingsScreen.routeName: (context) =>
                    const AppSettingsScreen(),
                SecurityPrivacyScreen.routeName: (_) =>
                    const SecurityPrivacyScreen(),
                ReferralProgrammeScreen.routeName: (context) =>
                    const ReferralProgrammeScreen(),
                BecomeWorkerScreen.routeName: (context) =>
                    const BecomeWorkerScreen(),
                AddNewAddressScreen.routeName: (context) =>
                    const AddNewAddressScreen(),
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
                ForgotPasswordScreen.routeName: (_) =>
                    const ForgotPasswordScreen(),
                AdminControlCenterScreen.routeName: (context) =>
                    const AdminControlCenterScreen(),
                AdminDisputeCenterScreen.routeName: (context) =>
                    const AdminDisputeCenterScreen(),
                AdminPayoutReviewScreen.routeName: (context) =>
                    const AdminPayoutReviewScreen(),
                AdminPaymentReviewScreen.routeName: (context) =>
                    const AdminPaymentReviewScreen(),
                AdminVerificationDashboard.routeName: (context) =>
                    const AdminVerificationDashboard(),
                AdminWorkStartOverrideScreen.routeName: (context) =>
                    const AdminWorkStartOverrideScreen(),
                AdminDemandReviewScreen.routeName: (context) =>
                    const AdminDemandReviewScreen(),
                AdminReferralRewardScreen.routeName: (context) =>
                    const AdminReferralRewardScreen(),
                AdminCampaignCalendarScreen.routeName: (context) =>
                    const AdminCampaignCalendarScreen(),

                CustomerBookingReviewScreen.routeName: (ctx) {
                  final args =
                      ModalRoute.of(ctx)!.settings.arguments
                          as Map<String, dynamic>;
                  return CustomerBookingReviewScreen(
                    bookingId: args['bookingId']!,
                    workerId: args['workerId']!,
                  );
                },

                '/customer/booking-history': (context) =>
                    const CustomerBookingsScreen(initialTab: 2),
                '/customer/ongoing-services': (context) =>
                    OngoingServicesScreen(),
                '/customer/payment-methods': (context) =>
                    const PaymentMethodsScreen(),
                '/customer/wallet-credits': (context) =>
                    const WalletCreditsScreen(),
                '/customer/transaction-history': (context) =>
                    const TransactionHistoryScreen(),
                '/customer/messages': (context) => const MessagesScreen(),
                '/customer/notifications': (context) =>
                    const NotificationsScreen(),
                '/customer/my-reviews': (context) => const MyReviewsScreen(),
                '/customer/help-support': (context) =>
                    const HelpSupportScreen(),
                '/customer/personal-information': (context) =>
                    const PersonalInformationScreen(),
                '/customer/address-management': (context) =>
                    const AddressManagementScreen(),
                '/customer/identity-verification': (context) =>
                    const IdentityVerificationScreen(),
                '/customer/app-settings': (context) =>
                    const AppSettingsScreen(),
                '/customer/referral-program': (context) =>
                    const ReferralProgrammeScreen(),
                '/customer/repeat-booking': (context) =>
                    const RepeatBookingScreen(),
                '/book-service': (context) => const BookingFormScreen(),
                '/terms-privacy': (context) => const TermsConditionsScreen(),
                '/repeat-booking': (ctx) => RepeatBookingScreen(),

                WorkerActiveJobsScreen.routeName: (_) =>
                    const WorkerActiveJobsScreen(),
                WorkerJobHistoryScreen.routeName: (_) =>
                    const WorkerJobHistoryScreen(),
                WorkerOpportunityFeedScreen.routeName: (_) =>
                    const WorkerOpportunityFeedScreen(),
                WorkerHelpRequestsScreen.routeName: (_) =>
                    const WorkerHelpRequestsScreen(),
                WorkerHelpRequestDetailScreen.routeName: (_) =>
                    const WorkerHelpRequestDetailScreen(),
                '/worker/schedule': (_) =>
                    const WorkerProfessionalProfileScreen(),
                '/worker/service-areas': (_) =>
                    const WorkerProfessionalProfileScreen(),
                WorkerEarningsScreen.routeName: (_) =>
                    const WorkerEarningsScreen(),
                WorkerPayoutMethodsScreen.routeName: (_) =>
                    const WorkerPayoutMethodsScreen(),
                '/worker/transaction-history': (_) =>
                    const TransactionHistoryScreen(
                      ownerField: 'workerId',
                      title: 'Worker Transactions',
                      isWorkerView: true,
                    ),
                '/worker/customer-reviews': (_) => const WorkerReviewsScreen(),
                '/worker/messages': (_) => const MessagesScreen(),
                WorkerPortfolioScreen.routeName: (_) =>
                    const WorkerPortfolioScreen(),
                WorkerProfessionalProfileScreen.routeName: (_) =>
                    const WorkerProfessionalProfileScreen(),
                '/worker/verification-status': (_) =>
                    const IdentityVerificationScreen(),

                '/worker/notification-settings': (_) =>
                    const AppSettingsScreen(),
                '/worker/app-settings': (_) => const AppSettingsScreen(),
                '/police-certificate': (context) =>
                    const PoliceCertificateScreen(),
              },

              onGenerateRoute: (settings) {
                final routeUri = Uri.tryParse(settings.name ?? '');
                if (routeUri != null && routeUri.path == '/invite') {
                  final code = ReferralLinkService.normalizeCode(
                    routeUri.queryParameters['ref'],
                  );
                  return MaterialPageRoute(
                    builder: (_) =>
                        ReferralInviteLandingScreen(referralCode: code),
                  );
                }

                switch (settings.name) {
                  case ChatScreen.routeName:
                    final args = settings.arguments as Map<String, dynamic>;
                    return MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatWithId: args['chatWithId'] ?? '',
                        chatWithName: args['chatWithName'] ?? '',
                        userRole: args['userRole'] ?? '',
                        bookingId: args['bookingId'],
                        workerService: args['workerService'],
                        workerRating: (args['workerRating'] as num?)
                            ?.toDouble(),
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
                      builder: (_) =>
                          CustomerBookingDetailScreen(booking: args),
                    );

                  case CustomerRescheduleScreen.routeName:
                    final bookingId = settings.arguments as String;
                    return MaterialPageRoute(
                      builder: (_) =>
                          CustomerRescheduleScreen(bookingId: bookingId),
                    );

                  case CustomerPaymentScreen.routeName:
                    final bookingId = settings.arguments as String;
                    return MaterialPageRoute(
                      builder: (_) =>
                          CustomerPaymentScreen(bookingId: bookingId),
                    );

                  case WorkerListScreen.routeName:
                    final results =
                        settings.arguments as List<Map<String, dynamic>>;
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
                    final onboardingData =
                        settings.arguments as WorkerOnboardingData;
                    return MaterialPageRoute(
                      builder: (_) =>
                          Step1ProfileScreen(onboardingData: onboardingData),
                    );

                  case Step2SkillsScreen.routeName:
                    final onboardingData =
                        settings.arguments as WorkerOnboardingData;
                    return MaterialPageRoute(
                      builder: (_) =>
                          Step2SkillsScreen(onboardingData: onboardingData),
                    );

                  case Step3PricingScreen.routeName:
                    final onboardingData =
                        settings.arguments as WorkerOnboardingData;
                    return MaterialPageRoute(
                      builder: (_) =>
                          Step3PricingScreen(onboardingData: onboardingData),
                    );

                  case Step4ScheduleScreen.routeName:
                    final onboardingData =
                        settings.arguments as WorkerOnboardingData;
                    return MaterialPageRoute(
                      builder: (_) =>
                          Step4ScheduleScreen(onboardingData: onboardingData),
                    );

                  case Step5VerifyScreen.routeName:
                    final onboardingData =
                        settings.arguments as WorkerOnboardingData;
                    return MaterialPageRoute(
                      builder: (_) =>
                          Step5VerifyScreen(onboardingData: onboardingData),
                    );

                  case WorkerJobDetailsScreen.routeName:
                    final bookingId = settings.arguments as String;
                    return MaterialPageRoute(
                      builder: (_) =>
                          WorkerJobDetailsScreen(bookingId: bookingId),
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
          },
        );
      },
    );
  }
}
