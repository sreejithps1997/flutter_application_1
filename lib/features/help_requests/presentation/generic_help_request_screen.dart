import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/workable_design.dart';
import '../../../screens/address_management_screen.dart';
import '../domain/help_request_draft.dart';
import '../domain/help_request_prefill.dart';
import 'customer_help_request_detail_screen.dart';
import 'help_request_providers.dart';

class GenericHelpRequestScreen extends ConsumerStatefulWidget {
  const GenericHelpRequestScreen({super.key});

  static const routeName = '/customer/help-request';

  @override
  ConsumerState<GenericHelpRequestScreen> createState() =>
      _GenericHelpRequestScreenState();
}

class _GenericHelpRequestScreenState
    extends ConsumerState<GenericHelpRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _budgetController = TextEditingController();

  String _requestType = 'General help';
  String _urgency = 'Normal';
  bool _saving = false;
  bool _prefillApplied = false;
  String _source = 'customer_manual';
  Map<String, dynamic> _sourceMetadata = const {};
  HelpRequestPrefill? _smartPrefill;
  Map<String, dynamic>? _selectedAddress;

  static const _types = [
    'General help',
    'Pickup',
    'Drop',
    'Delivery',
    'Urgent help',
    'Elder support',
  ];

  static const _urgencies = ['Normal', 'Today', 'Urgent'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefillApplied) return;
    _prefillApplied = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is HelpRequestPrefill) {
      _applyPrefill(args);
    }
  }

  void _applyPrefill(HelpRequestPrefill prefill) {
    _smartPrefill = prefill;
    _source = prefill.source;
    _sourceMetadata = prefill.toMetadata();
    _requestType = prefill.requestType;
    _urgency = _urgencies.contains(prefill.normalizedUrgency)
        ? prefill.normalizedUrgency
        : _urgency;
    _titleController.text = prefill.title;
    _descriptionController.text = prefill.description;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _selectAddress() async {
    final selectedAddress = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressManagementScreen(
          isSelectionMode: true,
          selectedAddressId: _selectedAddress?['id']?.toString(),
        ),
      ),
    );

    if (selectedAddress == null || !mounted) return;
    setState(() {
      _selectedAddress = selectedAddress;
      _pickupController.text = _formatAddress(selectedAddress);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      initialDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _dateController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _timeController.text = picked.format(context));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final draft = HelpRequestDraft(
        requestType: _requestType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        pickupAddress: _pickupController.text.trim(),
        destinationAddress: _destinationController.text.trim(),
        urgency: _urgency,
        preferredDate: _dateController.text.trim(),
        preferredTime: _timeController.text.trim(),
        budget: double.tryParse(_budgetController.text.trim()),
        pickupLocation: _addressGeoPoint(_selectedAddress),
        selectedAddress: _selectedAddress,
        source: _source,
        sourceMetadata: _sourceMetadata,
      );

      final requestId = await ref
          .read(helpRequestRepositoryProvider)
          .createHelpRequest(draft);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Help request created')));
      Navigator.pushReplacementNamed(
        context,
        CustomerHelpRequestDetailScreen.routeName,
        arguments: {'requestId': requestId},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to create request: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatAddress(Map<String, dynamic> address) {
    return [
          address['address'],
          address['area'],
          address['landmark'],
          address['pincode'],
        ]
        .where((part) {
          final text = part?.toString().trim();
          return text != null && text.isNotEmpty;
        })
        .join(', ');
  }

  GeoPoint? _addressGeoPoint(Map<String, dynamic>? address) {
    if (address == null) return null;
    final location = address['location'];
    if (location is GeoPoint) return location;
    final lat = _asDouble(address['latitude']);
    final lng = _asDouble(address['longitude']);
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return GeoPoint(lat, lng);
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  bool get _needsDestination {
    return _requestType == 'Pickup' ||
        _requestType == 'Drop' ||
        _requestType == 'Delivery';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Request Help'),
        backgroundColor: WorkableDesign.surface,
        foregroundColor: WorkableDesign.ink,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: WorkableDesign.surface,
            border: Border(top: BorderSide(color: WorkableDesign.border)),
          ),
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_saving ? 'Creating...' : 'Create Help Request'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _HeaderCard(urgency: _urgency, source: _source),
            if (_smartPrefill != null) ...[
              const SizedBox(height: 16),
              _SmartBookingPlanCard(prefill: _smartPrefill!),
            ],
            const SizedBox(height: 16),
            _SectionCard(
              title: 'What help do you need?',
              subtitle:
                  'This is for pickup, drop, delivery, urgent help, or any local assistance.',
              icon: Icons.volunteer_activism_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((type) {
                      return ChoiceChip(
                        label: Text(type),
                        selected: _requestType == type,
                        onSelected: (_) => setState(() => _requestType = type),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _titleController,
                    label: 'Short title',
                    hint: 'Pick up parcel from town',
                    icon: Icons.title_outlined,
                  ),
                  _field(
                    controller: _descriptionController,
                    label: 'Describe the help needed',
                    hint: 'What exactly should the helper do?',
                    icon: Icons.notes_outlined,
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Location and time',
              subtitle: 'Helpers need a clear starting point and time window.',
              icon: Icons.location_on_outlined,
              child: Column(
                children: [
                  _field(
                    controller: _pickupController,
                    label: 'Pickup / help location',
                    hint: 'Choose saved address or type manually',
                    icon: Icons.my_location_outlined,
                    suffix: TextButton(
                      onPressed: _selectAddress,
                      child: const Text('Saved'),
                    ),
                  ),
                  if (_needsDestination)
                    _field(
                      controller: _destinationController,
                      label: 'Destination',
                      hint: 'Where should this go?',
                      icon: Icons.flag_outlined,
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _dateController,
                          label: 'Date',
                          hint: 'Select date',
                          icon: Icons.calendar_today_outlined,
                          readOnly: true,
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          controller: _timeController,
                          label: 'Time',
                          hint: 'Select time',
                          icon: Icons.schedule_outlined,
                          readOnly: true,
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Urgency and budget',
              subtitle:
                  'This helps us later rank nearby helpers and fast responders.',
              icon: Icons.speed_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _urgencies.map((urgency) {
                      return ChoiceChip(
                        label: Text(urgency),
                        selected: _urgency == urgency,
                        onSelected: (_) => setState(() => _urgency = urgency),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _budgetController,
                    label: 'Approx budget',
                    hint: 'Optional',
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                    requiredField: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool readOnly = false,
    bool requiredField = true,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        keyboardType: keyboardType,
        onTap: onTap,
        validator: requiredField
            ? (value) {
                if (value == null || value.trim().isEmpty) return 'Required';
                return null;
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixIcon: suffix,
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.urgency, required this.source});

  final String urgency;
  final String source;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WorkableDesign.cardDecoration(color: WorkableDesign.ink),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(WorkableDesign.radius),
            ),
            child: const Icon(Icons.front_hand_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'One request, many possible helpers',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  source == 'smart_booking'
                      ? 'Smart Booking filled the first details. Confirm the location, time and budget before sending.'
                      : urgency == 'Urgent'
                      ? 'Marked urgent. Later this can notify nearby available helpers.'
                      : 'Create the request now. Matching and broadcast can be added next.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartBookingPlanCard extends StatelessWidget {
  const _SmartBookingPlanCard({required this.prefill});

  final HelpRequestPrefill prefill;

  @override
  Widget build(BuildContext context) {
    final questions = prefill.suggestedQuestions;
    final priceRange = prefill.aiPriceRange;
    final safetyNote = prefill.aiSafetyNote;
    final confidence = prefill.aiConfidence;
    final recommendedPath = prefill.aiRecommendedPath;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WorkableDesign.cardDecoration(
        color: WorkableDesign.primary.withValues(alpha: 0.06),
        borderColor: WorkableDesign.primary.withValues(alpha: 0.18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: WorkableDesign.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(WorkableDesign.radius),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: WorkableDesign.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Smart Booking plan',
                      style: TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prefill.aiSummary.isEmpty
                          ? 'Workable prepared this request from your need. Confirm the location, time and budget before sending.'
                          : prefill.aiSummary,
                      style: const TextStyle(
                        color: WorkableDesign.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PlanPill(
                label: prefill.category,
                color: WorkableDesign.primary,
                icon: Icons.category_outlined,
              ),
              _PlanPill(
                label: prefill.normalizedUrgency,
                color: prefill.normalizedUrgency == 'Urgent'
                    ? WorkableDesign.danger
                    : WorkableDesign.success,
                icon: Icons.flash_on_outlined,
              ),
              if (confidence.isNotEmpty)
                _PlanPill(
                  label: '${_titleCase(confidence)} confidence',
                  color: WorkableDesign.warning,
                  icon: Icons.fact_check_outlined,
                ),
              if (recommendedPath.isNotEmpty)
                _PlanPill(
                  label: _pathLabel(recommendedPath),
                  color: WorkableDesign.success,
                  icon: Icons.route_outlined,
                ),
            ],
          ),
          if (priceRange.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PlanInfoRow(
              icon: Icons.currency_rupee,
              text: 'Estimated range: $priceRange',
            ),
          ],
          if (safetyNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            _PlanInfoRow(
              icon: Icons.health_and_safety_outlined,
              text: safetyNote,
            ),
          ],
          if (questions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Confirm these before sending',
              style: TextStyle(
                color: WorkableDesign.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...questions.take(4).map((question) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _PlanInfoRow(
                  icon: Icons.check_circle_outline,
                  text: question,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _pathLabel(String value) {
    switch (value) {
      case 'worker_booking':
        return 'Compare workers';
      case 'emergency':
        return 'Urgent help';
      default:
        return 'Open help request';
    }
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }
}

class _PlanPill extends StatelessWidget {
  const _PlanPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanInfoRow extends StatelessWidget {
  const _PlanInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: WorkableDesign.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: WorkableDesign.muted, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WorkableDesign.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: WorkableDesign.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: WorkableDesign.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
