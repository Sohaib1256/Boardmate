import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';
import 'quiz_list_screen.dart';

// ─── Colour palette ──────────────────────────────────────────────────────────
const Color _deepBlue    = Color(0xFF1A237E);
const Color _lightBlue   = Color(0xFF03A9F4);
const Color _orange      = Color(0xFFF57C00);

class _QuizEntry {
  final String name;
  final double score;
  final double total;
  final String date;
  const _QuizEntry(this.name, this.score, this.total, this.date);
}

class _SubjectEntry {
  final String name;
  final List<_QuizEntry> quizzes;
  const _SubjectEntry(this.name, this.quizzes);
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
String _letterGrade(double pct) {
  if (pct >= 80) return 'A-1';
  if (pct >= 70) return 'A';
  if (pct >= 60) return 'B';
  if (pct >= 50) return 'C';
  if (pct >= 40) return 'D';
  if (pct >= 33) return 'E';
  return 'F';
}

Color _scoreColor(double pct) {
  if (pct >= 60) return Colors.green.shade700;
  if (pct >= 33) return Colors.orange.shade700;
  return Colors.red.shade700;
}

Color _scoreBg(double pct) {
  if (pct >= 60) return Colors.green.shade50;
  if (pct >= 33) return Colors.orange.shade50;
  return Colors.red.shade50;
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class ResultsScreen extends StatefulWidget {
  final AppUser appUser;
  const ResultsScreen({super.key, required this.appUser});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  // ── Bridge to QuizListScreen ─────────────────────────────────────────────
  Future<void> _takeQuiz() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizListScreen(appUser: widget.appUser),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'My Progress',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _deepBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('student_results')
            .where('userId', isEqualTo: widget.appUser.uid)
            .orderBy('completedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Something went wrong"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          Map<String, List<_QuizEntry>> grouped = {};
          int count = 0;
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final subject = data['subject'] ?? 'Unknown';
            final topic = data['topic'] ?? 'General';
            final score = (data['earnedMarks'] ?? 0).toDouble();
            final total = (data['totalMarks'] ?? 0).toDouble();
            final timestamp = data['completedAt'] as Timestamp?;
            final dateStr = timestamp != null 
                ? DateFormat.yMMMd().format(timestamp.toDate()) 
                : 'Recently';
            
            grouped.putIfAbsent(subject, () => []);
            grouped[subject]!.add(_QuizEntry(topic, score, total, dateStr));
            count++;
          }
          
          List<_SubjectEntry> subjects = [];
          grouped.forEach((key, value) {
            subjects.add(_SubjectEntry(key, value));
          });

          double totalPct = 0;
          int quizCount = 0;
          for (final s in subjects) {
            for (final q in s.quizzes) {
              double pct = q.total == 0 ? 0 : (q.score / q.total) * 100;
              totalPct += pct;
              quizCount++;
            }
          }
          final pct = quizCount == 0 ? 0.0 : totalPct / quizCount;
          final grade = _letterGrade(pct);

          return Column(
            children: [
              _buildHeader(pct, grade),
              Expanded(
                child: _buildSubjectList(subjects),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_late_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            const Text(
              'No Progress Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _deepBlue,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "You haven't attempted any quizzes. Test your knowledge to see your progress here!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _takeQuiz,
              icon: const Icon(Icons.quiz_outlined),
              label: const Text('Attempt a Quiz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _lightBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header panel ─────────────────────────────────────────────────────────
  Widget _buildHeader(double pct, String grade) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      decoration: const BoxDecoration(
        color: _deepBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          // Overall stats
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Avg Score',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              // Grade badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _orange.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  grade,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Practice quiz button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _takeQuiz,
              icon: const Icon(Icons.quiz_outlined, size: 20),
              label: const Text(
                'Take Quiz',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _lightBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Subject list ──────────────────────────────────────────────────────────
  Widget _buildSubjectList(List<_SubjectEntry> subjects) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      itemCount: subjects.length,
      itemBuilder: (ctx, i) => _buildSubjectTile(subjects[i]),
    );
  }

  Widget _buildSubjectTile(_SubjectEntry subject) {
    double totalPct = 0;
    int quizCount = 0;
    for (final q in subject.quizzes) {
      double pct = q.total == 0 ? 0 : (q.score / q.total) * 100;
      totalPct += pct;
      quizCount++;
    }
    final subPct = quizCount == 0 ? 0.0 : totalPct / quizCount;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _lightBlue, width: 1.2),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        title: Text(
          subject.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: _deepBlue,
            fontSize: 16,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              '${subPct.toStringAsFixed(1)}% • Grade ${_letterGrade(subPct)}',
              style: TextStyle(
                color: _scoreColor(subPct),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: _deepBlue.withValues(alpha: 0.08),
          child: Text(
            _letterGrade(subPct),
            style: TextStyle(
              color: _scoreColor(subPct),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        children: subject.quizzes.map((quiz) {
          final qPct = (quiz.score / quiz.total) * 100;
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: _scoreBg(qPct),
                child: Icon(
                  qPct >= 70 ? Icons.rocket_launch_rounded : Icons.trending_down_rounded,
                  color: _scoreColor(qPct),
                  size: 18,
                ),
              ),
              title: Text(quiz.name, style: const TextStyle(fontSize: 14)),
              subtitle: Text(quiz.date, style: const TextStyle(fontSize: 12)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _scoreBg(qPct),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${quiz.score.toInt()}/${quiz.total.toInt()}',
                  style: TextStyle(
                    color: _scoreColor(qPct),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
