import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class AdminUploadScreen extends StatefulWidget {
  const AdminUploadScreen({super.key});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends State<AdminUploadScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ──
  final _titleController = TextEditingController();
  final _chapterController = TextEditingController();

  // ── Dropdown state ──
  String _resourceType = 'textbook';
  final String _classLevel = '9';
  String _subject = 'Mathematics';

  // ── File state ──
  PlatformFile? _pickedFile;

  // ── Upload state ──
  bool _isUploading = false;

  // ── Cloudinary credentials ──
  static const String _cloudName = 'djblpxrmp';
  static const String _uploadPreset = 'boardmate_uploads';
  static const String _cloudinaryUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/raw/upload';

  // ── Dropdown options ──
  static const _resourceTypes = ['textbook', 'notes', 'past_paper'];
  static const _subjects = [
    'Mathematics',
    'Physics',
    'Urdu',
    'Islamiat',
    'English',
    'Computer Science',
    'Chemistry',
    'Biology',
  ];

  // ── Pretty labels for resource types ──
  static const _resourceTypeLabels = {
    'textbook': 'Textbook',
    'notes': 'Notes',
    'past_paper': 'Past Paper',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _chapterController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────
  // Pick a file
  // ──────────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        '7z', 'bdoc', 'cdoc', 'ddoc', 'gtar', 'gz', 'gzip',
        'hqx', 'rar', 'sit', 'tar', 'tgz', 'zip',
        'doc', 'docx', 'epub', 'gdoc', 'odt', 'oth', 'ott', 'pdf', 'rtf',
      ],
      withData: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Upload file → Cloudinary, then save metadata → Firestore
  // ──────────────────────────────────────────────────────────────
  Future<void> _upload() async {
    // Validate form
    if (!_formKey.currentState!.validate()) return;

    // Validate file selected
    if (_pickedFile == null) {
      _showSnackBar('Please select a file first.', isError: true);
      return;
    }

    // Validate file path exists on disk
    if (_pickedFile!.path == null) {
      _showSnackBar('Cannot read file path. Please re-select the file.', isError: true);
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('You must be logged in to upload.');

      // ── Step 1: Build Cloudinary multipart request ──
      final uri = Uri.parse(_cloudinaryUrl);
      final request = http.MultipartRequest('POST', uri);

      // Append the unsigned upload preset
      request.fields['upload_preset'] = _uploadPreset;

      // Give the file a clean public_id on Cloudinary
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeTitle = _titleController.text
          .trim()
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final publicId = '${_classLevel}_${_subject}_${safeTitle}_$timestamp'
          .replaceAll(' ', '_');
      request.fields['public_id'] = publicId;

      // Attach the file
      final file = File(_pickedFile!.path!);
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: _pickedFile!.name,
      );
      request.files.add(multipartFile);

      debugPrint('──────────────────────────────────────');
      debugPrint('Cloudinary Upload Starting...');
      debugPrint('Endpoint : $_cloudinaryUrl');
      debugPrint('File     : ${_pickedFile!.name}');
      debugPrint('Public ID: $publicId');
      debugPrint('──────────────────────────────────────');

      // ── Step 2: Send request and await response ──
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('HTTP Status : ${response.statusCode}');
      debugPrint('HTTP Body   : ${response.body}');

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        final msg = error['error']?['message'] ?? 'Unknown Cloudinary error';
        throw Exception('Cloudinary upload failed: $msg');
      }

      // ── Step 3: Parse the secure_url from the JSON response ──
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl = responseData['secure_url'] as String?;

      if (secureUrl == null || secureUrl.isEmpty) {
        throw Exception('Cloudinary returned no URL. Check upload preset settings.');
      }

      debugPrint('Cloudinary secure_url: $secureUrl');

      // ── Step 4: Save metadata to Firestore ──
      final title = _titleController.text.trim();
      await FirebaseFirestore.instance.collection('resources').add({
        'title': title,
        'title_lowercase': title.toLowerCase(), // Normalized for search
        'type': _resourceType,
        'classLevel': _classLevel,
        'subject': _subject,
        'subject_lowercase': _subject.toLowerCase(), // Normalized for search
        'chapter': _chapterController.text.trim(),
        'fileUrl': secureUrl,
        'uploadedBy': user.uid,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'New Resource: $_subject',
        'body': 'New study materials are available for $_subject.',
        'type': 'Resource',
        'targetAudience': 'All',
        'subject': _subject,
        'readBy': [FirebaseAuth.instance.currentUser?.uid],
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('Firestore document created successfully.');

      // ── Step 5: Reset form ──
      _formKey.currentState!.reset();
      _titleController.clear();
      _chapterController.clear();
      setState(() {
        _pickedFile = null;
        _resourceType = 'textbook';
        _subject = 'Mathematics';
      });

      _showSnackBar('Resource uploaded successfully!');
    } on SocketException {
      debugPrint('Upload Error: No internet connection.');
      _showSnackBar('No internet connection. Please check your network.', isError: true);
    } catch (e, stackTrace) {
      debugPrint('Upload Error: $e\n$stackTrace');
      _showSnackBar('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Resource'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              children: [
                // ── Header ──
                const Icon(Icons.cloud_upload_rounded,
                    size: 48, color: Colors.white70),
                const SizedBox(height: 8),
                Text(
                  'Add a new resource to the library',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white60),
                ),
                const SizedBox(height: 20),

                // ── Form Card ──
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Resource Title ──
                          TextFormField(
                            controller: _titleController,
                            decoration: _inputDecoration(
                              label: 'Resource Title',
                              icon: Icons.title_rounded,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Title is required'
                                : null,
                          ),
                          const SizedBox(height: 18),

                          // ── Resource Type ──
                          DropdownButtonFormField<String>(
                            initialValue: _resourceType,
                            decoration: _inputDecoration(
                              label: 'Resource Type',
                              icon: Icons.category_rounded,
                            ),
                            items: _resourceTypes
                                .map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(_resourceTypeLabels[t] ?? t),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _resourceType = v!),
                          ),
                          const SizedBox(height: 18),

                          // ── Subject ──
                          DropdownButtonFormField<String>(
                            initialValue: _subject,
                            decoration: _inputDecoration(
                              label: 'Subject',
                              icon: Icons.menu_book_rounded,
                            ),
                            items: _subjects
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _subject = v!),
                          ),
                          const SizedBox(height: 18),

                          // ── Chapter / Topic ──
                          TextFormField(
                            controller: _chapterController,
                            decoration: _inputDecoration(
                              label: 'Chapter / Topic (optional)',
                              icon: Icons.bookmark_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Pick File Button ──
                          OutlinedButton.icon(
                            onPressed: _isUploading ? null : _pickFile,
                            icon: Icon(
                              _pickedFile != null
                                  ? Icons.check_circle_rounded
                                  : Icons.attach_file_rounded,
                              color: _pickedFile != null
                                  ? Colors.green
                                  : null,
                            ),
                            label: Text(
                              _pickedFile != null
                                  ? _pickedFile!.name
                                  : 'Select File',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                color: _pickedFile != null
                                    ? Colors.green.shade400
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),

                          if (_pickedFile != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${(_pickedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // ── Upload Button / Progress ──
                          SizedBox(
                            height: 52,
                            child: _isUploading
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const LinearProgressIndicator(),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Uploading to Cloudinary...',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600),
                                      ),
                                    ],
                                  )
                                : ElevatedButton.icon(
                                    onPressed: _upload,
                                    icon: const Icon(Icons.cloud_upload_rounded),
                                    label: const Text(
                                      'Upload Resource',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1A237E),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared input decoration ──
  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
