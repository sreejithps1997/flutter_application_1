class AdminPermissionSet {
  const AdminPermissionSet({required this.isAdmin, required this.roles});

  final bool isAdmin;
  final Set<String> roles;

  bool get isSuperAdmin => roles.contains('super_admin');
  bool get canManagePayments => isSuperAdmin || roles.contains('payment_admin');
  bool get canManageVerification =>
      isSuperAdmin || roles.contains('verification_admin');
  bool get canManageSupport => isSuperAdmin || roles.contains('support_admin');
  bool get canViewAdmin => isAdmin || roles.isNotEmpty;

  String get label {
    if (isSuperAdmin) return 'Super admin';
    if (roles.isEmpty) return isAdmin ? 'Admin' : 'No admin role';
    return roles.map((role) => role.replaceAll('_', ' ')).join(', ');
  }

  factory AdminPermissionSet.fromData(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    final userType = map['userType']?.toString().toLowerCase() ?? '';
    final role = map['adminRole']?.toString().trim().toLowerCase();
    final roles = <String>{};
    if (role != null && role.isNotEmpty && role != 'null') {
      roles.add(role);
    }
    final rawRoles = map['adminRoles'];
    if (rawRoles is Iterable) {
      roles.addAll(
        rawRoles
            .map((item) => item.toString().trim().toLowerCase())
            .where((item) => item.isNotEmpty && item != 'null'),
      );
    }
    if (userType == 'admin' && roles.isEmpty) {
      roles.add('super_admin');
    }
    return AdminPermissionSet(isAdmin: userType == 'admin', roles: roles);
  }
}
