import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/utils/app_theme.dart';
import 'home.dart';
import '../services/background_task_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // Setup animation for the logo
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();

    // Preload all necessary data
    _preloadData().then((_) {
      setState(() {
        _isLoading = false;
      });

      // Navigate to home page after data is loaded
      Timer(const Duration(milliseconds: 600), () {
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
      });
    });
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
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: AppTheme.gradientBackground(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Icon with glow effect
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: AppTheme.accentGradient,
                        borderRadius: AppTheme.borderRadiusXl,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.psychology_outlined,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // App name
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    "Mental Warrior",
                    textAlign: TextAlign.center,
                    style: AppTheme.displayMedium.copyWith(
                      letterSpacing: 1,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Tagline
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    "Build discipline. Grow stronger.",
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Loading indicator
                if (_isLoading)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.accent.withOpacity(0.8),
                        ),
                        strokeWidth: 3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
