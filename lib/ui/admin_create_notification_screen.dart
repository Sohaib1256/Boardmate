import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminCreateNotificationScreen extends StatefulWidget {
  const AdminCreateNotificationScreen({super.key});

  @override
  State<AdminCreateNotificationScreen> createState() => _AdminCreateNotificationScreenState();
}

class _AdminCreateNotificationScreenState extends State<AdminCreateNotificationScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedTargetAudience = 'All';
  String _selectedType = 'Announcement';

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  final List<String> _audiences = [
    'All',
    'Mathematics',
    'Physics',
    'Computer Science',
    'Chemistry',
    'Biology',
    'English',
    'Urdu',
    'Islamiat'
  ];

  final List<String> _types = [
    'Announcement',
    'Discussion',
    'Resource',
    'Quiz'
  ];

  bool _isSubmitting = false;

  Future<void> _submitNotification() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'type': _selectedType,
        'targetAudience': 'All', // as requested in the prompt
        'subject': _selectedTargetAudience, // To support the dynamic filtering
        'readBy': [FirebaseAuth.instance.currentUser?.uid],
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification posted successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting notification: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Notification', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Target Audience Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedTargetAudience,
                decoration: InputDecoration(
                  labelText: 'Target Course',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: _audiences.map((audience) {
                  return DropdownMenuItem(
                    value: audience,
                    child: Text(audience),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTargetAudience = value!;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Notification Type Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Notification Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: _types.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 20),

              // Body Field
              TextFormField(
                controller: _bodyController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Message Body',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Message body is required' : null,
              ),
              const SizedBox(height: 32),

              // Post Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitNotification,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Post Notification',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
