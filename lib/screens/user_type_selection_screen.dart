import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/workable_design.dart';

class UserTypeSelectionScreen extends StatefulWidget {
  static const routeName = '/user-type-selection';

  const UserTypeSelectionScreen({super.key});

  @override
  State<UserTypeSelectionScreen> createState() =>
      _UserTypeSelectionScreenState();
}

class _UserTypeSelectionScreenState extends State<UserTypeSelectionScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  String _selectedRole = '';
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _navigateToRole(String role) async {
    setState(() {
      _isLoading = true;
      _selectedRole = role;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (!mounted) return;

        final userType = doc.data()?['userType'];

        if (userType == role) {
          if (role == 'customer') {
            Navigator.pushReplacementNamed(context, '/customer-dashboard');
          } else if (role == 'worker') {
            Navigator.pushReplacementNamed(context, '/worker-dashboard');
          }
          return;
        }

        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
      }

      if (role == 'customer') {
        Navigator.pushNamed(context, '/customer-auth');
      } else if (role == 'worker') {
        Navigator.pushNamed(context, '/worker-auth');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: WorkableDesign.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedRole = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              children: [
                _buildBrandHeader(),
                const SizedBox(height: 34),
                const Text(
                  'What do you need today?',
                  style: TextStyle(
                    color: WorkableDesign.ink,
                    fontSize: 30,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Book trusted help nearby or grow your service business from one simple app.',
                  style: TextStyle(
                    color: WorkableDesign.muted,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
                _buildRoleCard(
                  role: 'customer',
                  icon: Icons.person_search_outlined,
                  title: 'I need help',
                  description:
                      'Find verified workers for home service, repairs, delivery, pickup, and daily support.',
                  accentColor: WorkableDesign.primary,
                  badges: const ['Verified workers', 'Live booking flow'],
                ),
                const SizedBox(height: 14),
                _buildRoleCard(
                  role: 'worker',
                  icon: Icons.engineering_outlined,
                  title: 'I offer services',
                  description:
                      'Receive nearby jobs, manage bookings, build trust, and track earnings.',
                  accentColor: WorkableDesign.accent,
                  badges: const ['Business profile', 'Payout ready'],
                ),
                const SizedBox(height: 28),
                _buildTrustStrip(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: WorkableDesign.ink,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: WorkableDesign.primary.withValues(alpha: 0.16),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.handshake_outlined,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workable',
              style: TextStyle(
                color: WorkableDesign.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Your local helping hand',
              style: TextStyle(
                color: WorkableDesign.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required String title,
    required String description,
    required Color accentColor,
    required List<String> badges,
  }) {
    final isSelected = _selectedRole == role;
    final isLoading = _isLoading && isSelected;

    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: isSelected ? 0.985 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : () => _navigateToRole(role),
          borderRadius: BorderRadius.circular(WorkableDesign.radius),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: WorkableDesign.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: accentColor, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: WorkableDesign.ink,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: const TextStyle(
                              color: WorkableDesign.muted,
                              fontSize: 13.5,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (isLoading)
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: accentColor,
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: accentColor,
                        size: 24,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: badges
                      .map((badge) => _buildBadge(badge, accentColor))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accentColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildTrustStrip() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: WorkableDesign.cardDecoration(
        color: WorkableDesign.ink,
        borderColor: WorkableDesign.ink,
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_outlined, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Built for verified profiles, protected bookings, and transparent payments.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
