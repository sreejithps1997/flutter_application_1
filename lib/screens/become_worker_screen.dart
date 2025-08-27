import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class BecomeWorkerScreen extends StatefulWidget {
  static const routeName = '/become-worker';

  const BecomeWorkerScreen({super.key});

  @override
  State<BecomeWorkerScreen> createState() => _BecomeWorkerScreenState();
}

class _BecomeWorkerScreenState extends State<BecomeWorkerScreen> {
  static const routeName = '/become-worker';
  bool isRegistered = false;

  Widget buildProgressStep(
    int step,
    String title, {
    bool completed = false,
    bool active = false,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: completed
                ? Colors.green
                : active
                ? Colors.blue
                : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: completed
                ? const Icon(Icons.check_circle, size: 18, color: Colors.white)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: active ? Colors.white : Colors.black,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: active ? Colors.blue : Colors.grey.shade700,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    String? badge,
    String? status,
    Color color = Colors.blue,
  }) {
    Icon? statusIcon;
    if (status == 'completed') {
      statusIcon = const Icon(
        Icons.check_circle,
        size: 16,
        color: Colors.green,
      );
    } else if (status == 'pending') {
      statusIcon = const Icon(
        Icons.access_time,
        size: 16,
        color: Colors.orange,
      );
    } else if (status == 'required') {
      statusIcon = const Icon(Icons.error_outline, size: 16, color: Colors.red);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    if (statusIcon != null) statusIcon,
                    if (badge != null)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget buildStatsCard(
    String number,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          Icon(icon, color: color),
        ],
      ),
    );
  }

  Widget buildNotRegisteredView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.blue, Colors.indigo],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.work, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Start Earning Today!",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Join thousands of workers and grow your income",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  minimumSize: const Size.fromHeight(45),
                ),
                child: const Text("Get Started Now"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Why become a worker?",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...[
          "Flexible working hours",
          "Direct payments after job completion",
          "Build your reputation with ratings",
          "Access to insurance benefits",
        ].map(
          (e) => Row(
            children: [
              const Icon(Icons.circle, size: 8, color: Colors.green),
              const SizedBox(width: 8),
              Text(e),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Registration Process",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        buildProgressStep(1, "Personal Details", active: true),
        buildProgressStep(2, "Skills & Services"),
        buildProgressStep(3, "Identity Verification"),
        buildProgressStep(4, "Profile Setup"),
        buildProgressStep(5, "Account Approval"),
        const SizedBox(height: 20),
        const Text(
          "What you'll need",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        buildMenuItem(
          icon: LucideIcons.user,
          title: "Valid Identity Proof",
          subtitle: "Aadhaar, PAN, or Driving License",
          color: Colors.orange,
        ),
        buildMenuItem(
          icon: LucideIcons.camera,
          title: "Profile Photo",
          subtitle: "Clear, professional photo",
          color: Colors.purple,
        ),
        buildMenuItem(
          icon: LucideIcons.wrench,
          title: "Skills Information",
          subtitle: "List your services and experience",
          color: Colors.green,
        ),
        buildMenuItem(
          icon: LucideIcons.phone,
          title: "Contact Details",
          subtitle: "Phone number and email",
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget buildActiveWorkerView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Worker Profile Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.green,
                    child: const Text(
                      "JD",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Text(
                          "John Doe",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.verified, size: 18, color: Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Active Worker",
                      style: TextStyle(color: Colors.green),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: const [
                        Icon(Icons.star, size: 16, color: Colors.amber),
                        SizedBox(width: 4),
                        Text(
                          "4.8",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "156 jobs completed",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            buildStatsCard(
              "₹8,450",
              "This Month",
              LucideIcons.wallet,
              Colors.green,
            ),
            buildStatsCard(
              "12",
              "Active Bookings",
              LucideIcons.calendar,
              Colors.blue,
            ),
            buildStatsCard(
              "4.8",
              "Avg Rating",
              LucideIcons.star,
              Colors.orange,
            ),
            buildStatsCard(
              "156",
              "Total Jobs",
              LucideIcons.trendingUp,
              Colors.purple,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          "Quick Actions",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Expanded(
              child: buildMenuItem(
                icon: LucideIcons.calendar,
                title: "Manage Calendar",
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: buildMenuItem(
                icon: LucideIcons.wallet,
                title: "View Earnings",
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          "Profile & Services",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        buildMenuItem(
          icon: LucideIcons.user,
          title: "Worker Profile",
          subtitle: "Update your info",
          status: 'completed',
        ),
        buildMenuItem(
          icon: LucideIcons.wrench,
          title: "Services & Skills",
          subtitle: "5 services",
        ),
        buildMenuItem(
          icon: LucideIcons.star,
          title: "Portfolio & Gallery",
          subtitle: "12 photos",
        ),
        buildMenuItem(
          icon: LucideIcons.indianRupee,
          title: "Pricing & Rates",
          subtitle: "Set service rates",
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Become a Worker"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            isRegistered ? buildActiveWorkerView() : buildNotRegisteredView(),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => setState(() => isRegistered = !isRegistered),
              child: Text(
                "Demo: Toggle to ${isRegistered ? 'Registration' : 'Active Worker'} View",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
