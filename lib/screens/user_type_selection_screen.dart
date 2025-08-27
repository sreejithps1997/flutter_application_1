import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
        );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _navigateToRole(BuildContext context, String role) async {
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
        final userType = doc.data()?['userType'];

        if (userType == role) {
          // Navigate directly to dashboard
          if (role == 'customer') {
            Navigator.pushReplacementNamed(context, '/customer-dashboard');
          } else if (role == 'worker') {
            Navigator.pushReplacementNamed(context, '/worker-dashboard');
          }
          return;
        } else {
          // Signed in user but different role
          await FirebaseAuth.instance.signOut();
        }
      }

      // Not logged in or role mismatch, go to auth
      if (role == 'customer') {
        Navigator.pushNamed(context, '/customer-auth');
      } else if (role == 'worker') {
        Navigator.pushNamed(context, '/worker-auth');
      }
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade50,
              Colors.white,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // App Logo/Branding
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.deepPurple.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.work_outline,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 30),

                          // Title
                          Text(
                            "Welcome to Workable",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 8),

                          // Subtitle
                          Text(
                            "Connect with skilled workers or offer your services",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: 50),

                          // Role Selection Cards
                          _buildRoleCard(
                            context,
                            role: 'customer',
                            icon: Icons.person_outline,
                            title: "I'm a Customer",
                            description:
                                "Book skilled workers for home services",
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade600,
                              ],
                            ),
                            stats: "Join 5,000+ happy customers",
                          ),
                          SizedBox(height: 20),

                          _buildRoleCard(
                            context,
                            role: 'worker',
                            icon: Icons.handyman_outlined,
                            title: "I'm a Worker",
                            description: "Offer your skills and earn money",
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade400,
                                Colors.orange.shade600,
                              ],
                            ),
                            stats: "Join 10,000+ skilled workers",
                          ),
                        ],
                      ),
                    ),

                    // Bottom Options
                    Column(
                      children: [
                        TextButton(
                          onPressed: () {
                            // Navigate to browse/guest mode
                            Navigator.pushNamed(context, '/browse-services');
                          },
                          child: Text(
                            "Browse services without signing up",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        SizedBox(height: 10),

                        // Trust indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.security,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                            SizedBox(width: 4),
                            Text(
                              "Secure • Verified • Trusted",
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String role,
    required IconData icon,
    required String title,
    required String description,
    required LinearGradient gradient,
    required String stats,
  }) {
    bool isSelected = _selectedRole == role;
    bool isLoading = _isLoading && isSelected;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      transform: Matrix4.identity()..scale(isSelected ? 0.98 : 1.0),
      child: GestureDetector(
        onTap: isLoading ? null : () => _navigateToRole(context, role),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.3),
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 30, color: Colors.white),
              ),
              SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      stats,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Loading or Arrow
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: Colors.white.withOpacity(0.8),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
