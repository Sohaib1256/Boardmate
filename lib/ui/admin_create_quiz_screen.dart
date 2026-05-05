import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'design_course_app_theme.dart';
import 'dart:convert';

// ─────────────────────────────────────────────────────────────
//  Data Model
// ─────────────────────────────────────────────────────────────
class QuestionModel {
  String questionText = '';
  List<String> options = ['', '', '', ''];
  int correctAnswerIndex = 0;

  Map<String, dynamic> toMap() {
    return {
      'questionText': questionText,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
    };
  }
}

// ─────────────────────────────────────────────────────────────
//  Widget
// ─────────────────────────────────────────────────────────────
class AdminCreateQuizScreen extends StatefulWidget {
  final String? existingQuizId;
  final Map<String, dynamic>? existingQuizData;

  const AdminCreateQuizScreen(
      {super.key, this.existingQuizId, this.existingQuizData});

  @override
  State<AdminCreateQuizScreen> createState() => _AdminCreateQuizScreenState();
}

class _AdminCreateQuizScreenState extends State<AdminCreateQuizScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Controllers ──
  final TextEditingController _timeLimitCtrl = TextEditingController();
  final TextEditingController _totalMarksCtrl = TextEditingController();

  // ── Metadata ──
  String _subject = 'Mathematics';
  final List<String> _subjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'English',
    'Urdu',
    'Islamiat',
  ];

  // ── Questions ──
  List<QuestionModel> _questions = [];
  bool _isSaving = false;
  bool _isParsing = false;

  // ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    if (widget.existingQuizData != null) {
      // ── EDIT MODE: pre-fill from Firestore data ──
      final data = widget.existingQuizData!;
      _subject = data['subject'] ?? 'Mathematics';
      _timeLimitCtrl.text =
          (data['timeLimitMinutes'] ?? '').toString();
      _totalMarksCtrl.text =
          (data['totalMarks'] ?? '').toString();

      final List<dynamic>? existing = data['questions'];
      if (existing != null) {
        _questions = existing.map((qData) {
          final m = QuestionModel();
          m.questionText = qData['questionText'] ?? '';
          m.options =
              List<String>.from(qData['options'] ?? ['', '', '', '']);
          m.correctAnswerIndex = qData['correctAnswerIndex'] ?? 0;
          return m;
        }).toList();
      }
    } else {
      // ── CREATE MODE: start with one blank card ──
      _questions = [QuestionModel()];
    }
  }

  @override
  void dispose() {
    _timeLimitCtrl.dispose();
    _totalMarksCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  //  Snack helper
  // ─────────────────────────────────────────────────────────
  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Encoding artifact sanitizer
  // ─────────────────────────────────────────────────────────
  String _sanitizeEncoding(String raw) {
    return raw
        .replaceAll('Â°', '°')
        .replaceAll('â\u0080\u0099', "'")
        .replaceAll('â\u0080\u009c', '"')
        .replaceAll('â\u0080\u009d', '"')
        .replaceAll('â\u0080\u0093', '–')
        .replaceAll('â\u0080\u0094', '—')
        .replaceAll('Ã©', 'é')
        .replaceAll('Ã¨', 'è')
        .replaceAll('Ã ', 'à')
        .replaceAll('Ã¼', 'ü')
        .replaceAll('Ã¶', 'ö')
        .replaceAll('\u00a0', ' ');
  }

  // ─────────────────────────────────────────────────────────
  //  .txt File Parser  (resilient version)
  // ─────────────────────────────────────────────────────────
  Future<void> _uploadTxtFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        _showSnackBar('Could not read the file. Please try again.');
        return;
      }

      setState(() => _isParsing = true);

      // Step 1: Decode bytes with UTF-8 (allowing malformed) to preserve special characters.
      final rawContent = utf8.decode(bytes, allowMalformed: true);
      final content = rawContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      // Step 2: Flatten to non-empty trimmed lines
      final allLines = content
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      if (allLines.isEmpty) {
        _showSnackBar('The file appears to be empty.');
        setState(() => _isParsing = false);
        return;
      }

      // Step 3: Walk the flat line list and collect question blocks.
      final questionStartRegex = RegExp(r'^\d+\.');
      final optionRegex = RegExp(r'^([A-Da-d]\.)\s*');
      
      final List<QuestionModel> parsed = [];
      List<String> questionLines = [];
      List<String> parsedOptions = [];
      List<String> currentOptionLines = [];
      bool collectingOptions = false;

      void finaliseBlock() {
        if (currentOptionLines.isNotEmpty) {
          parsedOptions.add(currentOptionLines.join(' ').trim());
          currentOptionLines.clear();
        }
        if (questionLines.isEmpty && parsedOptions.isEmpty) {
          collectingOptions = false;
          return;
        }
        while (parsedOptions.length < 4) {
          parsedOptions.add('');
        }
        if (parsedOptions.length > 4) {
          parsedOptions = parsedOptions.sublist(0, 4);
        }
        if (questionLines.isNotEmpty) {
          parsed.add(QuestionModel()
            ..questionText = questionLines.join(' ').trim()
            ..options = List<String>.from(parsedOptions)
            ..correctAnswerIndex = 0);
        }
        questionLines.clear();
        parsedOptions.clear();
        collectingOptions = false;
      }

      for (final line in allLines) {
        if (questionStartRegex.hasMatch(line)) {
          // Start of a new question block
          finaliseBlock();
          questionLines.add(line);
        } else if (optionRegex.hasMatch(line)) {
          // Start of a new option
          collectingOptions = true;
          if (currentOptionLines.isNotEmpty) {
            parsedOptions.add(currentOptionLines.join(' ').trim());
            currentOptionLines.clear();
          }
          currentOptionLines.add(line.replaceFirst(optionRegex, '').trim());
        } else if (collectingOptions) {
          // Wrapped option continuation line.
          currentOptionLines.add(line);
        } else {
          // Skip short all-caps header lines before any question is seen.
          if (parsed.isEmpty && questionLines.isEmpty &&
              line.length < 6 && line == line.toUpperCase()) {
            continue;
          }
          questionLines.add(line);
        }
      }
      finaliseBlock(); // flush last block

      if (parsed.isEmpty) {
        _showSnackBar(
            'No valid question blocks found.\n\n'
            'Expected format:\nQuestion text\nA) Option\nB) Option\nC) Option\nD) Option');
        setState(() => _isParsing = false);
        return;
      }

      setState(() {
        _questions = parsed;
        _isParsing = false;
      });
      _showSnackBar('${parsed.length} questions imported successfully!',
          isError: false);
    } catch (e) {
      setState(() => _isParsing = false);
      _showSnackBar('Error reading file: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  //  Save / Update
  // ─────────────────────────────────────────────────────────
  Future<void> _saveQuiz() async {
    _formKey.currentState!.save();

    if (_timeLimitCtrl.text.trim().isEmpty) {
      _showSnackBar('Error: Please enter a Time Limit.');
      return;
    }
    if (_totalMarksCtrl.text.trim().isEmpty) {
      _showSnackBar('Error: Please enter Total Marks.');
      return;
    }

    final int? timeLimit = int.tryParse(_timeLimitCtrl.text.trim());
    final int? totalMarks = int.tryParse(_totalMarksCtrl.text.trim());

    if (timeLimit == null || timeLimit <= 0) {
      _showSnackBar('Please enter a valid Time Limit (minutes).');
      return;
    }
    if (totalMarks == null || totalMarks <= 0) {
      _showSnackBar('Please enter a valid Total Marks value.');
      return;
    }

    if (_questions.isEmpty) {
      _showSnackBar('Error: Please add at least one question.');
      return;
    }

    for (int i = 0; i < _questions.length; i++) {
      if (_questions[i].questionText.isEmpty) {
        _showSnackBar('Error: Question ${i + 1} is missing the question text.');
        return;
      }
      for (int j = 0; j < _questions[i].options.length; j++) {
        if (_questions[i].options[j].isEmpty) {
          _showSnackBar('Error: Question ${i + 1} is missing an option.');
          return;
        }
      }
    }

    setState(() => _isSaving = true);

    try {
      final List<Map<String, dynamic>> questionsData =
          _questions.map((q) => q.toMap()).toList();

      final payload = {
        'subject': _subject,
        'subject_lowercase': _subject.toLowerCase(), // Normalized for search
        'totalQuestions': _questions.length,
        'timeLimitMinutes': timeLimit,
        'totalMarks': totalMarks,
        'questions': questionsData,
      };

      if (widget.existingQuizId == null) {
        // ── CREATE ──
        payload['createdAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('quiz_sessions').add(payload);

        await _firestore.collection('notifications').add({
          'title': 'New Quiz: $_subject',
          'body': 'A new quiz has been uploaded for $_subject. Please check it out.',
          'type': 'Quiz',
          'targetAudience': 'All',
          'subject': _subject,
          'readBy': [FirebaseAuth.instance.currentUser?.uid],
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // ── UPDATE ──
        await _firestore
            .collection('quiz_sessions')
            .doc(widget.existingQuizId)
            .update(payload);
      }

      if (mounted) {
        _showSnackBar(
          widget.existingQuizId == null
              ? 'Quiz saved successfully!'
              : 'Quiz updated successfully!',
          isError: false,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to save quiz: $e');
        setState(() => _isSaving = false);
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  //  Question Card Builder
  // ─────────────────────────────────────────────────────────
  Widget _buildQuestionCard(int index, QuestionModel question) {
    return Card(
      key: ObjectKey(question),
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header with delete button ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (_questions.length > 1)
                  IconButton(
                    icon:
                        const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Remove question',
                    onPressed: () =>
                        setState(() => _questions.removeAt(index)),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Question Text ──
            TextFormField(
              initialValue: question.questionText,
              decoration: InputDecoration(
                labelText: 'Question Text',
                hintText: 'Enter your question here...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 2,
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              onSaved: (v) => question.questionText = v!.trim(),
            ),
            const SizedBox(height: 12),

            // ── 4 Option Fields ──
            ...List.generate(4, (optIndex) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TextFormField(
                  initialValue: question.options[optIndex],
                  decoration: InputDecoration(
                    labelText: 'Option ${optIndex + 1}',
                    hintText: 'Enter Option ${optIndex + 1}',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  onSaved: (v) =>
                      question.options[optIndex] = v!.trim(),
                ),
              );
            }),
            const SizedBox(height: 8),

            // ── Correct Answer Dropdown ──
            DropdownButtonFormField<int>(
              initialValue: question.correctAnswerIndex,
              decoration: InputDecoration(
                labelText: 'Correct Answer',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.green.shade50,
              ),
              items: List.generate(
                4,
                (i) => DropdownMenuItem(
                    value: i,
                    child: Text('Option ${i + 1}')),
              ),
              onChanged: (v) =>
                  setState(() => question.correctAnswerIndex = v!),
              onSaved: (v) => question.correctAnswerIndex = v!,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.existingQuizId != null;

    return Scaffold(
      backgroundColor: DesignCourseAppTheme.nearlyWhite,
      appBar: AppBar(
        title: Text(
          isEditMode ? 'Edit Quiz Session' : 'Create Quiz Session',
          style:
              const TextStyle(color: DesignCourseAppTheme.nearlyWhite),
        ),
        backgroundColor: DesignCourseAppTheme.nearlyBlue,
        iconTheme:
            const IconThemeData(color: DesignCourseAppTheme.nearlyWhite),
      ),
      body: _isSaving || _isParsing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _isParsing ? 'Parsing file...' : 'Saving quiz...',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ════════════════════════════════════════
                  //  Step 1: Subject Dropdown
                  // ════════════════════════════════════════
                  DropdownButtonFormField<String>(
                    initialValue: _subject,
                    decoration: InputDecoration(
                      labelText: 'Select Subject',
                      prefixIcon: const Icon(Icons.book_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: _subjects
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _subject = v!),
                  ),
                  const SizedBox(height: 16),

                  // ════════════════════════════════════════
                  //  Step 2: Time Limit & Total Marks
                  // ════════════════════════════════════════
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _timeLimitCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Time Limit (mins)',
                            prefixIcon:
                                const Icon(Icons.timer_outlined),
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _totalMarksCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Total Marks',
                            prefixIcon: const Icon(
                                Icons.grade_outlined),
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ════════════════════════════════════════
                  //  Step 3: Upload .txt File Button
                  // ════════════════════════════════════════
                  OutlinedButton.icon(
                    onPressed: _uploadTxtFile,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Upload .txt File'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DesignCourseAppTheme.nearlyBlue,
                      side: BorderSide(
                          color: DesignCourseAppTheme.nearlyBlue,
                          width: 1.5),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  // ── Format hint ──
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Format: Line 1 = Question, Lines 2-5 = Options A–D, blank line between blocks.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),

                  // ── Live question count chip ──
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(
                            Icons.format_list_numbered,
                            size: 16),
                        label: Text(
                            '${_questions.length} question(s) loaded'),
                        backgroundColor:
                            DesignCourseAppTheme.nearlyBlue
                                .withValues(alpha: 0.1),
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  const Divider(),
                  const SizedBox(height: 8),

                  // ════════════════════════════════════════
                  //  Step 4: Question Cards
                  // ════════════════════════════════════════
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      return _buildQuestionCard(
                          index, _questions[index]);
                    },
                  ),

                  // ════════════════════════════════════════
                  //  + Add Question Button
                  // ════════════════════════════════════════
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _questions.add(QuestionModel()));
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('+ Add Question'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(
                          color: Colors.green.shade400, width: 1.5),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),

      // ════════════════════════════════════════
      //  Save / Update FAB
      // ════════════════════════════════════════
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'saveQuizBtn',
        onPressed: _isSaving ? null : _saveQuiz,
        icon: Icon(isEditMode ? Icons.update : Icons.save),
        label: Text(
            isEditMode ? 'Update Quiz Session' : 'Save Quiz Session'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
    );
  }
}
