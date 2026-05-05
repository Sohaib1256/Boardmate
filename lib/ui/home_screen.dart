import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/app_user.dart';
import 'admin_upload_screen.dart';
import 'student_library_screen.dart';
import 'design_course_app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_create_quiz_screen.dart';
import 'quiz_list_screen.dart';
import 'notifications_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'ai_tutor_screen.dart';
import 'quiz_screen.dart';
import 'pdf_viewer_screen.dart';
import 'doc_viewer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
class HomeScreen extends StatefulWidget {
  final AppUser appUser;
  const HomeScreen({super.key, required this.appUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final List<String> subjects = [
    'Mathematics', 'Physics', 'Urdu', 'Islamiat', 'English', 'Computer Science', 'Chemistry', 'Biology'
  ];
  String selectedSubject = 'Mathematics';

  AnimationController? animationController;
  final AuthService _authService = AuthService();
  final TextEditingController searchController = TextEditingController();
  final ScrollController _featureScrollController = ScrollController();
  Timer? _carouselTimer;

  List<FeatureModel> mainFeatures = [];
  List<FeatureModel> filteredFeatures = [];
  
  List<String> _recentlyVisited = [];
  List<PopularModel> recentResources = [];

  // ── Search State ──
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingSearch = false;
  Timer? _searchDebounce;

  String _getImageForSubject(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics': return 'assets/images/math_bg.png';
      case 'physics': return 'assets/images/physics_bg.png';
      case 'chemistry': return 'assets/images/chemistry_bg.png';
      case 'biology': return 'assets/images/biology_bg.png';
      case 'english': return 'assets/images/english_bg.png';
      case 'islamiat': return 'assets/images/islamiat_bg.png';
      case 'urdu': return 'assets/images/urdu_bg.png';
      case 'computer science': return 'assets/images/computer_science_bg.png';
      default: return 'assets/images/physics_bg.png'; // fallback
    }
  }


  Future<void> _loadRecentSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList('recently_visited_subjects') ?? [];
    List<String> defaults = ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 'Islamiat'];
    Set<String> combined = {...saved, ...defaults};
    
