import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'design_course_app_theme.dart';
import 'quiz_screen.dart';

import '../models/app_user.dart';
import 'admin_create_quiz_screen.dart';

class QuizListScreen extends StatefulWidget {
  final AppUser appUser;
  final String? initialSubject;

  const QuizListScreen({super.key, required this.appUser, this.initialSubject});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  late String _selectedSubject;
  final Map<String, double> _completedQuizzes = {};
  Set<String> _favoriteQuizIds = {};

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.initialSubject ?? 'All';
    if (!widget.appUser.isAdmin) {
      _loadCompletedQuizzes();
    }
    _loadFavorites();
  }

  void _loadCompletedQuizzes() {
    FirebaseFirestore.instance
        .collection('student_results')
        .where('userId', isEqualTo: widget.appUser.uid)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          for (var doc in snapshot.docs) {
            final data = doc.data();
            _completedQuizzes[data['quizId'] as String] =
                (data['earnedMarks'] ?? 0).toDouble();
          }
        });
      }
    });
  }

  void _loadFavorites() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (mounted && doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          _favoriteQuizIds =
              Set<String>.from(data['favoriteQuizzes'] ?? []);
        });
      }
    });
  }

  Future<void> _toggleFavoriteQuiz(String quizId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final isFav = _favoriteQuizIds.contains(quizId);
    // Optimistic update
    setState(() {
      if (isFav) {
        _favoriteQuizIds.remove(quizId);
      } else {
        _favoriteQuizIds.add(quizId);
      }
    });

    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'favoriteQuizzes': isFav
            ? FieldValue.arrayRemove([quizId])
            : FieldValue.arrayUnion([quizId]),
      },
      SetOptions(merge: true),
    );
  }

  final List<String> _filters = [
    'All',
    'Favorites',
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'English',
    'Urdu',
    'Islamiat',
  ];

  void _showStartDialog(
      BuildContext context, Map<String, dynamic> data, String docId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Start Quiz?'),
          content: Text(
              'Subject: ${data['subject']}\nTime Limit: ${data['timeLimitMinutes']} mins\n\nAre you ready? The timer cannot be paused once started.'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignCourseAppTheme.nearlyBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => QuizScreen(sessionId: docId)),
                );
              },
              child: const Text('Start Attempt'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, String docId, String subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quiz?'),
        content: Text(
            'Are you sure you want to permanently delete the $subject quiz?'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('quiz_sessions')
          .doc(docId)
          .delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz deleted successfully.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showingFavorites = _selectedSubject == 'Favorites';

    // Build the base Firestore query (favorites are filtered client-side)
    Query query = FirebaseFirestore.instance
        .collection('quiz_sessions')
        .orderBy('createdAt', descending: true);

    if (!showingFavorites && _selectedSubject != 'All') {
      query = query.where('subject', isEqualTo: _selectedSubject);
    }

    return Scaffold(
      backgroundColor: DesignCourseAppTheme.nearlyWhite,
      appBar: AppBar(
        title: const Text('Available Quizzes',
            style: TextStyle(color: DesignCourseAppTheme.nearlyWhite)),
        backgroundColor: DesignCourseAppTheme.nearlyBlue,
        iconTheme: const IconThemeData(color: DesignCourseAppTheme.nearlyWhite),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Filter Chips Row ──
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final subject = _filters[index];
                final isSelected = _selectedSubject == subject;
                final isFavChip = subject == 'Favorites';
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    avatar: isFavChip
                        ? Icon(
                            isSelected
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: isSelected ? Colors.red : Colors.grey,
                          )
                        : null,
                    label: Text(subject),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedSubject = subject);
                    },
                    selectedColor: isFavChip
                        ? Colors.red.withValues(alpha: 0.15)
                        : DesignCourseAppTheme.nearlyBlue.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? (isFavChip
                              ? Colors.red
                              : DesignCourseAppTheme.nearlyBlue)
                          : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No quizzes available right now.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                // Client-side filter for favorites
                final allDocs = snapshot.data!.docs;
                final docs = showingFavorites
                    ? allDocs
                        .where((d) => _favoriteQuizIds.contains(d.id))
                        .toList()
                    : allDocs;

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_border,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text(
                          'No favourites yet.\nTap ♡ on any quiz to save it here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 16, bottom: 120),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final String subject = data['subject'] ?? 'Unknown Subject';
                    final int totalQuestions = data['totalQuestions'] ?? 0;
                    final int timeLimitMinutes = data['timeLimitMinutes'] ?? 0;
                    final Timestamp? createdAt = data['createdAt'];

                    String dateString = 'Recently';
                    if (createdAt != null) {
                      dateString =
                          DateFormat.yMMMd().format(createdAt.toDate());
                    }

                    final String quizId = docs[index].id;
                    final bool isCompleted =
                        _completedQuizzes.containsKey(quizId);
                    final double score = _completedQuizzes[quizId] ?? 0.0;
                    final bool isFav = _favoriteQuizIds.contains(quizId);

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      color: isCompleted ? Colors.green.shade50 : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isCompleted
                            ? BorderSide(
                                color: Colors.green.shade300, width: 2)
                            : BorderSide.none,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (widget.appUser.isAdmin) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminCreateQuizScreen(
                                  existingQuizId: docs[index].id,
                                  existingQuizData: data,
                                ),
                              ),
                            );
                          } else {
                            _showStartDialog(context, data, docs[index].id);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: DesignCourseAppTheme.nearlyBlue
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.quiz,
                                  color: DesignCourseAppTheme.nearlyBlue,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            subject,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: DesignCourseAppTheme
                                                  .darkerText,
                                            ),
                                          ),
                                        ),
                                        if (isCompleted)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color:
                                                      Colors.green.shade300),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.check_circle,
                                                    color: Colors.green,
                                                    size: 14),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Done: ${score.toInt()}',
                                                  style: TextStyle(
                                                      color: Colors
                                                          .green.shade800,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 4,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                                Icons.format_list_numbered,
                                                size: 16,
                                                color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$totalQuestions Qs',
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 14),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.timer,
                                                size: 16, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$timeLimitMinutes min',
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Added: $dateString',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                    )
                                  ],
                                ),
                              ),
                              // ── Favourite heart button (students only) ──
                              if (!widget.appUser.isAdmin)
                                IconButton(
                                  icon: Icon(
                                    isFav
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color:
                                        isFav ? Colors.red : Colors.grey,
                                  ),
                                  tooltip: isFav
                                      ? 'Remove favourite'
                                      : 'Add to favourites',
                                  onPressed: () =>
                                      _toggleFavoriteQuiz(quizId),
                                ),
                              if (widget.appUser.isAdmin)
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red),
                                  onPressed: () => _confirmDelete(
                                      context, docs[index].id, subject),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.appUser.isAdmin
          ? Padding(
              padding: const EdgeInsets.only(bottom: 90.0),
              child: FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminCreateQuizScreen()),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Quiz'),
                backgroundColor: DesignCourseAppTheme.nearlyBlue,
                foregroundColor: Colors.white,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
