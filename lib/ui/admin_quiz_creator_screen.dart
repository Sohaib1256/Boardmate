import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminQuizCreatorScreen extends StatefulWidget {
  const AdminQuizCreatorScreen({super.key});

  @override
  State<AdminQuizCreatorScreen> createState() => _AdminQuizCreatorScreenState();
}

class _AdminQuizCreatorScreenState extends State<AdminQuizCreatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  // ── Section 1: Quiz Details ──
  final String _classLevel = '9';
  String _subject = 'Mathematics';
  final _topicController = TextEditingController();

  // ── Section 2: Question Details ──
  final _questionController = TextEditingController();
  final _optionAController = TextEditingController();
  final _optionBController = TextEditingController();
  final _optionCController = TextEditingController();
  final _optionDController = TextEditingController();
  String _correctAnswer = 'A';

  bool _isSaving = false;
  int _questionsAdded = 0; // Track count for UX feedback

  // ── Dropdown options ──
  static const _subjects = [
    'Mathematics',
    'Physics',
    'Urdu',
    'Islamiat',
    'English',
    'Computer Science',
    'Chemistry',
    'Biology'
  ];
  static const _answerChoices = ['A', 'B', 'C', 'D'];

  @override
  void dispose() {
    _topicController.dispose();
    _questionController.dispose();
    _optionAController.dispose();
    _optionBController.dispose();
    _optionCController.dispose();
    _optionDController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────
  // Get the correct option text based on the selected letter
  // ──────────────────────────────────────────────────────────────
  String _getCorrectOptionText() {
    switch (_correctAnswer) {
      case 'A':
        return _optionAController.text.trim();
      case 'B':
        return _optionBController.text.trim();
      case 'C':
        return _optionCController.text.trim();
      case 'D':
        return _optionDController.text.trim();
      default:
        return _optionAController.text.trim();
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Find or create parent quiz document, then add question
  // ──────────────────────────────────────────────────────────────
  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('You must be logged in.');

      final topic = _topicController.text.trim();

      // ── Step 1: Find or create the parent quiz document ──
      final querySnapshot = await _firestore
          .collection('quizzes')
          .where('classLevel', isEqualTo: _classLevel)
          .where('subject', isEqualTo: _subject)
          .where('topic', isEqualTo: topic)
          .limit(1)
          .get();

      String quizDocId;

      if (querySnapshot.docs.isEmpty) {
        // Create a new quiz document
        final docRef = await _firestore.collection('quizzes').add({
          'classLevel': _classLevel,
          'subject': _subject,
          'topic': topic,
          'createdBy': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        quizDocId = docRef.id;
      } else {
        // Use existing quiz
        quizDocId = querySnapshot.docs.first.id;
      }

      // ── Step 2: Add the question to the subcollection ──
      await _firestore
          .collection('quizzes')
          .doc(quizDocId)
          .collection('questions')
          .add({
        'questionText': _questionController.text.trim(),
        'options': [
          _optionAController.text.trim(),
          _optionBController.text.trim(),
          _optionCController.text.trim(),
          _optionDController.text.trim(),
        ],
        'correctAnswer': _getCorrectOptionText(),
      });

      // ── Step 3: Clear question fields only, keep quiz details ──
      _questionController.clear();
      _optionAController.clear();
      _optionBController.clear();
      _optionCController.clear();
      _optionDController.clear();
      setState(() {
        _correctAnswer = 'A';
        _questionsAdded++;
      });

      _showSnackBar('Question Added! ($_questionsAdded so far for this topic)');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Quiz Questions'),
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
            stops: [0.0, 0.25],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // ── Header ──
                  const Icon(Icons.quiz_rounded,
                      size: 48, color: Colors.white70),
                  const SizedBox(height: 8),
                  Text(
                    _questionsAdded > 0
                        ? '$_questionsAdded question${_questionsAdded == 1 ? '' : 's'} added'
                        : 'Create MCQ questions for students',
                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 20),

                  // ═══════════════════════════════════════════════
                  // SECTION 1: Quiz Details
                  // ═══════════════════════════════════════════════
                  _buildSectionCard(
                    title: 'Quiz Details',
                    icon: Icons.folder_open_rounded,
                    children: [
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
                        onChanged: (v) {
                          setState(() {
                            _subject = v!;
                            _questionsAdded = 0;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── Topic Name ──
                      TextFormField(
                        controller: _topicController,
                        decoration: _inputDecoration(
                          label: 'Topic Name',
                          icon: Icons.topic_rounded,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Topic is required'
                            : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ═══════════════════════════════════════════════
                  // SECTION 2: Question Details
                  // ═══════════════════════════════════════════════
                  _buildSectionCard(
                    title: 'Question',
                    icon: Icons.help_outline_rounded,
                    children: [
                      // ── Question Text ──
                      TextFormField(
                        controller: _questionController,
                        maxLines: 3,
                        decoration: _inputDecoration(
                          label: 'Question Text',
                          icon: Icons.edit_note_rounded,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Question is required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Options A & B ──
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _optionAController,
                              decoration: _optionDecoration('A'),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _optionBController,
                              decoration: _optionDecoration('B'),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Options C & D ──
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _optionCController,
                              decoration: _optionDecoration('C'),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _optionDController,
                              decoration: _optionDecoration('D'),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Correct Answer Dropdown ──
                      DropdownButtonFormField<String>(
                        initialValue: _correctAnswer,
                        decoration: _inputDecoration(
                          label: 'Correct Answer',
                          icon: Icons.check_circle_outline_rounded,
                        ),
                        items: _answerChoices
                            .map((a) => DropdownMenuItem(
                                  value: a,
                                  child: Text('Option $a'),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _correctAnswer = v!),
                      ),
                      const SizedBox(height: 24),

                      // ── Save Button / Progress ──
                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: _isSaving
                            ? const Center(
                                child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                                onPressed: _saveQuestion,
                                icon:
                                    const Icon(Icons.save_rounded),
                                label: const Text(
                                  'Save Question',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF1A237E),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Section card wrapper ──
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF1A237E), size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ── Option-specific decoration with letter prefix ──
  InputDecoration _optionDecoration(String letter) {
    return InputDecoration(
      labelText: 'Option $letter',
      prefixIcon: CircleAvatar(
        radius: 14,
        backgroundColor: const Color(0xFF1A237E),
        child: Text(letter,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
