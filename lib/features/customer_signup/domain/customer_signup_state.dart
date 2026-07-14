class CustomerSignupState {
  const CustomerSignupState({
    this.verificationId = '',
    this.otpSent = false,
    this.isOtpSending = false,
    this.isVerifyingOtp = false,
    this.isPhoneVerified = false,
    this.isSubmitting = false,
    this.verifiedPhone = '',
    this.message,
    this.error,
  });

  final String verificationId;
  final bool otpSent;
  final bool isOtpSending;
  final bool isVerifyingOtp;
  final bool isPhoneVerified;
  final bool isSubmitting;
  final String verifiedPhone;
  final String? message;
  final String? error;

  CustomerSignupState copyWith({
    String? verificationId,
    bool? otpSent,
    bool? isOtpSending,
    bool? isVerifyingOtp,
    bool? isPhoneVerified,
    bool? isSubmitting,
    String? verifiedPhone,
    String? message,
    String? error,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return CustomerSignupState(
      verificationId: verificationId ?? this.verificationId,
      otpSent: otpSent ?? this.otpSent,
      isOtpSending: isOtpSending ?? this.isOtpSending,
      isVerifyingOtp: isVerifyingOtp ?? this.isVerifyingOtp,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      verifiedPhone: verifiedPhone ?? this.verifiedPhone,
      message: clearMessage ? null : message ?? this.message,
      error: clearError ? null : error ?? this.error,
    );
  }
}