    if (!mounted) return;
    setState(() {
      _recentlyVisited = combined.take(4).toList();
      _updateRecentResources();
    });
  }

  void _updateRecentResources() {
    recentResources = _recentlyVisited.map((subject) {
      return PopularModel(
        title: subject,
        subject: subject,
        rating: 4.8,
        imagePath: _getImageForSubject(subject),
      );
    }).toList();
  }

  Future<void> _saveRecentSubject(String subject) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recent = prefs.getStringList('recently_visited_subjects') ?? [];
    recent.remove(subject);
    recent.insert(0, subject);
    if (recent.length > 4) {
      recent = recent.sublist(0, 4);
    }
    await prefs.setStringList('recently_visited_subjects', recent);
    setState(() {
      _recentlyVisited = recent;
      _updateRecentResources();
    });
  }

  @override
  void initState() {
    animationController = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this);

    _loadRecentSubjects();

    mainFeatures = [
      FeatureModel(
        title: 'Resource Library',
        subtitle: 'Notes & Pastpapers',
        imagePath: 'assets/images/resource_library.png',
        onTap: () {
          _saveRecentSubject(selectedSubject);
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => StudentLibraryScreen(
                initialSubject: selectedSubject,
                appUser: widget.appUser,
              ))).then((_) => _loadRecentSubjects());
        },
      ),
      FeatureModel(
        title: widget.appUser.isAdmin ? 'Manage Quizzes' : 'Take Quiz',
        subtitle: widget.appUser.isAdmin ? 'Create & manage' : 'Test your skills',
        imagePath: 'assets/images/manage_quizzes.png',
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => QuizListScreen(appUser: widget.appUser)));
        },
      ),
      FeatureModel(
        title: 'Ask AI',
        subtitle: '24/7 Assistant',
        imagePath: 'assets/images/ask_ai.png',
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AiTutorScreen()));
        },
      ),
    ];
    filteredFeatures = List.from(mainFeatures);

    super.initState();
    _startCarouselTimer();
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_featureScrollController.hasClients) {
        final double maxScroll = _featureScrollController.position.maxScrollExtent;
        final double currentScroll = _featureScrollController.offset;
        
        // The feature card width is approx 280, adjust scroll offset to scroll one item
        double nextScroll = currentScroll + 280.0;
        
        // If we are already at the max scroll (or very close due to float precision), rewind to the start
        if (maxScroll == 0 || currentScroll >= maxScroll - 5.0) {
          _featureScrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          // Animate to the next scroll target, but don't overshoot maxScroll
          double target = nextScroll > maxScroll ? maxScroll : nextScroll;
          _featureScrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _isLoadingSearch = false;
      });
      return;
    }

    // Set searching immediately to hide categories and show loading/results
    setState(() {
      _isSearching = true;
      _isLoadingSearch = true; 
    });

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _performDynamicSearch(query);
    });
  }

  Future<void> _performDynamicSearch(String query) async {
    if (!mounted) return;
    final lowercaseQuery = query.toLowerCase().trim();
    
    setState(() {
      _isSearching = true;
      _isLoadingSearch = true;
    });

    try {
      List<SearchResult> resources = [];
      List<SearchResult> quizzes = [];

      // ── 1. Check for Keywords (Type-based search) ──
      String? targetType;
      final len = lowercaseQuery.length;
      
      if (len >= 3) {
        if ('notes'.startsWith(lowercaseQuery) || lowercaseQuery.startsWith('note')) targetType = 'notes';
        if ('pastpaper'.startsWith(lowercaseQuery) || lowercaseQuery.startsWith('past')) targetType = 'past_paper';
        if ('textbook'.startsWith(lowercaseQuery) || lowercaseQuery.startsWith('text')) targetType = 'textbook';
      }

      if (targetType != null) {
        final typeSnap = await FirebaseFirestore.instance
            .collection('resources')
            .where('type', isEqualTo: targetType)
            .limit(15)
            .get();
        
        resources = typeSnap.docs.map((doc) {
          final data = doc.data();
          return SearchResult(
            id: doc.id,
            title: data['title'] ?? 'Untitled Resource',
            type: 'Resource',
            url: data['fileUrl'],
            data: data,
          );
        }).toList();
      } else if (len >= 3 && ('resources'.startsWith(lowercaseQuery) || lowercaseQuery.startsWith('resour'))) {
        final allResSnap = await FirebaseFirestore.instance
            .collection('resources')
            .limit(15)
            .get();
        resources = allResSnap.docs.map((doc) {
          final data = doc.data();
          return SearchResult(
            id: doc.id,
            title: data['title'] ?? 'Untitled Resource',
            type: 'Resource',
            url: data['fileUrl'],
            data: data,
          );
        }).toList();
      }

      // ── 2. Prefix Match on Title & Subject (normalized fields) ──
      if (resources.length < 15) {
        // Search by Title
        final titleSnap = await FirebaseFirestore.instance
            .collection('resources')
            .where('title_lowercase', isGreaterThanOrEqualTo: lowercaseQuery)
            .where('title_lowercase', isLessThanOrEqualTo: '$lowercaseQuery\uf8ff')
            .limit(10)
            .get();
        
        // Search by Subject
        final subjectSnap = await FirebaseFirestore.instance
            .collection('resources')
            .where('subject_lowercase', isGreaterThanOrEqualTo: lowercaseQuery)
            .where('subject_lowercase', isLessThanOrEqualTo: '$lowercaseQuery\uf8ff')
            .limit(10)
            .get();
        
        final List<SearchResult> resourceMatches = [
          ...titleSnap.docs,
          ...subjectSnap.docs
        ].map((doc) {
          final data = doc.data();
          return SearchResult(
            id: doc.id,
            title: data['title'] ?? 'Untitled Resource',
            type: 'Resource',
            url: data['fileUrl'],
            data: data,
          );
        }).toList();
        
        // Merge and remove duplicates
        final existingIds = resources.map((r) => r.id).toSet();
        for (var m in resourceMatches) {
          if (!existingIds.contains(m.id)) {
            resources.add(m);
            existingIds.add(m.id);
          }
        }
      }

      // ── 3. Query Quizzes ──
      // If user types "qui...", show some quizzes, otherwise search by subject
      if (len >= 3 && ('quizzes'.startsWith(lowercaseQuery) || lowercaseQuery.startsWith('qui'))) {
        final allQuizSnap = await FirebaseFirestore.instance
            .collection('quiz_sessions')
            .orderBy('subject') // Need an order for limit
            .limit(10)
            .get();
        quizzes = allQuizSnap.docs.map((doc) {
          final data = doc.data();
          return SearchResult(
            id: doc.id,
            title: data['subject'] ?? 'Unknown Quiz',
            type: 'Quiz',
            data: data,
          );
        }).toList();
      } else {
        final quizSnap = await FirebaseFirestore.instance
            .collection('quiz_sessions')
            .where('subject_lowercase', isGreaterThanOrEqualTo: lowercaseQuery)
            .where('subject_lowercase', isLessThanOrEqualTo: '$lowercaseQuery\uf8ff')
            .limit(10)
            .get();

        quizzes = quizSnap.docs.map((doc) {
          final data = doc.data();
          return SearchResult(
            id: doc.id,
            title: data['subject'] ?? 'Unknown Quiz',
            type: 'Quiz',
            data: data,
          );
        }).toList();
      }

      if (mounted) {
        setState(() {
          _searchResults = [...resources, ...quizzes];
          _isLoadingSearch = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() => _isLoadingSearch = false);
      }
    }
  }

  void _showStartQuizDialog(Map<String, dynamic> data, String docId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Start Quiz?'),
          content: Text('Subject: ${data['subject']}\nTime Limit: ${data['timeLimitMinutes']} mins\n\nAre you ready? The timer cannot be paused once started.'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignCourseAppTheme.nearlyBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => QuizScreen(sessionId: docId)),
                );
              },
              child: const Text('Start Attempt'),
            ),
          ],
        );
      },
    );
  }


  @override
  void dispose() {
    _carouselTimer?.cancel();
    _featureScrollController.dispose();
    animationController?.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignCourseAppTheme.nearlyWhite,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
          Container(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/home_bg.png'),
                alignment: Alignment.topCenter,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                getAppBarUI(),
                getSearchBarUI(),
                Expanded(
                  child: _isSearching 
                      ? _buildSearchResultsUI()
                      : SingleChildScrollView(
                          child: Column(
                            children: <Widget>[
                              getCategoryUI(),
                              getPopularCourseUI(),
                              const SizedBox(height: 100), // Bottom padding for floating nav
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget getCategoryUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 8.0, left: 18, right: 16),
          child: Text(
            'Subjects',
            textAlign: TextAlign.left,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 22,
              letterSpacing: 0.27,
              color: DesignCourseAppTheme.darkerText,
            ),
          ),
        ),
        const SizedBox(
          height: 16,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: subjects.map((subject) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: getButtonUI(subject, selectedSubject == subject),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(
          height: 16,
        ),
        getCategoryListView(),
      ],
    );
  }

  Widget getButtonUI(String subjectData, bool isSelected) {
    return Container(
      decoration: BoxDecoration(
          color: DesignCourseAppTheme.nearlyWhite,
          borderRadius: const BorderRadius.all(Radius.circular(24.0)),
          border: Border.all(color: DesignCourseAppTheme.nearlyBlue)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          splashColor: Colors.white24,
          borderRadius: const BorderRadius.all(Radius.circular(24.0)),
          onTap: () {
            setState(() {
              selectedSubject = subjectData;
            });
            _saveRecentSubject(subjectData);
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => StudentLibraryScreen(
                  initialSubject: subjectData,
                  appUser: widget.appUser,
                )));
          },
          child: Padding(
            padding: const EdgeInsets.only(
                top: 12, bottom: 12, left: 18, right: 18),
            child: Center(
              child: Text(
                subjectData,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 0.27,
                  color: DesignCourseAppTheme.nearlyBlue,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget getCategoryListView() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: SizedBox(
        height: 144,
        width: double.infinity,
        child: ListView.builder(
          controller: _featureScrollController,
          padding: const EdgeInsets.only(
            top: 0,
            bottom: 0,
            right: 16,
            left: 16,
          ),
          itemCount: filteredFeatures.length,
          scrollDirection: Axis.horizontal,
          itemBuilder: (BuildContext context, int index) {
            final int count = filteredFeatures.length;
            final Animation<double> animation =
                Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animationController!,
                curve: Interval(
                  (1 / (count == 0 ? 1 : count)) * index,
                  1.0,
                  curve: Curves.fastOutSlowIn,
                ),
              ),
            );
            animationController?.forward();

            return getFeatureView(filteredFeatures[index], animation);
          },
        ),
      ),
    );
  }

  Widget getFeatureView(FeatureModel feature, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animationController!,
      builder: (BuildContext context, Widget? child) {
        return FadeTransition(
          opacity: animation,
          child: Transform(
            transform: Matrix4.translationValues(
              100 * (1.0 - animation.value),
              0.0,
              0.0,
            ),
            child: InkWell(
              splashColor: Colors.transparent,
              onTap: feature.onTap,
              child: SizedBox(
                width: 280,
                child: Stack(
                  children: <Widget>[
                    SizedBox(
                      child: Row(
                        children: <Widget>[
                          const SizedBox(width: 48),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: HexColor('#F8FAFB'),
                                border: Border.all(
                                  color: Colors.blue.shade900,
                                  width: 2.5,
                                ),
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(16.0),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  const SizedBox(width: 48 + 24.0),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 16, bottom: 8
                                          ),
                                          child: Text(
                                              feature.title,
                                              textAlign: TextAlign.left,
                                              maxLines: 2,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                                letterSpacing: 0.27,
                                                color: DesignCourseAppTheme.darkerText,
                                              ),
                                            ),
                                          ),
                                          const Expanded(child: SizedBox()),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 16,
                                              bottom: 8,
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: <Widget>[
                                                Text(
                                                  feature.subtitle,
                                                  textAlign: TextAlign.left,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w400,
                                                    fontSize: 12,
                                                    letterSpacing: 0.27,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.bolt_rounded,
                                                  color: DesignCourseAppTheme.nearlyBlue,
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16, right: 16
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: <Widget>[
                                                if (widget.appUser.isAdmin)
                                                  InkWell(
                                                    onTap: () {
                                                      if (feature.title == 'Resource Library') {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) => AdminUploadScreen(),
                                                          ),
                                                        );
                                                      } else if (feature.title == 'Create Quiz Session' || feature.title == 'Manage Quizzes') {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) => const AdminCreateQuizScreen(),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: DesignCourseAppTheme.nearlyBlue,
                                                        borderRadius: const BorderRadius.all(
                                                          Radius.circular(8.0),
                                                        ),
                                                      ),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(4.0),
                                                        child: Icon(
                                                          Icons.add,
                                                          color: DesignCourseAppTheme.nearlyWhite,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  const SizedBox(width: 32, height: 32),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 24,
                          bottom: 24,
                          left: 16,
                        ),
                        child: Row(
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(16.0),
                              ),
                              child: AspectRatio(
                                aspectRatio: 1.0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8.0),
                                    image: DecorationImage(
                                      image: AssetImage(feature.imagePath),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  Widget getPopularCourseUI() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 18, right: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Recent Resources',
            textAlign: TextAlign.left,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 22,
              letterSpacing: 0.27,
              color: DesignCourseAppTheme.darkerText,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GridView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              physics: const NeverScrollableScrollPhysics(),
              scrollDirection: Axis.vertical,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 32.0,
                  crossAxisSpacing: 32.0,
                  childAspectRatio: 0.8,
                ),
                children: List<Widget>.generate(
                  recentResources.length,
                  (int index) {
                    final int count = recentResources.length;
                    final Animation<double> animation =
                        Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animationController!,
                        curve: Interval(
                          (1 / count) * index,
                          1.0,
                          curve: Curves.fastOutSlowIn,
                        ),
                      ),
                    );
                    animationController?.forward();
                    return getGridResourceView(recentResources[index], animation);
                  },
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget getGridResourceView(PopularModel popular, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animationController!,
      builder: (BuildContext context, Widget? child) {
        return FadeTransition(
          opacity: animation,
          child: Transform(
            transform: Matrix4.translationValues(
              0.0,
              50 * (1.0 - animation.value),
              0.0,
            ),
            child: InkWell(
              splashColor: Colors.transparent,
              onTap: () {
                _saveRecentSubject(popular.subject);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => StudentLibraryScreen(
                      initialSubject: popular.subject,
                      appUser: widget.appUser,
                    ))).then((_) => _loadRecentSubjects());
              },
              child: SizedBox(
                height: 280,
                child: Stack(
                  alignment: AlignmentDirectional.bottomCenter,
                  children: <Widget>[
                    SizedBox(
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: HexColor('#F8FAFB'),
                                border: Border.all(
                                  color: Colors.blue.shade900,
                                  width: 2.5,
                                ),
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(16.0),
                                ),
                              ),
                              child: Column(
                                children: <Widget>[
                                  Expanded(
                                    child: Column(
                                      children: <Widget>[
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 16,
                                            left: 16,
                                            right: 16,
                                          ),
                                          child: Text(
                                              popular.title,
                                              textAlign: TextAlign.left,
                                              maxLines: 2,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                                letterSpacing: 0.27,
                                                color: DesignCourseAppTheme.darkerText,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 0,
                                              left: 16,
                                              right: 16,
                                              bottom: 8,
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: <Widget>[
                                                Text(
                                                  'Study Materials',
                                                  textAlign: TextAlign.left,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w400,
                                                    fontSize: 12,
                                                    letterSpacing: 0.27,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.description_outlined,
                                                  color: DesignCourseAppTheme.nearlyBlue,
                                                  size: 18,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(width: 48),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                    SizedBox(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 24,
                          right: 16,
                          left: 16,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(16.0),
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: DesignCourseAppTheme.grey.withValues(alpha: 0.2),
                                offset: const Offset(0.0, 0.0),
                                blurRadius: 6.0,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(16.0),
                            ),
                            child: AspectRatio(
                              aspectRatio: 1.28,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.asset(
                                  popular.imagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: Icon(Icons.error_outline, color: Colors.grey),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
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
      },
    );
  }

  Widget getSearchBarUI() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: HexColor('#F8FAFB'),
          borderRadius: BorderRadius.circular(13.0),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: TextFormField(
                  controller: searchController,
                  onChanged: _onSearchChanged,
                  style: TextStyle(
                    fontFamily: 'WorkSans',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: DesignCourseAppTheme.nearlyBlue,
                  ),
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Search resources or quizzes...',
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13.0),
                      borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13.0),
                      borderSide: BorderSide(color: DesignCourseAppTheme.nearlyBlue.withValues(alpha: 0.3), width: 1.0),
                    ),
                    helperStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: HexColor('#B9BABC'),
                    ),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      letterSpacing: 0.2,
                      color: HexColor('#B9BABC'),
                    ),
                  ),
                  onFieldSubmitted: (_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                ),
              ),
            ),
            SizedBox(
              width: 60,
              height: 60,
              child: IconButton(
                icon: Icon(
                  _isSearching ? Icons.close : Icons.search,
                  color: HexColor('#B9BABC'),
                ),
                onPressed: () {
                  if (_isSearching) {
                    searchController.clear();
                    _onSearchChanged('');
                  }
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsUI() {
    if (_isLoadingSearch) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          "No results found for '${searchController.text}'",
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 120),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _SearchResultTile(
          result: result,
          onTap: () {
            if (result.type == 'Resource') {
              final url = result.url;
              if (url == null || url.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Error: Document URL is missing.'),
                    backgroundColor: Colors.red.shade700,
                  ),
                );
                return;
              }
              final isPdf = url.toLowerCase().contains('.pdf');
              if (isPdf) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfViewerScreen(
                      url: url,
                      title: result.title,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DocViewerScreen(
                      url: url,
                      title: result.title,
                    ),
                  ),
                );
              }
            } else if (result.type == 'Quiz') {
              if (widget.appUser.isAdmin) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminCreateQuizScreen(
                      existingQuizId: result.id,
                      existingQuizData: result.data ?? {},
                    ),
                  ),
                );
              } else {
                _showStartQuizDialog(result.data ?? {}, result.id);
              }
            }
          },
        );
      },
    );
  }

  Widget getAppBarUI() {
    final user = widget.appUser;
    final String displayName = user.displayName.isNotEmpty ? user.displayName : (user.email.isNotEmpty ? user.email : "User");
    
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 18, right: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Hello,',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    letterSpacing: 0.2,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  '$displayName!',
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: 0.27,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: user.isAdmin
                        ? Colors.amber.shade700
                        : Colors.green.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.isAdmin ? '🎓 Admin / Teacher' : '📚 Student',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Actions wrapper pushed up by Transform
          Transform.translate(
            offset: const Offset(0, -15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Notification Bell
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DesignCourseAppTheme.nearlyWhite,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                          color: DesignCourseAppTheme.grey.withValues(alpha: 0.2),
                          offset: const Offset(0, 2),
                          blurRadius: 8.0),
                    ],
                  ),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .where('targetAudience', whereIn: ['All', widget.appUser.uid])
                        .snapshots(),
                    builder: (context, snapshot) {
                      bool hasUnread = false;
                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final readBy = List<String>.from(data['readBy'] ?? []);
                          if (!readBy.contains(widget.appUser.uid)) {
                            hasUnread = true;
                            break;
                          }
                        }
                      }
                      return Badge(
                        isLabelVisible: hasUnread,
                        backgroundColor: Colors.red,
                        smallSize: 14,
                        child: IconButton(
                          icon: const Icon(Icons.notifications_none, color: DesignCourseAppTheme.nearlyBlue),
                          tooltip: 'Notifications',
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(appUser: widget.appUser)));
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DesignCourseAppTheme.nearlyWhite,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                          color: DesignCourseAppTheme.grey.withValues(alpha: 0.2),
                          offset: const Offset(0, 2),
                          blurRadius: 8.0),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: DesignCourseAppTheme.nearlyBlue),
                    tooltip: 'Sign Out',
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      await _authService.signOut();
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FeatureModel {
  FeatureModel({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.onTap,
  });

  String title;
  String subtitle;
  String imagePath;
  VoidCallback onTap;
}

class SearchResult {
  final String id;
  final String title;
  final String type; // 'Resource' or 'Quiz'
  final String? url; // For resources
  final Map<String, dynamic>? data; // Full data for navigation

  SearchResult({
    required this.id,
    required this.title,
    required this.type,
    this.url,
    this.data,
  });
}

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _SearchResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isResource = result.type == 'Resource';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: DesignCourseAppTheme.nearlyBlue.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: (isResource ? Colors.orange : Colors.blue).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isResource ? Icons.description : Icons.quiz,
            color: isResource ? Colors.orange : Colors.blue,
          ),
        ),
        title: Text(
          result.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          '${result.type}${isResource ? "" : " Session"}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

class PopularModel {
  PopularModel({
    required this.title,
    required this.subject,
    required this.imagePath,
    required this.rating,
  });

  String title;
  String subject;
  String imagePath;
  double rating;
}

class HexColor extends Color {
  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));

  static int _getColorFromHex(String hexColor) {
    String formattedHexColor = hexColor.toUpperCase().replaceAll('#', '');
    if (formattedHexColor.length == 6) {
      formattedHexColor = 'FF$formattedHexColor';
    }
    return int.parse(formattedHexColor, radix: 16);
  }
}
