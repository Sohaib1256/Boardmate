import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import 'admin_create_notification_screen.dart';
import 'quiz_list_screen.dart';
import 'student_library_screen.dart';
import 'results_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final AppUser appUser;
  
  const NotificationsScreen({super.key, required this.appUser});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String selectedCourse = 'All';

  @override
  void initState() {
    super.initState();
  }

  final List<String> _courses = [
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

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Announcement':
        return Icons.campaign;
      case 'Discussion':
        return Icons.forum;
      case 'Resource':
        return Icons.library_books;
      case 'Quiz':
        return Icons.assignment;
      default:
        return Icons.notifications;
    }
  }

  void _showEditDialog(String docId, String currentTitle, String currentBody) {
    final titleController = TextEditingController(text: currentTitle);
    final bodyController = TextEditingController(text: currentBody);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Notification'),
          content: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextFormField(
                  controller: bodyController,
                  decoration: const InputDecoration(labelText: 'Body'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                FirebaseFirestore.instance.collection('notifications').doc(docId).update({
                  'title': titleController.text.trim(),
                  'body': bodyController.text.trim(),
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _markAllAsRead(List<QueryDocumentSnapshot> docs) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      List<String> readBy = List<String>.from(data['readBy'] ?? []);
      if (!readBy.contains(widget.appUser.uid)) {
        batch.update(doc.reference, {'readBy': FieldValue.arrayUnion([widget.appUser.uid])});
      }
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('notifications')
        .where('targetAudience', whereIn: ['All', widget.appUser.uid])
        .orderBy('timestamp', descending: true);

    if (selectedCourse != 'All') {
      query = query.where('subject', isEqualTo: selectedCourse);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];
        
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.done_all),
                tooltip: 'Mark all as read',
                onPressed: docs.isEmpty ? null : () => _markAllAsRead(docs),
              ),
            ],
          ),
      floatingActionButton: widget.appUser.isAdmin
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminCreateNotificationScreen()),
                );
              },
              backgroundColor: Colors.blue,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          // Filter Chips
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _courses.length,
              itemBuilder: (context, index) {
                final course = _courses[index];
                final isSelected = selectedCourse == course;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0, top: 8.0, bottom: 8.0),
                  child: ChoiceChip(
                    label: Text(course),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          selectedCourse = course;
                        });
                      }
                    },
                    selectedColor: Colors.blue.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.blue.shade700 : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: Colors.grey.shade100,
                  ),
                );
              },
            ),
          ),
          // Notifications List
          Expanded(
            child: () {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const Center(child: Text("Error loading notifications."));
              }

              if (!snapshot.hasData || docs.isEmpty) {
                return const Center(
                  child: Text(
                    "No notifications found.",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                );
              }

              return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF0F0F0),
                    indent: 72,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    
                    final title = data['title'] ?? 'No Title';
                    final subtitle = data['body'] ?? '';
                    final type = data['type'] ?? 'Announcement';
                    final timestamp = data['timestamp'] as Timestamp?;
                    
                    String dateStr = '';
                    if (timestamp != null) {
                      dateStr = DateFormat('MMM d, hh:mm a').format(timestamp.toDate());
                    }

                    final bool isUnread = !(List<String>.from(data['readBy'] ?? []).contains(widget.appUser.uid));
                    final IconData icon = _getIconForType(type);

                    return Container(
                      color: isUnread ? Colors.blue.withValues(alpha: 0.08) : Colors.transparent,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isUnread ? Colors.blue : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue.shade700,
                              radius: 24,
                              child: Icon(icon, size: 24),
                            ),
                          ],
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        trailing: widget.appUser.isAdmin
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showEditDialog(docs[index].id, title, subtitle),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => FirebaseFirestore.instance.collection('notifications').doc(docs[index].id).delete(),
                                  ),
                                ],
                              )
                            : Text(
                                dateStr,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                        onTap: () {
                          if (isUnread) {
                            FirebaseFirestore.instance
                                .collection('notifications')
                                .doc(docs[index].id)
                                .update({'readBy': FieldValue.arrayUnion([widget.appUser.uid])});
                          }

                          final String notificationType = data['type'] ?? 'Announcement';
                          final String subject = data['subject'] ?? 'All';

                          if (notificationType == 'Quiz') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QuizListScreen(
                                  appUser: widget.appUser,
                                  initialSubject: subject,
                                ),
                              ),
                            );
                          } else if (notificationType == 'Resource') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentLibraryScreen(
                                  appUser: widget.appUser,
                                  initialSubject: subject,
                                ),
                              ),
                            );
                          } else if (notificationType == 'Score') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ResultsScreen(
                                  appUser: widget.appUser,
                                ),
                              ),
                            );
                          } else {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Text(title),
                                content: Text(subtitle.isNotEmpty ? subtitle : 'No additional details.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
            }(),
          ),
        ],
      ),
    );
      },
    );
  }
}
