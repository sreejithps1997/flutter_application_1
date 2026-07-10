import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/workable_design.dart';

class WorkerPortfolioScreen extends StatefulWidget {
  const WorkerPortfolioScreen({super.key});

  static const routeName = '/worker/portfolio';

  @override
  State<WorkerPortfolioScreen> createState() => _WorkerPortfolioScreenState();
}

class _WorkerPortfolioScreenState extends State<WorkerPortfolioScreen> {
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _pickedImage;
  bool _saving = false;
  String _sampleType = 'Completed work';

  static const _sampleTypes = ['Completed work', 'Before', 'After'];

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 78,
      maxWidth: 1400,
      maxHeight: 1400,
    );
    if (picked == null) return;
    setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _saveItem() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final title = _titleController.text.trim();
    final category = _categoryController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty ||
        category.isEmpty ||
        description.isEmpty ||
        _pickedImage == null) {
      _showSnack('Add photo, title, service category and description.');
      return;
    }

    setState(() => _saving = true);
    try {
      final workerRef = FirebaseFirestore.instance
          .collection('workers')
          .doc(uid);
      final itemRef = workerRef.collection('portfolio').doc();

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('worker_portfolio')
          .child(uid)
          .child('${itemRef.id}.jpg');

      await storageRef.putFile(
        _pickedImage!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final imageUrl = await storageRef.getDownloadURL();
      final now = FieldValue.serverTimestamp();

      await itemRef.set({
        'imageUrl': imageUrl,
        'storagePath': storageRef.fullPath,
        'title': title,
        'category': category,
        'serviceCategory': category,
        'sampleType': _sampleType,
        'description': description,
        'isVisible': true,
        'createdAt': now,
        'updatedAt': now,
      });

      await _syncPortfolioSummary(workerRef);

      if (!mounted) return;
      setState(() {
        _pickedImage = null;
        _titleController.clear();
        _categoryController.clear();
        _descriptionController.clear();
        _sampleType = 'Completed work';
      });
      _showSnack('Portfolio item added');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Unable to save portfolio item: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteItem(String itemId, String? storagePath) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete portfolio item?'),
        content: const Text(
          'This removes the work sample from your customer profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final workerRef = FirebaseFirestore.instance
          .collection('workers')
          .doc(uid);
      await workerRef.collection('portfolio').doc(itemId).delete();
      if (storagePath != null && storagePath.isNotEmpty) {
        await FirebaseStorage.instance.ref(storagePath).delete();
      }
      await _syncPortfolioSummary(workerRef);
      if (!mounted) return;
      _showSnack('Portfolio item deleted');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Unable to delete item: $e');
    }
  }

  Future<void> _syncPortfolioSummary(
    DocumentReference<Map<String, dynamic>> workerRef,
  ) async {
    final snapshot = await workerRef.collection('portfolio').get();
    final categories = snapshot.docs
        .map((doc) => doc.data()['category']?.toString().trim())
        .where((category) => category != null && category.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    await workerRef.set({
      'portfolioCount': snapshot.docs.length,
      'portfolioCategories': categories,
      'portfolioUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Portfolio'),
        backgroundColor: WorkableDesign.surface,
        foregroundColor: WorkableDesign.ink,
      ),
      body: uid == null
          ? const Center(child: Text('Please log in again.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('workers')
                  .doc(uid)
                  .collection('portfolio')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];

                return ListView(
                  padding: const EdgeInsets.all(WorkableDesign.pagePadding),
                  children: [
                    _PortfolioHeader(count: docs.length),
                    const SizedBox(height: 16),
                    _buildCreatorCard(),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Your Work',
                            style: TextStyle(
                              color: WorkableDesign.ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _CountPill(count: docs.length),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const _LoadingPortfolio()
                    else if (snapshot.hasError)
                      _ErrorPortfolio(error: snapshot.error.toString())
                    else if (docs.isEmpty)
                      const _EmptyPortfolio()
                    else
                      ...docs.map((doc) {
                        final data = doc.data();
                        return _PortfolioItemCard(
                          data: data,
                          onDelete: () => _deleteItem(
                            doc.id,
                            data['storagePath']?.toString(),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildCreatorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WorkableDesign.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Work Sample',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Show customers real completed work to increase booking trust.',
            style: TextStyle(color: WorkableDesign.muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(WorkableDesign.radius),
            child: Container(
              height: 176,
              width: double.infinity,
              decoration: BoxDecoration(
                color: WorkableDesign.canvas,
                borderRadius: BorderRadius.circular(WorkableDesign.radius),
                border: Border.all(color: WorkableDesign.border),
                image: _pickedImage == null
                    ? null
                    : DecorationImage(
                        image: FileImage(_pickedImage!),
                        fit: BoxFit.cover,
                      ),
              ),
              child: _pickedImage == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 38,
                          color: WorkableDesign.muted,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap to choose photo',
                          style: TextStyle(
                            color: WorkableDesign.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Use clear photos of real completed work',
                          style: TextStyle(color: WorkableDesign.muted),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Kitchen sink repair, wall painting...',
              prefixIcon: Icon(Icons.title_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _categoryController,
            decoration: const InputDecoration(
              labelText: 'Service category',
              hintText: 'Plumbing, Cleaning, Painting...',
              prefixIcon: Icon(Icons.category_outlined),
            ),
          ),
          const SizedBox(height: 12),
          _buildSampleTypeSelector(),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'What problem did you solve?',
              prefixIcon: Icon(Icons.notes_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _saveItem,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_saving ? 'Uploading...' : 'Add to Portfolio'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _sampleTypes.map((type) {
        return ChoiceChip(
          label: Text(type),
          selected: _sampleType == type,
          onSelected: (_) => setState(() => _sampleType = type),
          selectedColor: WorkableDesign.primary.withValues(alpha: 0.12),
          labelStyle: TextStyle(
            color: _sampleType == type
                ? WorkableDesign.primary
                : WorkableDesign.ink,
            fontWeight: FontWeight.w700,
          ),
          side: BorderSide(
            color: _sampleType == type
                ? WorkableDesign.primary
                : WorkableDesign.border,
          ),
        );
      }).toList(),
    );
  }
}

class _PortfolioHeader extends StatelessWidget {
  const _PortfolioHeader({required this.count});

  final int count;

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
            child: const Icon(
              Icons.photo_library_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Proof builds trust',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == 0
                      ? 'Add your first work sample so customers can judge quality before booking.'
                      : '$count work ${count == 1 ? 'sample' : 'samples'} visible on your worker profile.',
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

class _PortfolioItemCard extends StatelessWidget {
  const _PortfolioItemCard({required this.data, required this.onDelete});

  final Map<String, dynamic> data;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final title = data['title']?.toString() ?? 'Work sample';
    final category =
        data['category']?.toString() ??
        data['serviceCategory']?.toString() ??
        'Service';
    final sampleType = data['sampleType']?.toString() ?? 'Completed work';
    final description = data['description']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: WorkableDesign.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(WorkableDesign.radius),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: WorkableDesign.canvas,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: _TypePill(label: sampleType),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          const SizedBox(height: 5),
                          Text(
                            category,
                            style: const TextStyle(
                              color: WorkableDesign.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete sample',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      color: WorkableDesign.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: WorkableDesign.ink.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: WorkableDesign.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: WorkableDesign.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LoadingPortfolio extends StatelessWidget {
  const _LoadingPortfolio();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: WorkableDesign.cardDecoration(),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorPortfolio extends StatelessWidget {
  const _ErrorPortfolio({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: WorkableDesign.cardDecoration(
        borderColor: WorkableDesign.danger.withValues(alpha: 0.24),
      ),
      child: Text(
        'Unable to load portfolio: $error',
        style: const TextStyle(color: WorkableDesign.danger),
      ),
    );
  }
}

class _EmptyPortfolio extends StatelessWidget {
  const _EmptyPortfolio();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: WorkableDesign.cardDecoration(),
      child: const Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 38,
            color: WorkableDesign.muted,
          ),
          SizedBox(height: 8),
          Text(
            'No work samples yet',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Add photos of completed work so customers can trust your quality.',
            textAlign: TextAlign.center,
            style: TextStyle(color: WorkableDesign.muted),
          ),
        ],
      ),
    );
  }
}
