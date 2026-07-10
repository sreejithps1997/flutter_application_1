import 'package:flutter/material.dart';

import '../../core/theme/workable_design.dart';
import '../../models/worker_onboarding_data.dart';
import '../../widgets/worker_onboarding_shell.dart';
import 'step5_verify_screen.dart';

class Step4ScheduleScreen extends StatefulWidget {
  static const routeName = '/step4-schedule';
  final WorkerOnboardingData onboardingData;

  const Step4ScheduleScreen({super.key, required this.onboardingData});

  @override
  State<Step4ScheduleScreen> createState() => _Step4ScheduleScreenState();
}

class _Step4ScheduleScreenState extends State<Step4ScheduleScreen> {
  String? _startTime;
  String? _endTime;
  bool _isFlexible = false;
  bool _acceptsUrgentJobs = true;
  final Set<String> _selectedDays = {};

  final List<String> _days = const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  final List<String> _timeOptions = const [
    '6:00 AM',
    '7:00 AM',
    '8:00 AM',
    '9:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '1:00 PM',
    '2:00 PM',
    '3:00 PM',
    '4:00 PM',
    '5:00 PM',
    '6:00 PM',
    '7:00 PM',
    '8:00 PM',
    '9:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    final schedule = widget.onboardingData.schedule;
    _startTime = schedule['startTime'] as String?;
    _endTime = schedule['endTime'] as String?;
    _isFlexible = schedule['isFlexible'] == true;
    _acceptsUrgentJobs = schedule['acceptsUrgentJobs'] != false;
    _selectedDays.addAll(
      List<String>.from(schedule['availableDays'] ?? const []),
    );
  }

  void _selectEveryDay() {
    setState(() {
      _selectedDays
        ..clear()
        ..addAll(_days);
    });
  }

  void _proceedToNextStep() {
    if (_selectedDays.isEmpty) {
      _showMessage('Select at least one working day.');
      return;
    }
    if (!_isFlexible && (_startTime == null || _endTime == null)) {
      _showMessage('Select your working hours or enable flexible hours.');
      return;
    }
    if (!_isFlexible && !_isValidTimeRange()) {
      _showMessage('End time must be later than start time.');
      return;
    }

    final updatedData = widget.onboardingData.copyWith(
      schedule: {
        'availableDays': _selectedDays.toList()..sort(),
        'startTime': _isFlexible ? null : _startTime,
        'endTime': _isFlexible ? null : _endTime,
        'isFlexible': _isFlexible,
        'acceptsUrgentJobs': _acceptsUrgentJobs,
      },
    );

    Navigator.pushNamed(
      context,
      Step5VerifyScreen.routeName,
      arguments: updatedData,
    );
  }

  bool _isValidTimeRange() {
    final start = _timeOptions.indexOf(_startTime ?? '');
    final end = _timeOptions.indexOf(_endTime ?? '');
    return start >= 0 && end >= 0 && end > start;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return WorkerOnboardingShell(
      title: 'Set your availability',
      subtitle:
          'Tell customers when you can work. Better availability data helps us match urgent and scheduled jobs correctly.',
      step: 5,
      totalSteps: 6,
      bottom: FilledButton(
        onPressed: _proceedToNextStep,
        child: const Text('Continue'),
      ),
      children: [
        WorkerOnboardingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Working days',
                      style: TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _selectEveryDay,
                    child: const Text('Every day'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _days.map(_buildDayChip).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        WorkerOnboardingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isFlexible,
                onChanged: (value) {
                  setState(() {
                    _isFlexible = value;
                    if (_isFlexible) {
                      _startTime = null;
                      _endTime = null;
                    }
                  });
                },
                title: const Text(
                  'Flexible hours',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Use this if your hours change by day or depend on job type.',
                ),
              ),
              if (!_isFlexible) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeDropdown(
                        label: 'Start time',
                        value: _startTime,
                        onChanged: (val) => setState(() => _startTime = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTimeDropdown(
                        label: 'End time',
                        value: _endTime,
                        onChanged: (val) => setState(() => _endTime = val),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        WorkerOnboardingCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _acceptsUrgentJobs,
            onChanged: (value) => setState(() => _acceptsUrgentJobs = value),
            title: const Text(
              'Available for urgent jobs',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Urgent availability can improve matching for emergency service requests.',
            ),
            secondary: const Icon(
              Icons.flash_on_outlined,
              color: WorkableDesign.warning,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayChip(String day) {
    final selected = _selectedDays.contains(day);

    return FilterChip(
      selected: selected,
      label: Text(day),
      onSelected: (value) {
        setState(() {
          value ? _selectedDays.add(day) : _selectedDays.remove(day);
        });
      },
      selectedColor: WorkableDesign.accent.withValues(alpha: 0.14),
      checkmarkColor: WorkableDesign.accent,
      side: BorderSide(
        color: selected
            ? WorkableDesign.accent.withValues(alpha: 0.35)
            : WorkableDesign.border,
      ),
      labelStyle: TextStyle(
        color: selected ? WorkableDesign.accent : WorkableDesign.ink,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildTimeDropdown({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: _timeOptions
          .map((time) => DropdownMenuItem(value: time, child: Text(time)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
