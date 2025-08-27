//lib/core/constants/api_endpoints.dart
// This file defines all the API endpoints used in the application.
class ApiEndpoints {
  // Base configuration
  static const String apiVersion = 'v1';

  // Authentication endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String verifyEmail = '/auth/verify-email';
  static const String resendVerification = '/auth/resend-verification';

  // User endpoints
  static const String profile = '/user/profile';
  static const String updateProfile = '/user/profile';
  static const String changePassword = '/user/change-password';
  static const String deleteAccount = '/user/delete';
  static const String userPreferences = '/user/preferences';

  // Service Provider endpoints
  static const String providerProfile = '/provider/profile';
  static const String providerServices = '/provider/services';
  static const String providerBookings = '/provider/bookings';
  static const String providerReviews = '/provider/reviews';
  static const String providerEarnings = '/provider/earnings';
  static const String providerAvailability = '/provider/availability';

  // Customer endpoints
  static const String customerProfile = '/customer/profile';
  static const String customerBookings = '/customer/bookings';
  static const String customerReviews = '/customer/reviews';
  static const String customerFavorites = '/customer/favorites';

  // Services endpoints
  static const String services = '/services';
  static const String serviceById = '/services/{id}';
  static const String servicesByCategory = '/services/category/{categoryId}';
  static const String searchServices = '/services/search';
  static const String nearbyServices = '/services/nearby';
  static const String featuredServices = '/services/featured';
  static const String serviceReviews = '/services/{id}/reviews';

  // Categories endpoints
  static const String categories = '/categories';
  static const String categoryById = '/categories/{id}';
  static const String subcategories = '/categories/{id}/subcategories';

  // Bookings endpoints
  static const String bookings = '/bookings';
  static const String bookingById = '/bookings/{id}';
  static const String createBooking = '/bookings';
  static const String updateBooking = '/bookings/{id}';
  static const String cancelBooking = '/bookings/{id}/cancel';
  static const String confirmBooking = '/bookings/{id}/confirm';
  static const String completeBooking = '/bookings/{id}/complete';

  // Reviews endpoints
  static const String reviews = '/reviews';
  static const String reviewById = '/reviews/{id}';
  static const String createReview = '/reviews';
  static const String updateReview = '/reviews/{id}';
  static const String deleteReview = '/reviews/{id}';

  // Search endpoints
  static const String search = '/search';
  static const String searchSuggestions = '/search/suggestions';
  static const String searchHistory = '/search/history';

  // Location endpoints
  static const String locations = '/locations';
  static const String cities = '/locations/cities';
  static const String areas = '/locations/areas';
  static const String nearbyProviders = '/locations/nearby-providers';

  // Notifications endpoints
  static const String notifications = '/notifications';
  static const String markNotificationRead = '/notifications/{id}/read';
  static const String markAllNotificationsRead = '/notifications/read-all';
  static const String notificationSettings = '/notifications/settings';

  // Payment endpoints
  static const String payments = '/payments';
  static const String paymentMethods = '/payments/methods';
  static const String addPaymentMethod = '/payments/methods';
  static const String removePaymentMethod = '/payments/methods/{id}';
  static const String processPayment = '/payments/process';
  static const String paymentHistory = '/payments/history';

  // Upload endpoints
  static const String uploadImage = '/upload/image';
  static const String uploadDocument = '/upload/document';
  static const String uploadAvatar = '/upload/avatar';

  // Admin endpoints
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsers = '/admin/users';
  static const String adminProviders = '/admin/providers';
  static const String adminBookings = '/admin/bookings';
  static const String adminReports = '/admin/reports';

  // Utility methods
  static String getServiceById(String id) {
    return serviceById.replaceAll('{id}', id);
  }

  static String getBookingById(String id) {
    return bookingById.replaceAll('{id}', id);
  }

  static String getReviewById(String id) {
    return reviewById.replaceAll('{id}', id);
  }

  static String getCategoryById(String id) {
    return categoryById.replaceAll('{id}', id);
  }

  static String getServicesByCategory(String categoryId) {
    return servicesByCategory.replaceAll('{categoryId}', categoryId);
  }

  static String getSubcategories(String categoryId) {
    return subcategories.replaceAll('{id}', categoryId);
  }

  static String getServiceReviews(String serviceId) {
    return serviceReviews.replaceAll('{id}', serviceId);
  }

  static String updateBookingEndpoint(String id) {
    return updateBooking.replaceAll('{id}', id);
  }

  static String cancelBookingEndpoint(String id) {
    return cancelBooking.replaceAll('{id}', id);
  }

  static String confirmBookingEndpoint(String id) {
    return confirmBooking.replaceAll('{id}', id);
  }

  static String completeBookingEndpoint(String id) {
    return completeBooking.replaceAll('{id}', id);
  }

  static String updateReviewEndpoint(String id) {
    return updateReview.replaceAll('{id}', id);
  }

  static String deleteReviewEndpoint(String id) {
    return deleteReview.replaceAll('{id}', id);
  }

  static String markNotificationReadEndpoint(String id) {
    return markNotificationRead.replaceAll('{id}', id);
  }

  static String removePaymentMethodEndpoint(String id) {
    return removePaymentMethod.replaceAll('{id}', id);
  }
}
