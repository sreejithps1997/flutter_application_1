import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/custom_button.dart';

class BackgroundCheckScreen extends StatefulWidget {
  static const routeName = '/background-check';

  const BackgroundCheckScreen({super.key});

  @override
  State<BackgroundCheckScreen> createState() => _BackgroundCheckScreenState();
}

class _BackgroundCheckScreenState extends State<BackgroundCheckScreen> {
  String activeTab = 'documents';

  Widget buildStatusBadge(String status, String text) {
    Color bgColor, textColor, borderColor;

    switch (status) {
      case 'verified':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        borderColor = Colors.green.shade200;
        break;
      case 'pending':
        bgColor = Colors.yellow.shade100;
        textColor = Colors.yellow.shade800;
        borderColor = Colors.yellow.shade200;
        break;
      case 'failed':
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        borderColor = Colors.red.shade200;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
        borderColor = Colors.grey.shade300;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget buildDocumentCard({
    required IconData icon,
    required String title,
    required String description,
    required String status,
    bool required = true,
    bool sampleDoc = false,
  }) {
    Color borderColor, bgColor;
    Icon statusIcon;

    switch (status) {
      case 'verified':
        borderColor = Colors.green.shade200;
        bgColor = Colors.green.shade50;
        statusIcon = const Icon(
          LucideIcons.checkCircle,
          color: Colors.green,
          size: 20,
        );
        break;
      case 'pending':
        borderColor = Colors.yellow.shade200;
        bgColor = Colors.yellow.shade50;
        statusIcon = const Icon(
          LucideIcons.clock,
          color: Colors.orange,
          size: 20,
        );
        break;
      case 'failed':
        borderColor = Colors.red.shade200;
        bgColor = Colors.red.shade50;
        statusIcon = const Icon(
          LucideIcons.xCircle,
          color: Colors.red,
          size: 20,
        );
        break;
      default:
        borderColor = Colors.grey.shade300;
        bgColor = Colors.white;
        statusIcon = const Icon(
          LucideIcons.upload,
          color: Colors.grey,
          size: 20,
        );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
          color: borderColor,
          width: 2,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue, size: 20),
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
                    const SizedBox(width: 6),
                    if (required)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(fontSize: 10, color: Colors.red),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (status == 'incomplete')
                      CustomButton(
                        text: "Upload Document",
                        icon: LucideIcons.upload,
                        onPressed: () {},
                        isSmall: true,
                      )
                    else
                      Row(
                        children: [
                          statusIcon,
                          const SizedBox(width: 6),
                          Text(
                            status == 'verified'
                                ? 'Verified'
                                : status == 'pending'
                                ? 'Under Review'
                                : 'Rejected',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(width: 8),
                    if (sampleDoc)
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(LucideIcons.eye, size: 16),
                        label: const Text(
                          "View Sample",
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ),
                if (status == 'failed')
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          LucideIcons.alertTriangle,
                          size: 14,
                          color: Colors.red,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Document quality unclear. Please upload a clearer image.",
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProcessStep({
    required String step,
    required String title,
    required String status,
    required String description,
    String? estimatedTime,
  }) {
    Color color;
    Widget child;
    if (status == 'completed') {
      color = Colors.green;
      child = const Icon(LucideIcons.check, color: Colors.white, size: 16);
    } else if (status == 'active') {
      color = Colors.blue;
      child = Text(
        step,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      color = Colors.grey.shade300;
      child = Text(step, style: const TextStyle(color: Colors.grey));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: child,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: status == 'active' ? Colors.blue : Colors.black,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                if (estimatedTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "⏱ $estimatedTime",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          "Background Check",
          style: TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(LucideIcons.helpCircle, color: Colors.grey),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status Overview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.shield,
                          color: Colors.blue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Background Verification",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            buildStatusBadge("pending", "2 of 4 completed"),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text.rich(
                      TextSpan(
                        text: "Enhanced Trust: ",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(
                            text:
                                "Complete background verification to unlock premium features and gain customer confidence.",
                            style: TextStyle(fontWeight: FontWeight.normal),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tabs
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () =>
                              setState(() => activeTab = 'documents'),
                          child: Text(
                            "Documents",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: activeTab == 'documents'
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () =>
                              setState(() => activeTab = 'process'),
                          child: Text(
                            "Process",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: activeTab == 'process'
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: activeTab == 'documents'
                        ? Column(
                            children: [
                              buildDocumentCard(
                                icon: LucideIcons.shield,
                                title: "Police Clearance Certificate",
                                description:
                                    "Valid police verification certificate (not older than 6 months)",
                                status: "verified",
                                sampleDoc: true,
                              ),
                              const SizedBox(height: 12),
                              buildDocumentCard(
                                icon: LucideIcons.users,
                                title: "Character References",
                                description:
                                    "2-3 character references from previous employers or community leaders",
                                status: "pending",
                              ),
                              const SizedBox(height: 12),
                              buildDocumentCard(
                                icon: LucideIcons.briefcase,
                                title: "Employment History",
                                description:
                                    "Previous work experience certificates or testimonials",
                                status: "incomplete",
                                required: false,
                              ),
                              const SizedBox(height: 12),
                              buildDocumentCard(
                                icon: LucideIcons.award,
                                title: "Skill Certificates",
                                description:
                                    "Relevant trade/skill certifications (if applicable)",
                                status: "failed",
                                required: false,
                                sampleDoc: true,
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              buildProcessStep(
                                step: "1",
                                title: "Document Submission",
                                status: "completed",
                                description:
                                    "Upload required documents and certificates",
                                estimatedTime: "5 minutes",
                              ),
                              buildProcessStep(
                                step: "2",
                                title: "Document Review",
                                status: "active",
                                description:
                                    "Our team reviews submitted documents for authenticity",
                                estimatedTime: "2–4 hours",
                              ),
                              buildProcessStep(
                                step: "3",
                                title: "Reference Verification",
                                status: "pending",
                                description:
                                    "We contact your references to verify information",
                                estimatedTime: "1–2 business days",
                              ),
                              buildProcessStep(
                                step: "4",
                                title: "Final Approval",
                                status: "pending",
                                description:
                                    "Complete verification and profile activation",
                                estimatedTime: "30 minutes",
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
