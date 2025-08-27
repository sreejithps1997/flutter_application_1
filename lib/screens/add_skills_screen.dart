import 'package:flutter/material.dart';

class AddSkillsScreen extends StatefulWidget {
  static const routeName = '/add-skills'; // ✅ Added for routing support

  const AddSkillsScreen({super.key}); // ✅ Added const constructor

  @override
  State<AddSkillsScreen> createState() => _AddSkillsScreenState();
}

class _AddSkillsScreenState extends State<AddSkillsScreen> {
  final _skillController = TextEditingController();
  List<String> skills = [];

  void _addSkill() {
    final newSkill = _skillController.text.trim();
    if (newSkill.isNotEmpty && !skills.contains(newSkill)) {
      setState(() {
        skills.add(newSkill);
        _skillController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Skill is empty or already added")),
      );
    }
  }

  void _removeSkill(String skill) {
    setState(() => skills.remove(skill));
  }

  @override
  void dispose() {
    _skillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Skills"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _skillController,
              decoration: InputDecoration(
                labelText: "Enter a skill",
                suffixIcon: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: _addSkill,
                ),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Your Skills:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            SizedBox(height: 12),
            Expanded(
              child: skills.isEmpty
                  ? Center(child: Text("No skills added yet"))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: skills.map((skill) {
                        return Chip(
                          label: Text(skill),
                          backgroundColor: Colors.deepPurple.shade100,
                          deleteIcon: Icon(Icons.close),
                          onDeleted: () => _removeSkill(skill),
                        );
                      }).toList(),
                    ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, skills),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  "Save Skills",
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
