import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LanguageSelectionScreen extends StatefulWidget {
  static const routeName = '/language-selection';

  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String selectedLanguage = 'en';
  String? downloadingLang;
  bool autoDetect = true;

  final List<Map<String, dynamic>> languages = [
    {
      'code': 'en',
      'name': 'English',
      'nativeName': 'English',
      'flag': '🇺🇸',
      'isDownloaded': true,
      'isPopular': true,
      'region': 'United States',
    },
    {
      'code': 'hi',
      'name': 'Hindi',
      'nativeName': 'हिन्दी',
      'flag': '🇮🇳',
      'isDownloaded': true,
      'isPopular': true,
      'region': 'India',
    },
    {
      'code': 'bn',
      'name': 'Bengali',
      'nativeName': 'বাংলা',
      'flag': '🇧🇩',
      'isDownloaded': false,
      'isPopular': true,
      'region': 'Bangladesh',
    },
    {
      'code': 'ta',
      'name': 'Tamil',
      'nativeName': 'தமிழ்',
      'flag': '🇮🇳',
      'isDownloaded': true,
      'isPopular': true,
      'region': 'India',
    },
    {
      'code': 'te',
      'name': 'Telugu',
      'nativeName': 'తెలుగు',
      'flag': '🇮🇳',
      'isDownloaded': false,
      'isPopular': true,
      'region': 'India',
    },
    {
      'code': 'mr',
      'name': 'Marathi',
      'nativeName': 'मराठी',
      'flag': '🇮🇳',
      'isDownloaded': false,
      'isPopular': false,
      'region': 'India',
    },
    {
      'code': 'gu',
      'name': 'Gujarati',
      'nativeName': 'ગુજરાતી',
      'flag': '🇮🇳',
      'isDownloaded': false,
      'isPopular': false,
      'region': 'India',
    },
    {
      'code': 'kn',
      'name': 'Kannada',
      'nativeName': 'ಕನ್ನಡ',
      'flag': '🇮🇳',
      'isDownloaded': true,
      'isPopular': true,
      'region': 'India',
    },
    {
      'code': 'ml',
      'name': 'Malayalam',
      'nativeName': 'മലയാളം',
      'flag': '🇮🇳',
      'isDownloaded': false,
      'isPopular': false,
      'region': 'India',
    },
    {
      'code': 'pa',
      'name': 'Punjabi',
      'nativeName': 'ਪੰਜਾਬੀ',
      'flag': '🇮🇳',
      'isDownloaded': false,
      'isPopular': false,
      'region': 'India',
    },
    {
      'code': 'ur',
      'name': 'Urdu',
      'nativeName': 'اردو',
      'flag': '🇵🇰',
      'isDownloaded': false,
      'isPopular': false,
      'region': 'Pakistan',
    },
    {
      'code': 'ar',
      'name': 'Arabic',
      'nativeName': 'العربية',
      'flag': '🇸🇦',
      'isDownloaded': false,
      'isPopular': false,
      'region': 'Saudi Arabia',
    },
  ];

  List<Map<String, dynamic>> get filteredLanguages {
    final query = _searchController.text.toLowerCase();
    return languages
        .where(
          (lang) =>
              lang['name'].toLowerCase().contains(query) ||
              lang['nativeName'].toLowerCase().contains(query),
        )
        .toList();
  }

  List<Map<String, dynamic>> get popularLanguages =>
      filteredLanguages.where((lang) => lang['isPopular'] == true).toList();

  List<Map<String, dynamic>> get otherLanguages =>
      filteredLanguages.where((lang) => lang['isPopular'] == false).toList();

  void handleLanguageSelect(String code) {
    setState(() {
      selectedLanguage = code;
    });
  }

  void handleDownload(String code) {
    setState(() => downloadingLang = code);
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        downloadingLang = null;
        final index = languages.indexWhere((lang) => lang['code'] == code);
        if (index != -1) languages[index]['isDownloaded'] = true;
      });
    });
  }

  Widget buildLanguageCard(Map<String, dynamic> lang) {
    final isSelected = selectedLanguage == lang['code'];
    return InkWell(
      onTap: () => handleLanguageSelect(lang['code']),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade200,
            width: isSelected ? 1.8 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(lang['flag'], style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        lang['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.blue[800] : Colors.black,
                        ),
                      ),
                      if (lang['isPopular'])
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            LucideIcons.star,
                            size: 14,
                            color: Colors.amber,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    lang['nativeName'],
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.blue : Colors.grey[600],
                    ),
                  ),
                  Text(
                    lang['region'],
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (!lang['isDownloaded'])
              IconButton(
                icon: downloadingLang == lang['code']
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.download, size: 18),
                onPressed: downloadingLang == lang['code']
                    ? null
                    : () => handleDownload(lang['code']),
              ),
            if (isSelected)
              const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.blue,
                child: Icon(LucideIcons.check, color: Colors.white, size: 12),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Language'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Current Language
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.indigo],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: const [
                      Icon(LucideIcons.globe, color: Colors.white),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Language',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'English (United States)',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '"Find skilled workers near you"',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(LucideIcons.search),
                hintText: 'Search languages...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Auto-detect
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.smartphone),
                    title: const Text('Auto-detect'),
                    subtitle: const Text('Use device language'),
                    trailing: Switch(
                      value: autoDetect,
                      onChanged: (val) => setState(() => autoDetect = val),
                    ),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(LucideIcons.volume2),
                    title: Text('Voice Language'),
                    subtitle: Text('For voice interactions'),
                    trailing: Text(
                      'Same as UI',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Popular Languages
            if (popularLanguages.isNotEmpty) ...[
              Row(
                children: const [
                  Icon(LucideIcons.star, color: Colors.amber, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Popular Languages',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...popularLanguages.map(buildLanguageCard),
              const SizedBox(height: 20),
            ],

            // All Other Languages
            if (otherLanguages.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'All Languages',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
              ...otherLanguages.map(buildLanguageCard),
            ],

            if (filteredLanguages.isEmpty)
              Column(
                children: const [
                  SizedBox(height: 40),
                  Icon(LucideIcons.globe, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No languages found'),
                  SizedBox(height: 4),
                  Text(
                    'Try adjusting your search',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),

            const SizedBox(height: 30),

            // Info Alert
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                border: Border.all(color: Colors.amber.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(LucideIcons.refreshCw, color: Colors.amber),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'App will restart to apply the new language. Your data will be preserved.',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Apply Button
            ElevatedButton(
              onPressed: selectedLanguage == 'en' ? null : () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Apply Language Change',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),
            const Text(
              'Downloaded languages work offline • Total size: 45 MB',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
