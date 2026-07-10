import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../services/app_preferences_service.dart';
import '../widgets/workable_ui.dart';

class LanguageSelectionScreen extends StatefulWidget {
  static const routeName = '/language-selection';

  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  final _searchController = TextEditingController();
  late String _selectedLanguage;
  bool _autoDetect = false;

  static const _languages = [
    _LanguageOption('English (India)', 'English', 'India', true),
    _LanguageOption('Hindi', 'Hindi', 'India', true),
    _LanguageOption('Malayalam', 'Malayalam', 'India', true),
    _LanguageOption('Tamil', 'Tamil', 'India', true),
    _LanguageOption('Telugu', 'Telugu', 'India', true),
    _LanguageOption('Kannada', 'Kannada', 'India', false),
    _LanguageOption('Marathi', 'Marathi', 'India', false),
    _LanguageOption('Bengali', 'Bengali', 'India / Bangladesh', false),
    _LanguageOption('Arabic', 'Arabic', 'Middle East', false),
    _LanguageOption('Urdu', 'Urdu', 'South Asia', false),
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = AppPreferencesService.language;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_LanguageOption> get _filteredLanguages {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _languages;
    return _languages.where((language) {
      return language.name.toLowerCase().contains(query) ||
          language.nativeName.toLowerCase().contains(query) ||
          language.region.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _selectLanguage(String language) async {
    setState(() => _selectedLanguage = language);
    await AppPreferencesService.setLanguage(language);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Language set to $language'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final popular = _filteredLanguages
        .where((language) => language.popular)
        .toList();
    final other = _filteredLanguages
        .where((language) => !language.popular)
        .toList();

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Language')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          children: [
            WorkablePageHeader(
              title: _selectedLanguage,
              subtitle:
                  'Choose the app language for labels, settings, and future voice-assisted help.',
              icon: LucideIcons.languages,
            ),
            const SizedBox(height: 16),
            WorkableSectionCard(
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(LucideIcons.search),
                      labelText: 'Search language',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _autoDetect,
                    onChanged: (value) => setState(() => _autoDetect = value),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use device language when available'),
                    subtitle: const Text(
                      'Fallback remains your selected Workable language.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (popular.isNotEmpty) ...[
              const _SectionTitle('Popular languages'),
              const SizedBox(height: 10),
              ...popular.map(_buildLanguageCard),
              const SizedBox(height: 16),
            ],
            if (other.isNotEmpty) ...[
              const _SectionTitle('More languages'),
              const SizedBox(height: 10),
              ...other.map(_buildLanguageCard),
            ],
            if (_filteredLanguages.isEmpty)
              const WorkableEmptyState(
                icon: LucideIcons.search,
                title: 'No languages found',
                message: 'Try another language name or region.',
              ),
            const SizedBox(height: 16),
            const WorkableSectionCard(
              color: WorkableDesign.surface,
              child: WorkableInfoRow(
                icon: LucideIcons.info,
                text:
                    'Full multi-language translation is planned for global launch. This setting is stored now and will drive localized copy as translations are added.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageCard(_LanguageOption language) {
    final selected = _selectedLanguage == language.name;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WorkableSectionCard(
        color: selected
            ? WorkableDesign.primary.withValues(alpha: 0.06)
            : WorkableDesign.surface,
        borderColor: selected
            ? WorkableDesign.primary.withValues(alpha: 0.26)
            : WorkableDesign.border,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => _selectLanguage(language.name),
          leading: CircleAvatar(
            backgroundColor: WorkableDesign.primary.withValues(alpha: 0.1),
            child: const Icon(
              LucideIcons.languages,
              color: WorkableDesign.primary,
              size: 18,
            ),
          ),
          title: Text(
            language.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text('${language.nativeName} • ${language.region}'),
          trailing: selected
              ? const Icon(
                  LucideIcons.checkCircle,
                  color: WorkableDesign.success,
                )
              : const Icon(LucideIcons.chevronRight),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: WorkableDesign.ink,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _LanguageOption {
  const _LanguageOption(this.name, this.nativeName, this.region, this.popular);

  final String name;
  final String nativeName;
  final String region;
  final bool popular;
}
