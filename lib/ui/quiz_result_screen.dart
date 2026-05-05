import 'package:flutter/material.dart';
import 'design_course_app_theme.dart';

class QuizResultScreen extends StatelessWidget {
  final double earnedMarks;
  final int totalMarks;

  const QuizResultScreen({
    super.key,
    required this.earnedMarks,
    required this.totalMarks,
  });

  @override
  Widget build(BuildContext context) {
    final double percentage =
        totalMarks == 0 ? 0 : (earnedMarks / totalMarks * 100);
    final bool passed = percentage >= 33;

    // Format earnedMarks: show as int if whole number, else 1 decimal
    final String earnedDisplay = earnedMarks == earnedMarks.roundToDouble()
        ? earnedMarks.toInt().toString()
        : earnedMarks.toStringAsFixed(1);

    return Scaffold(
      backgroundColor: DesignCourseAppTheme.nearlyWhite,
      appBar: AppBar(
        title: const Text('Quiz Results',
            style: TextStyle(color: DesignCourseAppTheme.nearlyWhite)),
        backgroundColor: DesignCourseAppTheme.nearlyBlue,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Trophy / Sad icon ──
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Icon(
                  passed ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                  size: 110,
                  color: passed ? Colors.amber : Colors.grey,
                ),
              ),
              const SizedBox(height: 24),

              // ── Headline ──
              Text(
                passed ? 'Congratulations! 🎉' : 'Keep Practicing!',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: DesignCourseAppTheme.darkerText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // ── Score card ──
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 24, horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'You scored',
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          earnedDisplay,
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            color: passed ? Colors.green : Colors.red,
                          ),
                        ),
                        Text(
                          ' / $totalMarks',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Percentage badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: passed
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: passed ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Feedback message ──
              Text(
                _feedbackMessage(percentage),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 48),

              // ── Back to Home ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignCourseAppTheme.nearlyBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Back to Home',
                      style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _feedbackMessage(double percentage) {
    if (percentage >= 80) return 'A-1 Grade (Outstanding)';
    if (percentage >= 70) return 'A Grade (Excellent)';
    if (percentage >= 60) return 'B Grade (Good)';
    if (percentage >= 50) return 'C Grade (Satisfactory / Fair)';
    if (percentage >= 40) return 'D Grade (Average)';
    if (percentage >= 33) return 'E Grade (Pass)';
    return 'F Grade (Fail)';
  }
}
