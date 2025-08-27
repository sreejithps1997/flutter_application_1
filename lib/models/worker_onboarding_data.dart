class WorkerOnboardingData {
  String fullName;
  String phone;
  String gender;
  bool imagePicked;
  List<String> skills;
  String experienceLevel;
  String paymentMethod;
  Map<String, dynamic> schedule;
  String primaryIdType;
  String phoneNumber;
  bool consent;
  String email;
  String location;
  DateTime? submittedAt;
  String? profileImageUrl;
  String uid;
  int age;

  // Step 1 location fields
  String address;
  String city;
  String pincode;
  int serviceRadius;
  double latitude;
  double longitude;

  // NEW FIELDS for pricing & payment
  Map<String, String> wageMap;
  String? upiId;
  String? bankAccountNumber;
  String? ifscCode;

  WorkerOnboardingData({
    required this.fullName,
    required this.phone,
    required this.gender,
    this.imagePicked = false,
    this.skills = const [],
    this.experienceLevel = '',
    this.paymentMethod = '',
    this.schedule = const {},
    this.primaryIdType = '',
    this.phoneNumber = '',
    this.consent = false,
    this.email = '',
    this.location = 'N/A',
    this.submittedAt,
    this.profileImageUrl,
    required this.uid,
    required this.age,
    this.address = '',
    this.city = '',
    this.pincode = '',
    this.serviceRadius = 2,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.wageMap = const {},
    this.upiId,
    this.bankAccountNumber,
    this.ifscCode,
  });

  WorkerOnboardingData copyWith({
    String? fullName,
    String? phone,
    String? gender,
    bool? imagePicked,
    List<String>? skills,
    String? experienceLevel,
    String? paymentMethod,
    Map<String, dynamic>? schedule,
    String? primaryIdType,
    String? phoneNumber,
    bool? consent,
    String? email,
    String? location,
    DateTime? submittedAt,
    String? profileImageUrl,
    String? uid,
    int? age,
    String? address,
    String? city,
    String? pincode,
    int? serviceRadius,
    double? latitude,
    double? longitude,
    Map<String, String>? wageMap,
    String? upiId,
    String? bankAccountNumber,
    String? ifscCode,
  }) {
    return WorkerOnboardingData(
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      imagePicked: imagePicked ?? this.imagePicked,
      skills: skills ?? this.skills,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      schedule: schedule ?? this.schedule,
      primaryIdType: primaryIdType ?? this.primaryIdType,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      consent: consent ?? this.consent,
      email: email ?? this.email,
      location: location ?? this.location,
      submittedAt: submittedAt ?? this.submittedAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      uid: uid ?? this.uid,
      age: age ?? this.age,
      address: address ?? this.address,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      serviceRadius: serviceRadius ?? this.serviceRadius,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      wageMap: wageMap ?? this.wageMap,
      upiId: upiId ?? this.upiId,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phone': phone,
      'gender': gender,
      'imagePicked': imagePicked,
      'skills': skills,
      'experienceLevel': experienceLevel,
      'paymentMethod': paymentMethod,
      'schedule': schedule,
      'primaryIdType': primaryIdType,
      'phoneNumber': phoneNumber,
      'consent': consent,
      'email': email,
      'location': location,
      'submittedAt': submittedAt?.toIso8601String(),
      'profileImageUrl': profileImageUrl,
      'uid': uid,
      'age': age,
      'address': address,
      'city': city,
      'pincode': pincode,
      'serviceRadius': serviceRadius,
      'latitude': latitude,
      'longitude': longitude,
      'wageMap': wageMap,
      'upiId': upiId,
      'bankAccountNumber': bankAccountNumber,
      'ifscCode': ifscCode,
    };
  }

  factory WorkerOnboardingData.fromMap(Map<String, dynamic> map) {
    return WorkerOnboardingData(
      fullName: map['fullName'] ?? '',
      phone: map['phone'] ?? '',
      gender: map['gender'] ?? '',
      imagePicked: map['imagePicked'] ?? false,
      skills: List<String>.from(map['skills'] ?? []),
      experienceLevel: map['experienceLevel'] ?? '',
      paymentMethod: map['paymentMethod'] ?? '',
      schedule: Map<String, dynamic>.from(map['schedule'] ?? {}),
      primaryIdType: map['primaryIdType'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      consent: map['consent'] ?? false,
      email: map['email'] ?? '',
      location: map['location'] ?? 'N/A',
      submittedAt: map['submittedAt'] != null
          ? DateTime.tryParse(map['submittedAt'])
          : null,
      profileImageUrl: map['profileImageUrl'],
      uid: map['uid'] ?? '',
      age: map['age'] ?? 0,
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      pincode: map['pincode'] ?? '',
      serviceRadius: map['serviceRadius'] ?? 2,
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      wageMap: Map<String, String>.from(map['wageMap'] ?? {}),
      upiId: map['upiId'],
      bankAccountNumber: map['bankAccountNumber'],
      ifscCode: map['ifscCode'],
    );
  }
}
