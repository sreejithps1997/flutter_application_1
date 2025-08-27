// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:image_picker/image_picker.dart';
// import 'dart:io';

// import '../widgets/custom_button.dart';

// class HelpSupportScreen extends StatefulWidget {
//   static const routeName = '/help-support';

//   const HelpSupportScreen({super.key});

//   @override
//   State<HelpSupportScreen> createState() => _HelpSupportScreenState();
// }

// class _HelpSupportScreenState extends State<HelpSupportScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _subjectController = TextEditingController();
//   final TextEditingController _messageController = TextEditingController();

//   File? _selectedImage;
//   bool _isSubmitting = false;

//   Future<void> _pickImage() async {
//     final pickedFile = await ImagePicker().pickImage(
//       source: ImageSource.gallery,
//       imageQuality: 60,
//     );
//     if (pickedFile != null) {
//       setState(() => _selectedImage = File(pickedFile.path));
//     }
//   }

//   Future<void> _submitSupportRequest() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => _isSubmitting = true);

//     final uid = FirebaseAuth.instance.currentUser?.uid;
//     final timestamp = Timestamp.now();

//     final data = {
//       'userId': uid,
//       'subject': _subjectController.text.trim(),
//       'message': _messageController.text.trim(),
//       'timestamp': timestamp,
//     };

//     try {
//       await FirebaseFirestore.instance.collection('support_requests').add(data);

//       // 🟡 Future: Upload screenshot to Firebase Storage & link it here.

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Support request submitted successfully'),
//           ),
//         );
//         Navigator.pop(context);
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
//       }
//     } finally {
//       if (mounted) setState(() => _isSubmitting = false);
//     }
//   }

//   @override
//   void dispose() {
//     _subjectController.dispose();
//     _messageController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Help & Support'),
//         backgroundColor: Colors.deepPurple,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Form(
//           key: _formKey,
//           autovalidateMode: AutovalidateMode.onUserInteraction,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Submit a support request',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 16),

//               TextFormField(
//                 controller: _subjectController,
//                 decoration: const InputDecoration(
//                   labelText: 'Subject',
//                   border: OutlineInputBorder(),
//                 ),
//                 validator: (val) =>
//                     val == null || val.trim().isEmpty ? 'Enter subject' : null,
//               ),
//               const SizedBox(height: 12),

//               TextFormField(
//                 controller: _messageController,
//                 maxLines: 4,
//                 decoration: const InputDecoration(
//                   labelText: 'Message',
//                   border: OutlineInputBorder(),
//                 ),
//                 validator: (val) => val == null || val.trim().isEmpty
//                     ? 'Enter your message'
//                     : null,
//               ),
//               const SizedBox(height: 16),

//               if (_selectedImage != null)
//                 ClipRRect(
//                   borderRadius: BorderRadius.circular(8),
//                   child: Image.file(_selectedImage!, height: 100),
//                 ),
//               TextButton.icon(
//                 onPressed: _pickImage,
//                 icon: const Icon(Icons.image),
//                 label: const Text("Attach Screenshot (optional)"),
//               ),

