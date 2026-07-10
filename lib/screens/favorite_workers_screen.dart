import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';
import 'worker_profile_screen.dart';

class FavoriteWorkersScreen extends StatefulWidget {
  static const routeName = '/customer/favorite-workers';

  const FavoriteWorkersScreen({super.key});

  @override
  State<FavoriteWorkersScreen> createState() => _FavoriteWorkersScreenState();
}

class _FavoriteWorkersScreenState extends State<FavoriteWorkersScreen> {
  String _searchQuery = '';
  String _selectedSkill = 'All';

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _favoritesRef =>
      FirebaseFirestore.instance
          .collection('customers')
          .doc(_uid)
          .collection('favoriteWorkers');

  Future<void> _removeFavorite(String workerId, String workerName) async {
    HapticFeedback.mediumImpact();
    await _favoritesRef.doc(workerId).delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$workerName removed from favorites'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await _favoritesRef.doc(workerId).set({
              'workerId': workerId,
              'addedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          },
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchWorkers(List<String> ids) async {
    if (ids.isEmpty) return [];

    final docs = await Future.wait(
      ids.map(
        (id) => FirebaseFirestore.instance.collection('workers').doc(id).get(),
      ),
    );

    return docs
        .where((doc) => doc.exists)
        .map((doc) => {'id': doc.id, ...doc.data()!})
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Favorite Workers'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _uid.isEmpty
            ? const WorkableEmptyState(
                icon: LucideIcons.heart,
                title: 'Sign in required',
                message: 'Please log in to view and manage favorite workers.',
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: _buildHeader(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _buildSearchField(),
                  ),
                  Expanded(child: _buildFavoritesList()),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _favoritesRef.snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return WorkablePageHeader(
          title: 'Trusted workers',
          subtitle:
              'Save the people you trust most and book them again without searching from scratch.',
          icon: LucideIcons.heartHandshake,
          trailing: WorkableStatusPill(
            label: '$count saved',
            color: WorkableDesign.accent,
            icon: LucideIcons.heart,
          ),
        );
      },
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (value) => setState(() => _searchQuery = value.trim()),
      decoration: const InputDecoration(
        hintText: 'Search by name, skill, or city',
        prefixIcon: Icon(LucideIcons.search),
      ),
    );
  }

