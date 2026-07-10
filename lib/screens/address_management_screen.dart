import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';
import 'add_new_address_screen.dart';

class AddressManagementScreen extends StatefulWidget {
  static const routeName = '/address-management';

  final bool isSelectionMode;
  final String? selectedAddressId;

  const AddressManagementScreen({
    super.key,
    this.isSelectionMode = false,
    this.selectedAddressId,
  });

  @override
  State<AddressManagementScreen> createState() =>
      _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  @override
  void initState() {
    super.initState();
    _loadAddresses(); // 🔁 This triggers loading when screen opens
  }

  Future<void> _loadAddresses() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .orderBy('createdAt', descending: true)
        .get();

    if (!mounted) return;
    setState(() {
      addresses = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // store document ID for later actions
        return data;
      }).toList();
    });
  }

  Future<void> _editAddress(Map<String, dynamic> address) async {
    // Navigate to AddNewAddressScreen with existing data
    final updatedAddress = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddNewAddressScreen(isEdit: true, addressData: address),
      ),
    );

    if (widget.isSelectionMode && updatedAddress != null && mounted) {
      Navigator.pop(context, updatedAddress);
      return;
    }

    if (!mounted) return;
    _loadAddresses();
  }

  Future<void> _markAddressUsed(Map<String, dynamic> address) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final addressId = address['id'];

    if (uid == null || addressId == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .doc(addressId)
        .update({'lastUsed': 'Just now', 'lastUsedAt': Timestamp.now()});
  }

  Future<void> _selectAddress(Map<String, dynamic> address) async {
    await _markAddressUsed(address);

    if (!mounted) return;
    Navigator.pop(context, {
      ...address,
      'lastUsed': 'Just now',
      'lastUsedAt': Timestamp.now(),
    });
  }

  Future<void> _bookServiceAtAddress(Map<String, dynamic> address) async {
    await _markAddressUsed(address);

    if (!mounted) return;

    await Navigator.pushNamed(
      context,
      '/book-service',
      arguments: {'selectedAddress': address},
    );

    if (!mounted) return;
    _loadAddresses();
  }

  Future<void> _setAsDefault(String selectedId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final userAddressRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses');

    final allAddresses = await userAddressRef.get();
    for (var doc in allAddresses.docs) {
      batch.update(doc.reference, {'isDefault': doc.id == selectedId});
    }

    await batch.commit();
    if (!mounted) return;
    _loadAddresses();
  }

  Future<void> _deleteAddress(String addressId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .doc(addressId)
          .delete();

      if (!mounted) return;
      _loadAddresses();
    }
  }

  int? activeMenu;

  List<Map<String, dynamic>> addresses = [];

  Map<String, dynamic>? get recentlyUsedAddress {
    if (addresses.isEmpty) return null;

    final sorted = [...addresses];
    sorted.sort((a, b) {
      final aLastUsed = a['lastUsedAt'];
      final bLastUsed = b['lastUsedAt'];
      final aCreated = a['createdAt'];
      final bCreated = b['createdAt'];
      final aTime = aLastUsed is Timestamp ? aLastUsed : aCreated;
      final bTime = bLastUsed is Timestamp ? bLastUsed : bCreated;

      if (aTime is Timestamp && bTime is Timestamp) {
        return bTime.compareTo(aTime);
      }
      if (aTime is Timestamp) return -1;
      if (bTime is Timestamp) return 1;
      return 0;
    });

    return sorted.first;
  }

  IconData getTypeIcon(String type) {
    switch (type) {
      case 'home':
        return LucideIcons.home;
      case 'work':
        return LucideIcons.building2;
      default:
        return LucideIcons.mapPin;
    }
  }

  Color getSafetyColor(String rating) {
    switch (rating) {
      case 'high':
        return Colors.green.shade100;
      case 'medium':
        return Colors.yellow.shade100;
      case 'low':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Color getSafetyTextColor(String rating) {
    switch (rating) {
      case 'high':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget buildAddressCard(Map<String, dynamic> address) {
    final isSelected =
        widget.isSelectionMode &&
        widget.selectedAddressId != null &&
        address['id']?.toString() == widget.selectedAddressId;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? WorkableDesign.primary.withValues(alpha: 0.06)
            : WorkableDesign.surface,
        border: Border.all(
          color: isSelected ? WorkableDesign.primary : WorkableDesign.border,
          width: isSelected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Top Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: WorkableDesign.primary.withValues(alpha: 0.1),
                child: Icon(
                  getTypeIcon(address['type']),
                  color: WorkableDesign.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          address['label'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 6),
                        if (address['isDefault'])
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: WorkableDesign.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 10,
                                color: WorkableDesign.primary,
                              ),
                            ),
                          ),
                        if (address['isVerified']) const SizedBox(width: 6),
                        if (address['isVerified'])
                          const Icon(
                            LucideIcons.check,
                            color: Colors.green,
                            size: 16,
                          ),
                        if (isSelected) const SizedBox(width: 6),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: WorkableDesign.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Selected',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address['address'],
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      address['area'],
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<int>(
                onSelected: (value) {
                  if (value == 0) {
                    _editAddress(address);
                  } else if (value == 1) {
                    _setAsDefault(address['id']);
                  } else if (value == 2) {
                    _deleteAddress(address['id']);
                  }
                },

                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 0,
                    child: ListTile(
                      leading: Icon(LucideIcons.edit3),
                      title: Text('Edit'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 1,
                    child: ListTile(
                      leading: Icon(LucideIcons.star),
                      title: Text('Set as Default'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 2,
                    child: ListTile(
                      leading: Icon(LucideIcons.trash2),
                      title: Text('Delete'),
                    ),
                  ),
                ],
                child: const Icon(LucideIcons.moreVertical, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// Safety & Contact
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getSafetyColor(address['safetyRating']),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.shield, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${address['safetyRating']} safety'.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        color: getSafetyTextColor(address['safetyRating']),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(LucideIcons.phone, size: 14, color: Colors.grey.shade700),
              const SizedBox(width: 4),
              Text(address['contact'], style: const TextStyle(fontSize: 12)),
              const Spacer(),
              Icon(LucideIcons.clock, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(address['lastUsed'], style: const TextStyle(fontSize: 12)),
            ],
          ),

          const SizedBox(height: 10),

          /// Instructions
          if (address['instructions'] != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.alertCircle,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address['instructions'],
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 10),

          /// Quick Actions
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  icon: Icon(
                    widget.isSelectionMode
                        ? LucideIcons.checkCircle
                        : LucideIcons.eye,
                    size: 16,
                  ),
                  label: Text(
                    widget.isSelectionMode ? "Use Address" : "View Details",
                  ),
                  onPressed: () => widget.isSelectionMode
                      ? _selectAddress(address)
                      : _editAddress(address),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  icon: Icon(
                    widget.isSelectionMode
                        ? LucideIcons.edit3
                        : LucideIcons.plus,
                    size: 16,
                  ),
                  label: Text(widget.isSelectionMode ? "Edit" : "Book Service"),
                  onPressed: () => widget.isSelectionMode
                      ? _editAddress(address)
                      : _bookServiceAtAddress(address),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recentAddress = recentlyUsedAddress;
    final defaultCount = addresses.where((a) => a['isDefault'] == true).length;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: Text(
          widget.isSelectionMode ? 'Select Address' : 'Address Management',
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WorkablePageHeader(
            title: widget.isSelectionMode
                ? 'Choose service address'
                : 'Saved addresses',
            subtitle:
                'Keep homes, offices, and family locations ready for faster bookings and help requests.',
            icon: LucideIcons.mapPin,
          ),
          const SizedBox(height: 16),

          /// Quick Stats
          Row(
            children: [
              _buildStatCard(
                "Total",
                addresses.length.toString(),
                WorkableDesign.primary,
              ),
              _buildStatCard(
                "Verified",
                addresses
                    .where((a) => a['isVerified'] == true)
                    .length
                    .toString(),
                WorkableDesign.success,
              ),
              _buildStatCard(
                "Default",
                defaultCount.toString(),
                WorkableDesign.warning,
              ),
            ],
          ),

          const SizedBox(height: 16),

          /// Add New
          ElevatedButton.icon(
            // onPressed: () {
            //   Navigator.pushNamed(context, AddNewAddressScreen.routeName);
            // },
            onPressed: () async {
              final newAddress = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(builder: (_) => const AddNewAddressScreen()),
              );

              if (!context.mounted) return;

              if (widget.isSelectionMode && newAddress != null) {
                Navigator.pop(context, newAddress);
                return;
              }

              _loadAddresses(); // ⬅ reload Firestore addresses after returning
            },

            icon: const Icon(LucideIcons.plus),
            label: const Text("Add New Address"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

          const SizedBox(height: 20),
          if (addresses.isEmpty)
            WorkableEmptyState(
              icon: LucideIcons.mapPin,
              title: 'No saved addresses',
              message:
                  'Add your home, office, or family address to book services faster.',
            ),
          if (addresses.isNotEmpty) ...[
            const Text(
              "Recently Used",
              style: TextStyle(
                color: WorkableDesign.ink,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            if (recentAddress != null) buildAddressCard(recentAddress),

            const SizedBox(height: 20),
            const Text(
              "All Addresses",
              style: TextStyle(
                color: WorkableDesign.ink,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            ...addresses.map(buildAddressCard),
          ],

          const SizedBox(height: 24),

          /// Safety Tips
          Container(
            decoration: BoxDecoration(
              color: Colors.yellow.shade50,
              border: Border.all(color: Colors.yellow.shade200),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.shield, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Safety Tips",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "For your safety, always meet workers in well-lit, accessible areas. Avoid sharing addresses late at night.",
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: WorkableDesign.surface,
          border: Border.all(color: WorkableDesign.border),
          borderRadius: BorderRadius.circular(WorkableDesign.radius),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: WorkableDesign.muted),
            ),
          ],
        ),
      ),
    );
  }
}
