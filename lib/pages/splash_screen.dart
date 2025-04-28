import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mental_warior/services/database_services.dart';
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
  late Animation<double> _animation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // Setup animation for the logo
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();

    // Preload all necessary data
    _preloadData().then((_) {
      setState(() {
        _isLoading = false;
      });

      // Navigate to home page after data is loaded
      Timer(const Duration(milliseconds: 500), () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomePage()),
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
      backgroundColor: const Color(0xFFF9F9F9), // Light soft background
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Elegant text
              FadeTransition(
                opacity: _animation,
                child: const Text(
                  "Mental Warrior",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222), // Very dark grey, not pure black
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Simple loading indicator
              if (_isLoading)
                FadeTransition(
                  opacity: _animation,
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF3A86FF)), // Soft blue
                    strokeWidth: 3,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
