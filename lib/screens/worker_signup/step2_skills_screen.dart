import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../core/theme/workable_design.dart';
import '../../models/worker_onboarding_data.dart';
import '../../widgets/worker_onboarding_shell.dart';
import 'step3_pricing_screen.dart';

class Step2SkillsScreen extends StatefulWidget {
  static const routeName = '/step2-skills';
  final WorkerOnboardingData onboardingData;

  const Step2SkillsScreen({super.key, required this.onboardingData});

  @override
  State<Step2SkillsScreen> createState() => _Step2SkillsScreenState();
}

class _Step2SkillsScreenState extends State<Step2SkillsScreen> {
  final List<_SkillCategory> _categories = const [
    _SkillCategory(
      title: 'House Cleaning',
      icon: Icons.cleaning_services_outlined,
      skills: [
        _SkillOption('Regular House Cleaning', 'Rs 300-500'),
        _SkillOption('Deep Cleaning', 'Rs 800-1500'),
        _SkillOption('Post-Renovation Cleaning', 'Rs 1000-2000'),
        _SkillOption('Kitchen Deep Cleaning', 'Rs 400-700'),
      ],
    ),
    _SkillCategory(
      title: 'Beauty & Salon',
      icon: Icons.spa_outlined,
      skills: [
        _SkillOption("Men's Haircut", 'Rs 100-300'),
        _SkillOption("Women's Haircut & Styling", 'Rs 200-500'),
        _SkillOption('Facial & Cleanup', 'Rs 300-800'),
        _SkillOption('Manicure & Pedicure', 'Rs 200-500'),
        _SkillOption('Eyebrow Threading', 'Rs 50-150'),
      ],
    ),
    _SkillCategory(
      title: 'Appliance Repair',
      icon: Icons.home_repair_service_outlined,
      skills: [
        _SkillOption('AC Servicing & Repair', 'Rs 300-800'),
        _SkillOption('Washing Machine Repair', 'Rs 200-600'),
        _SkillOption('Refrigerator Repair', 'Rs 250-700'),
        _SkillOption('TV & Electronics Repair', 'Rs 200-1000'),
      ],
    ),
    _SkillCategory(
      title: 'Home Maintenance',
      icon: Icons.handyman_outlined,
      skills: [
        _SkillOption('Plumbing Services', 'Rs 200-800'),
        _SkillOption('Electrical Work', 'Rs 200-600'),
        _SkillOption('Painting Services', 'Rs 15-25/sq ft'),
        _SkillOption('Carpenter Services', 'Rs 300-800'),
      ],
    ),
  ];

  final List<Map<String, String>> _experienceOptions = const [
    {'label': 'Beginner', 'value': '<1 year'},
    {'label': 'Intermediate', 'value': '1-2 years'},
    {'label': 'Experienced', 'value': '3-5 years'},
    {'label': 'Expert', 'value': '5+ years'},
    {'label': 'Master', 'value': '10+ years'},
  ];

  final Map<String, String> _selectedSkillExperience = {};

  @override
  void initState() {
    super.initState();
    _selectedSkillExperience.addAll(widget.onboardingData.skillExperience);
  }

  void _openExperienceSelector(String skillName) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Experience level',
                  style: TextStyle(
                    color: WorkableDesign.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  skillName,
                  style: const TextStyle(
                    color: WorkableDesign.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ..._experienceOptions.map((option) {
                  final label = option['label']!;
                  final value = option['value']!;
                  return RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: label,
                    groupValue: _selectedSkillExperience[skillName],
                    title: Text('$label ($value)'),
                    onChanged: (val) {
                      Navigator.pop(context);
                      setState(() {
                        _selectedSkillExperience[skillName] = val!;
                      });
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _continueToNextStep() async {
    if (_selectedSkillExperience.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one skill and experience level.'),
        ),
      );
      return;
    }

    final callable = FirebaseFunctions.instanceFor(
      region: 'us-central1',
    ).httpsCallable('suggestWorkerSignupSkill');
    for (final entry in _selectedSkillExperience.entries) {
      await callable.call<Map<String, dynamic>>({'skill': entry.key});
    }

    if (!mounted) return;
    final updatedData = widget.onboardingData.copyWith(
      skills: _selectedSkillExperience.keys.toList(),
      skillExperience: _selectedSkillExperience,
      experienceLevel: 'per_skill',
    );

    Navigator.pushNamed(
      context,
      Step3PricingScreen.routeName,
      arguments: updatedData,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WorkerOnboardingShell(
      title: 'Choose your services',
      subtitle:
          'Select only the work you can confidently accept. Accurate skills help customers book the right worker faster.',
      step: 3,
      totalSteps: 6,
      bottom: FilledButton(
        onPressed: _continueToNextStep,
        child: Text(
          _selectedSkillExperience.isEmpty
              ? 'Continue'
              : 'Continue (${_selectedSkillExperience.length})',
        ),
      ),
      children: _categories.map(_buildCategoryCard).toList(),
    );
  }

  Widget _buildCategoryCard(_SkillCategory category) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: WorkerOnboardingCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(category.icon, color: WorkableDesign.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category.title,
                    style: const TextStyle(
                      color: WorkableDesign.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...category.skills.map(_buildSkillTile),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillTile(_SkillOption skill) {
    final isSelected = _selectedSkillExperience.containsKey(skill.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          if (isSelected) {
            setState(() => _selectedSkillExperience.remove(skill.name));
          } else {
            _openExperienceSelector(skill.name);
          }
        },
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? WorkableDesign.accent.withValues(alpha: 0.08)
                : WorkableDesign.canvas,
            borderRadius: BorderRadius.circular(WorkableDesign.radius),
            border: Border.all(
              color: isSelected
                  ? WorkableDesign.accent.withValues(alpha: 0.35)
                  : WorkableDesign.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      style: const TextStyle(
                        color: WorkableDesign.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSelected
                          ? 'Experience: ${_selectedSkillExperience[skill.name]}'
                          : 'Typical rate: ${skill.rate}',
                      style: TextStyle(
                        color: isSelected
                            ? WorkableDesign.accent
                            : WorkableDesign.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.check_circle
                    : Icons.add_circle_outline_rounded,
                color: isSelected
                    ? WorkableDesign.accent
                    : WorkableDesign.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkillCategory {
  final String title;
  final IconData icon;
  final List<_SkillOption> skills;

  const _SkillCategory({
    required this.title,
    required this.icon,
    required this.skills,
  });
}

class _SkillOption {
  final String name;
  final String rate;

  const _SkillOption(this.name, this.rate);
}
