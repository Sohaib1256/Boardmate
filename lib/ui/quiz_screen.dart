import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'design_course_app_theme.dart';
import 'quiz_result_screen.dart';

class QuizScreen extends StatefulWidget {
  final String sessionId;
  final bool isSandbox;

  const QuizScreen({super.key, required this.sessionId, this.isSandbox = false});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Loading & Data ──
  bool _isLoading = true;
  String _subject = '';
  List<dynamic> _questions = [];
  int _totalMarks = 0;

  // ── Progress ──
  int _currentQuestionIndex = 0;
  double _totalEarnedMarks = 0;

  // ── Instant Feedback ──
  int? _selectedIndex;
  bool _hasAnsweredCurrent = false;

  // ── Timer ──
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _fetchQuizData();
  }

  Future<void> _fetchQuizData() async {
    if (widget.isSandbox) {
      setState(() {
        _subject = 'Practice Quiz';
        _questions = [
          {
            'text': 'What is the capital of Pakistan?',
            'options': ['Lahore', 'Karachi', 'Islamabad', 'Peshawar'],
            'correctIndex': 2,
            'marks': 1,
          },
          {
            'text': 'Which of the following is a scalar quantity?',
            'options': ['Velocity', 'Force', 'Speed', 'Acceleration'],
            'correctIndex': 2,
            'marks': 1,
          },
          {
            'text': 'What is the chemical formula for water?',
            'options': ['CO2', 'H2O', 'NaCl', 'O2'],
            'correctIndex': 1,
            'marks': 1,
          }
        ];
        _totalMarks = 3;
        _remainingSeconds = 5 * 60;
        _isLoading = false;
      });
      _startTimer();
      return;
    }

    try {
      final doc = await _firestore
          .collection('quiz_sessions')
          .doc(widget.sessionId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final int timeLimitMinutes = (data['timeLimitMinutes'] ?? 0) as int;

        setState(() {
          _subject = data['subject'] ?? 'Quiz';
          _questions = data['questions'] ?? [];
          _totalMarks = (data['totalMarks'] ?? _questions.length) as int;
          _remainingSeconds = timeLimitMinutes * 60;
          _isLoading = false;
        });

        _startTimer();
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        _submitQuiz(); // Auto-submit on timer expiry
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Called when student taps an option ──
  void _handleOptionTap(int index) {
    if (_hasAnsweredCurrent) return; // Lock further selections

    final currentQuestion = _questions[_currentQuestionIndex];
    final int correctIndex = currentQuestion['correctAnswerIndex'] ?? 0;
    final double pointsPerQuestion =
        _questions.isEmpty ? 0 : _totalMarks / _questions.length;

    setState(() {
      _selectedIndex = index;
      _hasAnsweredCurrent = true;
      if (index == correctIndex) {
        _totalEarnedMarks += pointsPerQuestion;
      }
    });
  }

  // ── Called when student presses Next / Submit ──
  void _handleNext() {
    if (!_hasAnsweredCurrent) return;

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedIndex = null;
        _hasAnsweredCurrent = false;
      });
    } else {
      _submitQuiz();
    }
  }

  Future<void> _submitQuiz() async {
    _timer?.cancel();
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final double percentage = _totalMarks == 0 ? 0 : (_totalEarnedMarks / _totalMarks * 100);

    if (widget.isSandbox) {
      Navigator.pop(context, percentage);
      return;
    }

    try {
      final payload = {
        'userId': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        'quizId': widget.sessionId,
        'subject': _subject,
        'topic': 'General',
        'earnedMarks': _totalEarnedMarks,
        'totalMarks': _totalMarks,
        'percentage': percentage,
        'completedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('student_results').add(payload);

      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'Quiz Graded: $_subject',
        'body': 'You scored ${_totalEarnedMarks.toStringAsFixed(1)} out of $_totalMarks.',
        'type': 'Score',
        'targetAudience': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        'subject': _subject,
        'readBy': [FirebaseAuth.instance.currentUser?.uid],
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to save completed quiz results: $e');
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          earnedMarks: _totalEarnedMarks,
          totalMarks: _totalMarks,
        ),
      ),
    );
  }

  // ── Option tile colour logic ──
  Color _tileColor(int index, int correctIndex) {
    if (!_hasAnsweredCurrent) {
      return index == _selectedIndex
          ? DesignCourseAppTheme.nearlyBlue.withValues(alpha: 0.08)
          : Colors.white;
    }
    if (index == correctIndex) return Colors.green.shade50;
    if (index == _selectedIndex) return Colors.red.shade50;
    return Colors.white;
  }

  Color _tileBorderColor(int index, int correctIndex) {
    if (!_hasAnsweredCurrent) {
      return index == _selectedIndex
          ? DesignCourseAppTheme.nearlyBlue
          : Colors.grey.shade300;
    }
    if (index == correctIndex) return Colors.green;
    if (index == _selectedIndex) return Colors.red;
    return Colors.grey.shade300;
  }

  IconData _trailingIcon(int index, int correctIndex) {
    if (!_hasAnsweredCurrent) {
      return index == _selectedIndex
          ? Icons.radio_button_checked
          : Icons.radio_button_unchecked;
    }
    if (index == correctIndex) return Icons.check_circle_rounded;
    if (index == _selectedIndex) return Icons.cancel_rounded;
    return Icons.radio_button_unchecked;
  }

  Color _trailingIconColor(int index, int correctIndex) {
    if (!_hasAnsweredCurrent) {
      return index == _selectedIndex
          ? DesignCourseAppTheme.nearlyBlue
          : Colors.grey;
    }
    if (index == correctIndex) return Colors.green;
    if (index == _selectedIndex) return Colors.red;
    return Colors.grey.shade300;
  }

  String get _formattedTime {
    final minutes =
        (_remainingSeconds / 60).floor().toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('No questions found for this quiz.')),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final String questionText = currentQuestion['questionText'] ?? '';
    final List<dynamic> options = currentQuestion['options'] ?? [];
    final int correctIndex = currentQuestion['correctAnswerIndex'] ?? 0;
    final bool isLastQuestion =
        _currentQuestionIndex == _questions.length - 1;

    // ── Pulse timer red in last 30 seconds ──
    final bool isUrgent = _remainingSeconds <= 30;

    return Scaffold(
      backgroundColor: DesignCourseAppTheme.nearlyWhite,
      appBar: AppBar(
        title: Text('$_subject Quiz',
            style:
                const TextStyle(color: DesignCourseAppTheme.nearlyWhite)),
        backgroundColor: DesignCourseAppTheme.nearlyBlue,
        iconTheme:
            const IconThemeData(color: DesignCourseAppTheme.nearlyWhite),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.timer,
                    color: isUrgent ? Colors.redAccent : Colors.white),
                const SizedBox(width: 4),
                Text(
                  _formattedTime,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isUrgent ? Colors.redAccent : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Progress row ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Score: ${_totalEarnedMarks.toStringAsFixed(1)} / $_totalMarks',
                    style: const TextStyle(
                      fontSize: 14,
                      color: DesignCourseAppTheme.nearlyBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_currentQuestionIndex + 1) / _questions.length,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(
                    DesignCourseAppTheme.nearlyBlue),
              ),
              const SizedBox(height: 28),

              // ── Question Text ──
              Text(
                questionText,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: DesignCourseAppTheme.darkerText,
                ),
              ),
              const SizedBox(height: 24),

              // ── Options ──
              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: InkWell(
                        onTap: () => _handleOptionTap(index),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            color: _tileColor(index, correctIndex),
                            border: Border.all(
                              color: _tileBorderColor(index, correctIndex),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _trailingIcon(index, correctIndex),
                                color: _trailingIconColor(
                                    index, correctIndex),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  options[index].toString(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _hasAnsweredCurrent
                                        ? (index == correctIndex
                                            ? Colors.green.shade800
                                            : index == _selectedIndex
                                                ? Colors.red.shade800
                                                : DesignCourseAppTheme
                                                    .darkText)
                                        : (index == _selectedIndex
                                            ? DesignCourseAppTheme
                                                .nearlyBlue
                                            : DesignCourseAppTheme
                                                .darkText),
                                    fontWeight: index == correctIndex &&
                                            _hasAnsweredCurrent
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Next / Submit button — hidden until answered ──
              AnimatedOpacity(
                opacity: _hasAnsweredCurrent ? 1.0 : 0.35,
                duration: const Duration(milliseconds: 300),
                child: ElevatedButton(
                  onPressed: _hasAnsweredCurrent ? _handleNext : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: isLastQuestion
                        ? Colors.green
                        : DesignCourseAppTheme.nearlyBlue,
                    disabledBackgroundColor: Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isLastQuestion ? 'Submit Quiz' : 'Next Question →',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
