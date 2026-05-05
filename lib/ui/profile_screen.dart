import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import 'login_screen.dart';
import 'results_screen.dart';
import 'admin_create_notification_screen.dart';
import 'admin_create_quiz_screen.dart';
import 'admin_upload_screen.dart';

const Color _deepBlue  = Color(0xFF1A237E);
const Color _lightBlue = Color(0xFF03A9F4);
const Color _orange    = Color(0xFFF57C00);

class ProfileScreen extends StatelessWidget {
  final AppUser appUser;

  const ProfileScreen({super.key, required this.appUser});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = appUser.isAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Fixed header — logout icon lives here, far from nav bar ────
          SafeArea(
            bottom: false,
            child: _buildHeader(isAdmin, context),
          ),

          // ── Fixed content — uses proportional spacing to fit any screen ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: isAdmin
                  ? _AdminContent(appUser: appUser)
                  : _StudentContent(appUser: appUser),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildHeader(bool isAdmin, BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // ── Centred profile info column ────────────────────────────────
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              // Top clearance so avatar does not overlap the icon row
                const SizedBox(height: 30),
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  appUser.displayName.isNotEmpty
                      ? appUser.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                      fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
                const SizedBox(height: 5),
              Text(
                appUser.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                appUser.email,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
                const SizedBox(height: 5),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: isAdmin ? _orange : _lightBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isAdmin ? 'Admin / Teacher' : 'Student',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

          // ── Logout icon — top-right ────────────────────────────────────
          Positioned(
            top: 15,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Logout',
              onPressed: () => _logout(context),
            ),
          ),

          // ── Admin: notification bell — top-left ───────────────────────
          if (isAdmin)
            Positioned(
              top: 15,
              right: 40,
              child: IconButton(
                icon: const Icon(Icons.add_alert_outlined, color: Colors.white),
                tooltip: 'Create Notification',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminCreateNotificationScreen()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Student View ──────────────────────────────────────────────────────────────
class _StudentContent extends StatelessWidget {
  final AppUser appUser;

  const _StudentContent({required this.appUser});

  Future<void> _debugClearMyProgress(BuildContext context) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      
      final snapshot = await FirebaseFirestore.instance
          .collection('student_results')
          .where('userId', isEqualTo: uid)
          .get();
      
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      batch.set(userRef, {'stats': 0}, SetOptions(merge: true));
      await batch.commit();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All past quiz progress cleared!')),
        );
      }
    } catch (e) {
      debugPrint('Error clearing progress: $e');
    }
  }

  Future<void> _confirmClearProgress(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Progress?'),
          content: const Text('Are you sure you want to permanently delete all your quiz history and reset your progress? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true && context.mounted) {
      await _debugClearMyProgress(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info card
        _infoCard(children: [
          _infoRow(Icons.school_rounded, 'Class', '9th Grade'),
          const Divider(height: 1),
          _infoRow(Icons.location_city_rounded, 'Board', 'Sindh Board of Education'),
        ]),

        const Text(
          'Quick Stats',
          style: TextStyle(
            color: _deepBlue,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('student_results')
              .where('userId', isEqualTo: appUser.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text('No quizzes attempted yet.'),
                ),
              );
            }

            int quizzesTaken = 0;
            double totalEarned = 0.0;
            double totalPossible = 0.0;
            
            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              quizzesTaken = snapshot.data!.docs.length;
              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final earned = double.tryParse(data['earnedMarks']?.toString() ?? '0') ?? 0.0;
                final possible = double.tryParse(data['totalMarks']?.toString() ?? '0') ?? 0.0;
                totalEarned += earned;
                totalPossible += possible;
              }
            }

              return Row(
                children: [
                  Expanded(child: _statCard('Quizzes Taken', '$quizzesTaken', Icons.assignment_turned_in_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Overall Score', '${totalEarned.toInt()}/${totalPossible.toInt()}', Icons.bar_chart_rounded)),
                ],
              );
          },
        ),

        // Actions
        Column(
          children: [
            _primaryButton(
              context,
              icon: Icons.insights_rounded,
              label: 'My Progress',
              color: _deepBlue,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ResultsScreen(appUser: appUser)),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => _confirmClearProgress(context),
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text('Reset Progress', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            // Bottom Bumper for Floating Nav Bar
            const SizedBox(height: 100),
          ],
        ),
      ],
    );
  }
}

// ─── Admin View ────────────────────────────────────────────────────────────────
class _AdminContent extends StatelessWidget {
  final AppUser appUser;

  const _AdminContent({required this.appUser});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Admin Stats',
          style: TextStyle(
            color: _deepBlue,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Dynamic Stats Row
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('resources').snapshots(),
          builder: (context, resSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('quiz_sessions').snapshots(),
              builder: (context, quizSnapshot) {
                final int resourceCount = resSnapshot.hasData ? resSnapshot.data!.docs.length : 0;
                final int quizCount = quizSnapshot.hasData ? quizSnapshot.data!.docs.length : 0;

                int pastpapersCount = 0;
                int notesCount = 0;
                int notebooksCount = 0;

                if (resSnapshot.hasData) {
                  final docs = resSnapshot.data!.docs;
                  pastpapersCount = docs.where((doc) => (doc.data() as Map<String, dynamic>)['type'] == 'past_paper').length;
                  notesCount = docs.where((doc) => (doc.data() as Map<String, dynamic>)['type'] == 'notes').length;
                  notebooksCount = docs.where((doc) => (doc.data() as Map<String, dynamic>)['type'] == 'textbook').length;
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            'Total Resources',
                            '$resourceCount',
                            Icons.library_books_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            'Active Quizzes',
                            '$quizCount',
                            Icons.quiz_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _lightBlue, width: 1.2),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildSubStatColumn(
                              value: pastpapersCount.toString(),
                              label: 'Pastpapers',
                            ),
                            const VerticalDivider(thickness: 1, color: _lightBlue),
                            _buildSubStatColumn(
                              value: notesCount.toString(),
                              label: 'Notes',
                            ),
                            const VerticalDivider(thickness: 1, color: _lightBlue),
                            _buildSubStatColumn(
                              value: notebooksCount.toString(),
                              label: 'Notebooks',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),

        // Admin Actions
        Column(
          children: [
            _primaryButton(
              context,
              icon: Icons.quiz_rounded,
              label: 'Manage Quizzes',
              color: _deepBlue,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminCreateQuizScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _primaryButton(
              context,
              icon: Icons.upload_file_rounded,
              label: 'Upload Resources',
              color: _lightBlue,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminUploadScreen()),
              ),
            ),
          ],
        ),

        // Bottom Bumper for Floating Nav Bar
        const SizedBox(height: 70),
      ],
    );
  }
}

// ─── Shared Helpers ────────────────────────────────────────────────────────────
Widget _infoCard({required List<Widget> children}) {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: _lightBlue, width: 1.2),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: children),
    ),
  );
}

Widget _infoRow(IconData icon, String label, String value) {
  return ListTile(
    leading: Icon(icon, color: _deepBlue, size: 22),
    title: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
    subtitle: Text(
      value,
      style: const TextStyle(
        color: _deepBlue,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    ),
  );
}

Widget _statCard(String label, String value, IconData icon) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _lightBlue, width: 1.2),
    ),
    child: Column(
      children: [
        Icon(icon, color: _deepBlue, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: _deepBlue,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      ],
    ),
  );
}

Widget _buildSubStatColumn({required String value, required String label}) {
  return Expanded(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: _deepBlue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 10,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _primaryButton(
  BuildContext context, {
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
