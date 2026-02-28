import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/services/user_preferences.dart';
import 'username_input_screen.dart';

import 'home.dart';
import '../services/background_task_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _logoFadeController;
  late Animation<double> _logoFadeAnimation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    _logoFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _logoFadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoFadeController, curve: Curves.easeInOut),
    );

    _handleStartup();
  }

  Future<void> _handleStartup() async {
    final startTime = DateTime.now();
    await _preloadData();
    final elapsed = DateTime.now().difference(startTime);
    final minDuration = const Duration(seconds: 2);
    final remaining = minDuration - elapsed;
    await Future.delayed(remaining > Duration.zero ? remaining : Duration.zero);

    final username = await UserPreferences.getUsername();
    if (username == null || username.isEmpty) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => UsernameInputScreen(
              onSubmit: (name) async {
                await UserPreferences.setUsername(name);
                Navigator.of(context).pushReplacement(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        HomePage(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                );
              },
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => HomePage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    }
  }

  Future<void> _preloadData() async {
    // Preload all the data that HomePage needs
    final taskService = TaskService();
    final completedTaskService = CompletedTaskService();
    final habitService = HabitService();
    final goalService = GoalService();
    final bookService = BookService();
    final categoryService = CategoryService();

    // Perform all data loading in parallel
    await Future.wait([
      taskService.getTasks(),
      completedTaskService.getCompletedTasks(),
      habitService.getHabits(),
      goalService.getGoals(),
      bookService.getBooks(),
      categoryService.getCategories(),
      BackgroundTaskManager.getStoredDailyQuote(),
    ]);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _logoFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Fading logo animation with glare behind it
              FadeTransition(
                opacity: _fadeAnimation,
                child: AnimatedBuilder(
                  animation: _logoFadeAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _isLoading ? _logoFadeAnimation.value : 1.0,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glare (glow effect)
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.18),
                                  blurRadius: 60,
                                  spreadRadius: 30,
                                ),
                              ],
                            ),
                          ),
                          // Logo
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/icons/mv_logo.png',
                                width: 110,
                                height: 110,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 38),

              // App name with fade-in
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  "Mental Warrior",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Tagline with fade-in
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  "Build discipline. Grow stronger.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
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