//               const SizedBox(height: 20),
//               _isSubmitting
//                   ? const Center(child: CircularProgressIndicator())
//                   : CustomButton(
//                       text: 'Submit Request',
//                       onPressed: _submitSupportRequest,
//                     ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HelpSupportScreen extends StatefulWidget {
  static const routeName = '/help-support';

  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Help & Support',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service Status
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        border: Border.all(color: Colors.green[200]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Support Team Available',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Average response time: 2–5 minutes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Search bar
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Describe your problem...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() => searchQuery = value);
                      },
                    ),

                    const SizedBox(height: 24),

                    // Immediate Help
                    const Text(
                      'Need Immediate Help?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        _quickActionCard(
                          icon: LucideIcons.alertTriangle,
                          title: 'Emergency Support',
                          subtitle: 'Safety issues, harassment, fraud',
                          color: Colors.red,
                        ),
                        _quickActionCard(
                          icon: LucideIcons.messageCircle,
                          title: 'Live Chat Support',
                          subtitle: 'Chat with our support team now',
                          color: Colors.blue,
                        ),
                        _quickActionCard(
                          icon: LucideIcons.phone,
                          title: 'Request Callback',
                          subtitle: "We'll call you back in 5 minutes",
                          color: Colors.green,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Problem Categories
                    const Text(
                      'What Problem Are You Facing?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        _issueCard(
                          icon: LucideIcons.users,
                          title: 'Worker Issues',
                          subtitle:
                              'Worker didn\'t show up, poor service quality',
                          urgent: true,
                          color: Colors.red,
                        ),
                        _issueCard(
                          icon: LucideIcons.shield,
                          title: 'Safety & Security',
                          subtitle:
                              'Report harassment, fraud, or safety concerns',
                          urgent: true,
                          color: Colors.red,
                        ),
                        _issueCard(
                          icon: LucideIcons.scale,
                          title: 'Dispute Resolution',
                          subtitle: 'Payment disputes, service disagreements',
                          color: Colors.orange,
                        ),
                        _issueCard(
                          icon: LucideIcons.bug,
                          title: 'App Not Working',
                          subtitle: 'Crashes, login issues, slow performance',
                          color: Colors.purple,
                        ),
                        _issueCard(
                          icon: LucideIcons.flag,
                          title: 'File a Complaint',
                          subtitle: 'Formal complaint about service',
                          color: Colors.amber,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // FAQs
                    _sectionHeader('Common Problems'),
                    _faqCard(
                      question: 'Worker didn\'t show up for the job',
                      answer:
                          'You can report a no-show and get a full refund. We’ll help you find a replacement.',
                    ),
                    _faqCard(
                      question: 'Not satisfied with work quality',
                      answer:
                          'You can request a re-work within 24 hrs or ask for a refund.',
                    ),
                    _faqCard(
                      question: 'Payment was deducted but service failed',
                      answer:
                          'Report this immediately. Refund will be processed within 2–3 days.',
                    ),
                    _faqCard(
                      question: 'How to report inappropriate behavior?',
                      answer:
                          'Use Emergency Support or call our safety helpline.',
                    ),

                    const SizedBox(height: 24),

                    // Self Help Resources
                    _sectionHeader('Self-Help Resources'),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.4,
                      padding: EdgeInsets.zero,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: [
                        _resourceCard(
                          icon: LucideIcons.video,
                          title: 'How-to Videos',
                          subtitle: 'Step-by-step guides',
                          color: Colors.blue,
                        ),
                        _resourceCard(
                          icon: LucideIcons.helpCircle,
                          title: 'Troubleshooting',
                          subtitle: 'Fix common issues',
                          color: Colors.green,
                        ),
                        _resourceCard(
                          icon: LucideIcons.fileText,
                          title: 'Safety Guidelines',
                          subtitle: 'Stay safe & secure',
                          color: Colors.purple,
                        ),
                        _resourceCard(
                          icon: LucideIcons.lightbulb,
                          title: 'Suggestions',
                          subtitle: 'Help us improve',
                          color: Colors.orange,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Contact Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Other Ways to Contact Us',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                LucideIcons.messageSquare,
                                size: 18,
                                color: Colors.green,
                              ),
                              SizedBox(width: 8),
                              Text('WhatsApp: +91 98765-43210'),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                LucideIcons.headphones,
                                size: 18,
                                color: Colors.blue,
                              ),
                              SizedBox(width: 8),
                              Text('Safety Helpline: 1800-XXX-XXXX'),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                LucideIcons.clock,
                                size: 18,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 8),
                              Text('24/7 Emergency Support Available'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Recent Support
                    _sectionHeader('Your Recent Requests'),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Worker No-Show Report',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Request #WS-12345 • In Progress',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: color),
        ],
      ),
    );
  }

  Widget _issueCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    bool urgent = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(width: 4, color: urgent ? Colors.red : color),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 18),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (urgent)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Urgent',
                          style: TextStyle(fontSize: 10, color: Colors.red),
                        ),
                      ),
                  ],
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _faqCard({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Text(
            'View All',
            style: TextStyle(color: Colors.blue, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _resourceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