  Widget _buildFavoritesList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _favoritesRef.orderBy('addedAt', descending: true).snapshots(),
      builder: (context, favoriteSnapshot) {
        if (favoriteSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (favoriteSnapshot.hasError) {
          return const WorkableEmptyState(
            icon: LucideIcons.alertTriangle,
            title: 'Could not load favorites',
            message: 'Please check your connection and try again.',
          );
        }

        final favoriteDocs = favoriteSnapshot.data?.docs ?? [];
        if (favoriteDocs.isEmpty) {
          return WorkableEmptyState(
            icon: LucideIcons.heart,
            title: 'No favorite workers yet',
            message:
                'Open a worker profile and tap the favorite action to keep trusted workers here.',
            actionLabel: 'Explore Workers',
            onAction: () => Navigator.pop(context),
          );
        }

        final workerIds = favoriteDocs.map((doc) => doc.id).toList();
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchWorkers(workerIds),
          builder: (context, workersSnapshot) {
            if (workersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (workersSnapshot.hasError) {
              return const WorkableEmptyState(
                icon: LucideIcons.alertTriangle,
                title: 'Worker details unavailable',
                message: 'Some saved workers could not be loaded right now.',
              );
            }

            final workers = _filteredWorkers(workersSnapshot.data ?? []);
            final skills = _availableSkills(workersSnapshot.data ?? []);

            if (workers.isEmpty) {
              return _buildNoResults();
            }

            return Column(
              children: [
                if (skills.length > 1) _buildSkillFilters(skills),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: workers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildWorkerCard(workers[index]);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _filteredWorkers(
    List<Map<String, dynamic>> workers,
  ) {
    final query = _searchQuery.toLowerCase();

    return workers.where((worker) {
      final skills = _workerSkills(worker);
      final searchable = [
        worker['fullName'],
        worker['name'],
        worker['city'],
        ...skills,
      ].whereType<Object>().join(' ').toLowerCase();

      final matchesQuery = query.isEmpty || searchable.contains(query);
      final matchesSkill =
          _selectedSkill == 'All' || skills.contains(_selectedSkill);
      return matchesQuery && matchesSkill;
    }).toList();
  }

  List<String> _availableSkills(List<Map<String, dynamic>> workers) {
    final skills = <String>{'All'};
    for (final worker in workers) {
      skills.addAll(_workerSkills(worker));
    }
    return skills.toList();
  }

  List<String> _workerSkills(Map<String, dynamic> worker) {
    final rawSkills = worker['skills'] ?? worker['services'];
    if (rawSkills is List) {
      return rawSkills.map((skill) => skill.toString()).toList();
    }
    return const [];
  }

  Widget _buildSkillFilters(List<String> skills) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        itemCount: skills.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final skill = skills[index];
          final selected = _selectedSkill == skill;
          return ChoiceChip(
            label: Text(skill),
            selected: selected,
            onSelected: (_) => setState(() => _selectedSkill = skill),
          );
        },
      ),
    );
  }

  Widget _buildWorkerCard(Map<String, dynamic> worker) {
    final workerId = worker['id']?.toString() ?? '';
    final name = (worker['fullName'] ?? worker['name'] ?? 'Worker').toString();
    final city = (worker['city'] ?? '').toString();
    final skills = _workerSkills(worker);
    final rating = _asDouble(worker['averageRating'] ?? worker['rating']);
    final jobs = worker['completedJobsCount'] ?? worker['completedJobs'] ?? 0;
    final isAvailable = worker['isAvailable'] == true;
    final profileImageUrl =
        (worker['profileImageUrl'] ?? worker['profilePhotoUrl']) as String?;
    final wageMap = worker['wageMap'] is Map
        ? Map<String, dynamic>.from(worker['wageMap'] as Map)
        : <String, dynamic>{};
    final primarySkill = skills.isNotEmpty ? skills.first : 'Service provider';
    final primaryPrice = _displayPrice(worker, wageMap, primarySkill);

    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(name, profileImageUrl, isAvailable),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    WorkableInfoRow(
                      icon: LucideIcons.mapPin,
                      text: city.isEmpty
                          ? primarySkill
                          : '$primarySkill in $city',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        WorkableStatusPill(
                          label: isAvailable ? 'Available' : 'Unavailable',
                          color: isAvailable
                              ? WorkableDesign.success
                              : WorkableDesign.muted,
                          icon: isAvailable
                              ? LucideIcons.zap
                              : LucideIcons.clock,
                        ),
                        WorkableStatusPill(
                          label: primaryPrice,
                          color: WorkableDesign.primary,
                          icon: LucideIcons.wallet,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove favorite',
                onPressed: () => _confirmRemove(workerId, name),
                icon: const Icon(LucideIcons.heartOff),
                color: WorkableDesign.danger,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _metric(
                LucideIcons.star,
                rating > 0 ? rating.toStringAsFixed(1) : 'New',
              ),
              const SizedBox(width: 8),
              _metric(LucideIcons.checkCircle, '$jobs jobs'),
            ],
          ),
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills.take(4).map((skill) {
                final wage = wageMap[skill];
                final label = wage == null ? skill : '$skill - Rs $wage';
                return WorkableStatusPill(
                  label: label,
                  color: WorkableDesign.accent,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openWorkerProfile(worker),
                  icon: const Icon(LucideIcons.calendarCheck),
                  label: const Text('Book / View Profile'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Call worker',
                onPressed: () => _callWorker(
                  worker['phone']?.toString() ??
                      worker['phoneNumber']?.toString(),
                ),
                icon: const Icon(LucideIcons.phone),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, String? imageUrl, bool isAvailable) {
    return Stack(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: WorkableDesign.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(WorkableDesign.radius),
            image: imageUrl == null || imageUrl.isEmpty
                ? null
                : DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
          ),
          child: imageUrl == null || imageUrl.isEmpty
              ? Center(
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      color: WorkableDesign.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              : null,
        ),
        if (isAvailable)
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: WorkableDesign.success,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: WorkableDesign.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _metric(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: WorkableDesign.cardDecoration(
          color: WorkableDesign.canvas,
          borderColor: WorkableDesign.border,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: WorkableDesign.muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: WorkableDesign.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return WorkableEmptyState(
      icon: LucideIcons.searchX,
      title: 'No matching workers',
      message: 'Try a different name, city, or service skill.',
      actionLabel: 'Clear Search',
      onAction: () => setState(() {
        _searchQuery = '';
        _selectedSkill = 'All';
      }),
    );
  }

  String _displayPrice(
    Map<String, dynamic> worker,
    Map<String, dynamic> wageMap,
    String primarySkill,
  ) {
    final skillPrice = wageMap[primarySkill];
    if (skillPrice != null) return 'From Rs $skillPrice/hr';

    final pricing = worker['pricing'];
    if (pricing is num) return 'From Rs ${pricing.round()}/hr';
    if (pricing is Map && pricing.isNotEmpty) {
      final first = pricing.values.first;
      return 'From Rs $first/hr';
    }
    final displayPricing = worker['displayPricing']?.toString();
    if (displayPricing != null && displayPricing.isNotEmpty) {
      return displayPricing.replaceAll('₹', 'Rs ');
    }
    return 'Price on booking';
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _openWorkerProfile(Map<String, dynamic> worker) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerProfileScreen(
          workerId: worker['id']?.toString() ?? '',
          name: (worker['fullName'] ?? worker['name'] ?? 'Worker').toString(),
        ),
      ),
    );
  }

  void _callWorker(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Call support/phone integration needed: $phone')),
    );
  }

  Future<void> _confirmRemove(String workerId, String name) async {
    if (workerId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove favorite?'),
        content: Text('$name will be removed from your saved workers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _removeFavorite(workerId, name);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'W';
  }
}
