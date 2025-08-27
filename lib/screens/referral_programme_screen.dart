import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ReferralProgrammeScreen extends StatefulWidget {
  static const routeName = '/referral-programme';

  const ReferralProgrammeScreen({super.key});

  @override
  State<ReferralProgrammeScreen> createState() =>
      _ReferralProgrammeScreenState();
}

class _ReferralProgrammeScreenState extends State<ReferralProgrammeScreen> {
  bool copied = false;

  final List<Map<String, String>> referralHistory = [
    {
      'name': 'Priya Sharma',
      'status': 'completed',
      'reward': '₹100',
      'date': '2 days ago',
      'avatar': 'PS',
    },
    {
      'name': 'Raj Kumar',
      'status': 'pending',
      'reward': '₹100',
      'date': '5 days ago',
      'avatar': 'RK',
    },
    {
      'name': 'Anjali Singh',
      'status': 'completed',
      'reward': '₹100',
      'date': '1 week ago',
      'avatar': 'AS',
    },
    {
      'name': 'Vikram Patel',
      'status': 'rejected',
      'reward': '₹0',
      'date': '2 weeks ago',
      'avatar': 'VP',
    },
  ];

  void handleCopyCode() async {
    await Clipboard.setData(const ClipboardData(text: 'JOHN2024'));
    setState(() => copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => copied = false);
    });
  }

  Widget buildReferralItem(Map<String, String> referral) {
    IconData icon;
    Color color;

    switch (referral['status']) {
      case 'completed':
        icon = LucideIcons.check;
        color = Colors.green;
        break;
      case 'pending':
        icon = LucideIcons.clock;
        color = Colors.orange;
        break;
      default:
        icon = LucideIcons.x;
        color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.blueAccent,
            child: Text(
              referral['avatar']!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  referral['name']!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  referral['date']!,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                referral['reward']!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(
                      referral['status']!,
                      style: TextStyle(color: color, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildStatCard(
    IconData icon,
    String value,
    String label,
    Color color,
    String? trend,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              if (trend != null)
                Row(
                  children: [
                    const Icon(
                      LucideIcons.trendingUp,
                      size: 14,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+$trend%',
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget buildShareButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: const BackButton(color: Colors.black87),
        title: const Text(
          'Referral Programme',
          style: TextStyle(color: Colors.black87),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Hero
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.lightBlueAccent],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Invite & Earn!",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Refer friends and get rewarded",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        LucideIcons.gift,
                        color: Colors.white,
                        size: 36,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'JOHN2024',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: handleCopyCode,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue,
                          ),
                          icon: Icon(
                            copied ? LucideIcons.check : LucideIcons.copy,
                            size: 16,
                          ),
                          label: Text(copied ? 'Copied!' : 'Copy'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // How it works
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(LucideIcons.star, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "How It Works",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...[
                    {
                      'step': '1',
                      'title': 'Share your code',
                      'desc': 'Friend signs up using your referral code',
                    },
                    {
                      'step': '2',
                      'title': 'Friend completes first booking',
                      'desc': 'Minimum booking value of ₹200',
                    },
                    {
                      'step': '3',
                      'title': 'Both get rewarded!',
                      'desc': 'You get ₹100, friend gets ₹50 credit',
                    },
                  ].map(
                    (step) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              step['step']!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step['title']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  step['desc']!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats
            Row(
              children: [
                Expanded(
                  child: buildStatCard(
                    LucideIcons.users,
                    "12",
                    "Friends Referred",
                    Colors.blue,
                    "25",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildStatCard(
                    LucideIcons.wallet,
                    "₹850",
                    "Total Earned",
                    Colors.green,
                    "15",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Share
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(LucideIcons.share2, size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        "Share With Friends",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      buildShareButton(
                        LucideIcons.messageCircle,
                        "WhatsApp",
                        Colors.green,
                        () {},
                      ),
                      buildShareButton(
                        LucideIcons.mail,
                        "Email",
                        Colors.blue,
                        () {},
                      ),
                      buildShareButton(
                        LucideIcons.facebook,
                        "Facebook",
                        Colors.blue.shade800,
                        () {},
                      ),
                      buildShareButton(
                        LucideIcons.twitter,
                        "Twitter",
                        Colors.lightBlue,
                        () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Campaign
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.purple, Colors.pink],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(LucideIcons.trophy, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        "Special Campaign",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Spacer(),
                      Icon(LucideIcons.calendar, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        "5 days left",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Double Rewards Week!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    "Get ₹200 for each successful referral instead of ₹100",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        "Progress: 3/10 referrals",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const Spacer(),
                      Container(
                        width: 80,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white30,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: 0.3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Referral History
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  "Recent Referrals",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text("View All", style: TextStyle(color: Colors.blue)),
              ],
            ),
            const SizedBox(height: 10),
            ...referralHistory.take(3).map(buildReferralItem).toList(),
            const SizedBox(height: 16),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {},
                    child: const Text("Invite Friends"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {},
                    child: const Text("View Terms"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Text(
              "Referral rewards are credited within 24 hours",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
