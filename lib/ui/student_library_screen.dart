import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import 'pdf_viewer_screen.dart';
import 'doc_viewer_screen.dart';

class StudentLibraryScreen extends StatefulWidget {
  final String initialSubject;
  final AppUser appUser;
  final String? initialResourceId;

  const StudentLibraryScreen({
    super.key,
    this.initialSubject = 'Physics',
    required this.appUser,
    this.initialResourceId,
  });

  @override
  State<StudentLibraryScreen> createState() => _StudentLibraryScreenState();
}

class _StudentLibraryScreenState extends State<StudentLibraryScreen> {
  final String _selectedClass = '9';
  late String _selectedSubject;
  String _selectedType = 'All';

  Set<String> _favoriteResourceIds = {};

  static const _allSubjects = 'All Subjects';
  static const _favoritesKey = 'Favorites';

  static const _subjects = [
    _allSubjects,
    _favoritesKey,
    'Mathematics', 'Physics', 'Urdu', 'Islamiat',
    'English', 'Computer Science', 'Chemistry', 'Biology',
  ];

  static const _typeIcons = {
    'textbook': Icons.auto_stories_rounded,
    'notes': Icons.note_alt_rounded,
    'past_paper': Icons.history_edu_rounded,
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialResourceId != null) {
      _selectedSubject = _allSubjects;
      _selectedType = 'All';
    } else {
      _selectedSubject = _subjects.contains(widget.initialSubject)
          ? widget.initialSubject
          : _allSubjects;
    }
    _loadFavorites();
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
          _favoriteResourceIds =
              Set<String>.from(data['favoriteResources'] ?? []);
        });
      }
    });
  }

  Future<void> _toggleFavoriteResource(String resourceId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final isFav = _favoriteResourceIds.contains(resourceId);
    // Optimistic update
    setState(() {
      if (isFav) {
        _favoriteResourceIds.remove(resourceId);
      } else {
        _favoriteResourceIds.add(resourceId);
      }
    });

    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'favoriteResources': isFav
            ? FieldValue.arrayRemove([resourceId])
            : FieldValue.arrayUnion([resourceId]),
      },
      SetOptions(merge: true),
    );
  }

  // ── Firestore query stream ──────────────────────────────────────
  Stream<QuerySnapshot> get _resourceStream {
    // Specific resource from search
    if (widget.initialResourceId != null &&
        _selectedType == 'All' &&
        _selectedSubject == _allSubjects) {
      return FirebaseFirestore.instance
          .collection('resources')
          .where(FieldPath.documentId, isEqualTo: widget.initialResourceId)
          .snapshots();
    }

    // Favorites — fetch all then filter client-side
    if (_selectedSubject == _favoritesKey) {
      return FirebaseFirestore.instance
          .collection('resources')
          .where('classLevel', isEqualTo: _selectedClass)
          .orderBy('uploadedAt', descending: true)
          .snapshots();
    }

    // Normal browsing
    Query query = FirebaseFirestore.instance
        .collection('resources')
        .where('classLevel', isEqualTo: _selectedClass);

    if (_selectedSubject != _allSubjects) {
      query = query.where('subject', isEqualTo: _selectedSubject);
    }

    if (_selectedType != 'All') {
      query = query.where('type', isEqualTo: _selectedType);
    }

    return query.orderBy('uploadedAt', descending: true).snapshots();
  }

  Future<void> _saveRecentSubject(String subject) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recent =
        prefs.getStringList('recently_visited_subjects') ?? [];
    recent.remove(subject);
    recent.insert(0, subject);
    if (recent.length > 4) recent = recent.sublist(0, 4);
    await prefs.setStringList('recently_visited_subjects', recent);
  }

  void _openFile(String title, String fileUrl) {
    if (fileUrl.isEmpty) {
      _showSnackBar('No file URL available for this resource.',
          isError: true);
      return;
    }
    _saveRecentSubject(_selectedSubject);
    final lowerUrl = fileUrl.toLowerCase();
    if (lowerUrl.endsWith('.pdf') || lowerUrl.contains('.pdf')) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => PdfViewerScreen(url: fileUrl, title: title)));
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => DocViewerScreen(url: fileUrl, title: title)));
    }
  }

  Future<void> _confirmDelete(String docId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('Delete Resource'),
        ]),
        content: Text(
            'Are you sure you want to permanently delete\n"$title"?\n\nThis cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('resources')
          .doc(docId)
          .delete();
      _showSnackBar('"$title" deleted successfully.');
    } catch (e) {
      debugPrint('Delete error: $e');
      _showSnackBar('Failed to delete: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
      backgroundColor:
          isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── BUILD ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool showingFavorites = _selectedSubject == _favoritesKey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resource Library'),
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
            stops: [0.0, 0.15],
          ),
        ),
        child: Column(
          children: [
            // ═══ SUBJECT FILTER (DROPDOWN) ═══════════════════════
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        showingFavorites
                            ? Icons.favorite
                            : Icons.filter_alt_rounded,
                        color: showingFavorites
                            ? Colors.red
                            : const Color(0xFF1A237E),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSubject,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Color(0xFF1A237E)),
                            style: const TextStyle(
                                color: Color(0xFF1A237E),
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                            items: _subjects
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Row(
                                        children: [
                                          if (s == _favoritesKey) ...[
                                            const Icon(Icons.favorite,
                                                color: Colors.red, size: 16),
                                            const SizedBox(width: 8),
                                          ],
                                          Text(s),
                                        ],
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedSubject = v!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ═══ TYPE FILTER CHIPS ════════════════════════════════
            if (!showingFavorites)
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildTypeChip('All', 'All'),
                    _buildTypeChip('Textbook', 'textbook'),
                    _buildTypeChip('Past Paper', 'past_paper',
                        autoSubject: _allSubjects),
                    _buildTypeChip('Notes', 'notes'),
                  ],
                ),
              )
            else
              const SizedBox(height: 12),

            // ═══ RESOURCE LIST ════════════════════════════════════
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _resourceStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.white));
                  }
                  if (snapshot.hasError) {
                    return _buildEmptyState(
                      icon: Icons.error_outline_rounded,
                      message: 'Error loading resources.\n${snapshot.error}',
                    );
                  }

                  final allDocs = snapshot.data?.docs ?? [];

                  // Client-side filter when showing favorites
                  final docs = showingFavorites
                      ? allDocs
                          .where((d) => _favoriteResourceIds.contains(d.id))
                          .toList()
                      : allDocs;

                  if (docs.isEmpty) {
                    return showingFavorites
                        ? _buildEmptyState(
                            icon: Icons.favorite_border,
                            message:
                                'No favourites yet.\nTap ♡ on any resource to save it here.',
                          )
                        : _buildEmptyState(
                            icon: Icons.folder_off_rounded,
                            message:
                                'No resources found for\nClass $_selectedClass • $_selectedSubject',
                          );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(
                        left: 16, top: 0, right: 16, bottom: 120),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data()! as Map<String, dynamic>;
                      return _buildResourceCard(doc.id, data);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Resource card ──────────────────────────────────────────────
  Widget _buildResourceCard(String docId, Map<String, dynamic> data) {
    final title = data['title'] as String? ?? 'Untitled';
    final type = data['type'] as String? ?? 'unknown';
    final chapter = data['chapter'] as String? ?? '';
    final fileUrl = data['fileUrl'] as String? ?? '';

    final typeIcon = _typeIcons[type] ?? Icons.insert_drive_file_rounded;
    final subtitle = chapter.isNotEmpty
        ? '${type.toUpperCase()} • $chapter'
        : type.toUpperCase();

    final bool isFav = _favoriteResourceIds.contains(docId);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: fileUrl.isEmpty ? null : () => _openFile(title, fileUrl),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1A237E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(typeIcon,
                color: const Color(0xFF1A237E), size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Favourite heart (students only) ──
              if (!widget.appUser.isAdmin)
                IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? Colors.red : Colors.grey,
                  ),
                  tooltip: isFav
                      ? 'Remove favourite'
                      : 'Add to favourites',
                  onPressed: () => _toggleFavoriteResource(docId),
                ),

              // ── View icon ──
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFF1A237E),
                ),
              ),

              // ── Delete (ADMIN ONLY) ──
              if (widget.appUser.isAdmin)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.red.shade600,
                  tooltip: 'Delete Resource',
                  onPressed: () => _confirmDelete(docId, title),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty / error state ────────────────────────────────────────
  Widget _buildEmptyState({
    required IconData icon,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.white30),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // ── Type Filter Chip ────────────────────────────────────────────
  Widget _buildTypeChip(String label, String value, {String? autoSubject}) {
    final isSelected = _selectedType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = value;
            if (autoSubject != null) _selectedSubject = autoSubject;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.transparent : Colors.white54,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue.shade900 : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
