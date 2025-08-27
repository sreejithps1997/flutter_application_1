import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/worker_onboarding_data.dart';
import 'step3_pricing_screen.dart';

class Step2SkillsScreen extends StatefulWidget {
  static const routeName = '/step2-skills';

  final WorkerOnboardingData onboardingData;

  const Step2SkillsScreen({super.key, required this.onboardingData});

  @override
  State<Step2SkillsScreen> createState() => _Step2SkillsScreenState();
}

class _Step2SkillsScreenState extends State<Step2SkillsScreen> {
  final List<Map<String, dynamic>> _skillCategoryData = [
    {
      "title": "House Cleaning",
      "emoji": "🏠",
      "bgColor": Color(0xFFE6F0FF),
      "borderColor": Color(0xFFB3D1FF),
      "skills": [
        {"id": "Regular House Cleaning", "rate": "₹300–500"},
        {"id": "Deep Cleaning", "rate": "₹800–1500"},
        {"id": "Post-Renovation Cleaning", "rate": "₹1000–2000"},
        {"id": "Kitchen Deep Cleaning", "rate": "₹400–700"},
      ],
    },
    {
      "title": "Beauty & Salon",
      "emoji": "💄",
      "bgColor": Color(0xFFFFF0F5),
      "borderColor": Color(0xFFFFD6E7),
      "skills": [
        {"id": "Men's Haircut", "rate": "₹100–300"},
        {"id": "Women's Haircut & Styling", "rate": "₹200–500"},
        {"id": "Facial & Cleanup", "rate": "₹300–800"},
        {"id": "Manicure & Pedicure", "rate": "₹200–500"},
        {"id": "Eyebrow Threading", "rate": "₹50–150"},
      ],
    },
    {
      "title": "Appliance Repair",
      "emoji": "🛠️",
      "bgColor": Color(0xFFE8FFF0),
      "borderColor": Color(0xFFAEEEC1),
      "skills": [
        {"id": "AC Servicing & Repair", "rate": "₹300–800"},
        {"id": "Washing Machine Repair", "rate": "₹200–600"},
        {"id": "Refrigerator Repair", "rate": "₹250–700"},
        {"id": "TV & Electronics Repair", "rate": "₹200–1000"},
      ],
    },
    {
      "title": "Home Maintenance",
      "emoji": "🔨",
      "bgColor": Color(0xFFFFF4E5),
      "borderColor": Color(0xFFFFDAB3),
      "skills": [
        {"id": "Plumbing Services", "rate": "₹200–800"},
        {"id": "Electrical Work", "rate": "₹200–600"},
        {"id": "Painting Services", "rate": "₹15–25/sq ft"},
        {"id": "Carpenter Services", "rate": "₹300–800"},
      ],
    },
  ];

  final List<Map<String, String>> _experienceOptions = [
    {'label': 'Beginner', 'value': '<1 year'},
    {'label': 'Intermediate', 'value': '1–2 years'},
    {'label': 'Experienced', 'value': '3–5 years'},
    {'label': 'Expert', 'value': '5+ years'},
    {'label': 'Master', 'value': '10+ years'},
  ];

  final Map<String, String> _selectedSkillExperience = {};

  void _openExperienceSelector(String skillName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Select experience level for:",
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              Text(
                skillName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ..._experienceOptions.map((option) {
                return ListTile(
                  leading: Radio<String>(
                    value: option['label']!,
                    groupValue: _selectedSkillExperience[skillName],
                    onChanged: (val) {
                      Navigator.pop(context);
                      setState(() {
                        _selectedSkillExperience[skillName] = val!;
                      });
                    },
                  ),
                  title: Text("${option['label']} (${option['value']})"),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedSkillExperience[skillName] = option['label']!;
                    });
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _continueToNextStep() async {
    if (_selectedSkillExperience.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select at least one skill and experience level.",
          ),
        ),
      );
      return;
    }

    for (final entry in _selectedSkillExperience.entries) {
      await FirebaseFirestore.instance.collection('skills').doc(entry.key).set({
        'name': entry.key,
      }, SetOptions(merge: true));
    }

    final updatedData = widget.onboardingData.copyWith(
      skills: _selectedSkillExperience.keys.toList(),
      experienceLevel: 'custom',
    );

    Navigator.pushNamed(
      context,
      Step3PricingScreen.routeName,
      arguments: updatedData,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Select Your Skills"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: 0.4,
              color: Colors.deepPurple,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: _skillCategoryData.map((category) {
                  final String title = category['title'];
                  final String emoji = category['emoji'];
                  final Color bgColor = category['bgColor'];
                  final Color borderColor = category['borderColor'];
                  final List skills = category['skills'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...skills.map((skill) {
                            final String skillId = skill['id'];
                            final isSelected = _selectedSkillExperience
                                .containsKey(skillId);

                            return GestureDetector(
                              onTap: () {
                                if (_selectedSkillExperience.containsKey(
                                  skillId,
                                )) {
                                  // If already selected, unselect it on tap
                                  setState(() {
                                    _selectedSkillExperience.remove(skillId);
                                  });
                                } else {
                                  // Otherwise, open selector
                                  _openExperienceSelector(skillId);
                                }
                              },

                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.blue
                                        : Colors.grey.shade300,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          skillId,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          "Typical rate: ${skill['rate']}",
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                        if (isSelected)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4.0,
                                            ),
                                            child: Text(
                                              "Experience: ${_selectedSkillExperience[skillId]}",
                                              style: const TextStyle(
                                                color: Colors.blueAccent,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Icon(
                                      isSelected
                                          ? Icons.check_box
                                          : Icons.check_box_outline_blank,
                                      color: isSelected
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _continueToNextStep,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.deepPurple,
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
