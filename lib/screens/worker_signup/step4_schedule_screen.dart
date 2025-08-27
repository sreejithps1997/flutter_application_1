import 'package:flutter/material.dart';
import 'step5_verify_screen.dart';
import '../../models/worker_onboarding_data.dart';

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

  final List<String> _timeOptions = [
    "6:00 AM",
    "7:00 AM",
    "8:00 AM",
    "9:00 AM",
    "10:00 AM",
    "11:00 AM",
    "12:00 PM",
    "1:00 PM",
    "2:00 PM",
    "3:00 PM",
    "4:00 PM",
    "5:00 PM",
    "6:00 PM",
    "7:00 PM",
    "8:00 PM",
    "9:00 PM",
  ];

  void _proceedToNextStep() {
    final isValid = (_startTime != null && _endTime != null) || _isFlexible;

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select working hours or mark as flexible."),
        ),
      );
      return;
    }

    final updatedData = widget.onboardingData.copyWith(
      schedule: {
        'startTime': _startTime,
        'endTime': _endTime,
        'isFlexible': _isFlexible,
      },
    );

    Navigator.pushNamed(
      context,
      Step5VerifyScreen.routeName,
      arguments: updatedData,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Schedule")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(value: 0.8, color: Colors.deepPurple),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _startTime,
                    hint: const Text("Start Time"),
                    items: _timeOptions
                        .map(
                          (time) =>
                              DropdownMenuItem(value: time, child: Text(time)),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _startTime = val),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _endTime,
                    hint: const Text("End Time"),
                    items: _timeOptions
                        .map(
                          (time) =>
                              DropdownMenuItem(value: time, child: Text(time)),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _endTime = val),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              value: _isFlexible,
              onChanged: (val) {
                setState(() {
                  _isFlexible = val ?? false;
                  if (_isFlexible) {
                    _startTime = null;
                    _endTime = null;
                  }
                });
              },
              title: const Text("I'm flexible with my hours"),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _proceedToNextStep,
              child: const Text("Continue"),
            ),
          ],
        ),
      ),
    );
  }
}
