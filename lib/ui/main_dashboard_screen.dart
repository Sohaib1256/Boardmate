import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import 'home_screen.dart';
import 'quiz_list_screen.dart';
import 'student_library_screen.dart';
import 'ai_tutor_screen.dart';
import 'profile_screen.dart';

class MainDashboardScreen extends StatefulWidget {
  final AppUser appUser;
  
  const MainDashboardScreen({super.key, required this.appUser});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // List of screens managed by IndexedStack
    final List<Widget> screens = [
      HomeScreen(appUser: widget.appUser),
      StudentLibraryScreen(appUser: widget.appUser),
      const SizedBox(), // Placeholder for index 2 (AI Tutor is now pushed as a new route)
      QuizListScreen(appUser: widget.appUser),
      ProfileScreen(appUser: widget.appUser),
    ];

    return Scaffold(
      extendBody: true, // Ensures screens render behind the floating nav bar
      resizeToAvoidBottomInset: false, // Prevents keyboard from shrinking the entire dashboard viewport
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildFloatingNavigationBar(),
    );
  }

  Widget _buildFloatingNavigationBar() {
    // Wrapped in SafeArea to handle device notches and bottom indicators gracefully
    return SafeArea(
      child: Container(
        height: 60,
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 25),
        decoration: BoxDecoration(
          color: Colors.white, // Themed background
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        // Stack to allow the AI Tutor button to overlap the top of the container
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildNavItem(icon: Icons.home_rounded, index: 0, label: "Home"),
                _buildNavItem(icon: Icons.menu_book_rounded, index: 1, label: "Resources"),
                // Placeholder width so standard icons wrap around the center overlapping button
                const SizedBox(width: 60), 
                _buildNavItem(icon: Icons.assignment_rounded, index: 3, label: "Quizzes"),
                _buildNavItem(icon: Icons.person_rounded, index: 4, label: "Profile"),
              ],
            ),
            // The "AI Tutor" Center Button physically popping out of the top
            Positioned(
              top: -20,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AiTutorScreen()),
                    );
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0083B0).withValues(alpha: 0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required int index, required String label}) {
    final bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withValues(alpha: 0.15) : Colors.transparent,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.blue : Colors.grey.shade400,
          size: 28,
        ),
      ),
    );
  }
}

