//lib/core/constants/app_constants.dart
class AppConstants {
  // App Info
  static const String appName = 'Global Service Portal';
  static const String appVersion = '1.0.0';
  static const String packageName = 'com.globalservice.portal';

  // API Constants
  static const String baseUrl = 'https://api.globalserviceportal.com';
  static const String apiVersion = 'v1';
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Storage Keys
  static const String userTokenKey = 'user_token';
  static const String userTypeKey = 'user_type';
  static const String userDataKey = 'user_data';
  static const String isFirstTimeKey = 'is_first_time';
  static const String languageKey = 'language';
  static const String themeKey = 'theme_mode';

  // User Types
  static const String customerType = 'customer';
  static const String providerType = 'service_provider';
  static const String adminType = 'admin';

  // Service Categories
  static const List<String> serviceCategories = [
    'Home Cleaning',
    'Plumbing',
    'Electrical',
    'Carpentry',
    'Painting',
    'Gardening',
    'AC Repair',
    'Appliance Repair',
    'Pest Control',
    'Interior Design',
  ];

  // Validation Constants
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 20;
  static const int minNameLength = 2;
  static const int maxNameLength = 50;
  static const int maxDescriptionLength = 500;

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String providersCollection = 'service_providers';
  static const String customersCollection = 'customers';
  static const String servicesCollection = 'services';
  static const String bookingsCollection = 'bookings';
  static const String reviewsCollection = 'reviews';
  static const String categoriesCollection = 'categories';
  static const Duration splashDuration = Duration(seconds: 3);
}
