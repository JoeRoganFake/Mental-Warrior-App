import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:mental_warior/pages/meditation_coundown.dart';
import 'package:mental_warior/utils/app_theme.dart';

class MeditationPage extends StatefulWidget {
  const MeditationPage({super.key});

  @override
  MeditationPageState createState() => MeditationPageState();
}

class MeditationPageState extends State<MeditationPage>
    with SingleTickerProviderStateMixin {
  String? selectedMode;
  final List<int> durations = [5, 10, 15, 20, 25, 30, 45, 60];
  late AnimationController _animationController;
  late Animation<double> _animation;
  final int _patternSeed = Random().nextInt(10000);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationController.reset();
    _animationController.forward();
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
      body: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.accent.withOpacity(0.0005),
                      AppTheme.background,
                    ],
                  ),
                ),
              ),
              CustomPaint(
                painter: RandomPatternPainter(
                  seed: _patternSeed,
                  animationValue: _animation.value,
                ),
                size: Size.infinite,
              ),
              Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.accent.withOpacity(0.02),
                              AppTheme.accent.withOpacity(0.005),
                            ],
                          ),
                        ),
                        child: Icon(Icons.spa_outlined,
                            size: 70, color: AppTheme.accent),
                      ),
                      SizedBox(height: 24),
                      Text(
                        "Recharge Your Mind",
                        style: AppTheme.displayLarge,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Choose your meditation mode",
                        style: AppTheme.bodyMedium
                            .copyWith(color: AppTheme.textSecondary),
                      ),
                      SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildModeButton(
                              "Guided", Icons.headset, AppTheme.accent),
                          SizedBox(width: 20),
                          _buildModeButton("Unguided", Icons.self_improvement,
                              AppTheme.success),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModeButton(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMode = title;
        });
        _showDurationSelection();
      },
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: AppTheme.borderRadiusLg,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.015),
              color.withOpacity(0.003),
            ],
          ),
          border: Border.all(
            color: color.withOpacity(0.1),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 40),
            SizedBox(height: 10),
            Text(
              title,
              style: AppTheme.labelLarge.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  void _showDurationSelection() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Select Duration",
                    style: AppTheme.headlineMedium.copyWith(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...durations.map((duration) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    _startMeditation(duration);
                                  },
                                  borderRadius: AppTheme.borderRadiusMd,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceLight,
                                      borderRadius: AppTheme.borderRadiusMd,
                                      border: Border.all(
                                        color: AppTheme.surfaceBorder,
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "$duration minutes",
                                        style: AppTheme.bodyMedium.copyWith(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )),
                        const SizedBox(height: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _showCustomTimePicker();
                            },
                            borderRadius: AppTheme.borderRadiusMd,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.accent.withOpacity(0.02),
                                    AppTheme.accent.withOpacity(0.005),
                                  ],
                                ),
                                borderRadius: AppTheme.borderRadiusMd,
                                border: Border.all(
                                  color: AppTheme.accent.withOpacity(0.08),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  "Custom",
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCustomTimePicker() {
    int customMinutes = 5;
    Timer? timer;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: AppTheme.surface,
              shape:
                  RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusLg),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Set Custom Time",
                      style: AppTheme.headlineMedium.copyWith(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: AppTheme.borderRadiusMd,
                        border: Border.all(
                          color: AppTheme.surfaceBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onLongPressStart: (_) {
                              timer = Timer.periodic(
                                  Duration(milliseconds: 100), (t) {
                                if (customMinutes > 1) {
                                  setDialogState(() => customMinutes--);
                                }
                              });
                            },
                            onLongPressEnd: (_) {
                              timer?.cancel();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.surfaceBorder,
                                  width: 1,
                                ),
                              ),
                              child: IconButton(
                                icon: Icon(Icons.remove_rounded,
                                    color: AppTheme.accent, size: 24),
                                onPressed: () {
                                  if (customMinutes > 1) {
                                    setDialogState(() => customMinutes--);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Column(
                            children: [
                              Text(
                                "$customMinutes",
                                style: AppTheme.displayLarge.copyWith(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accent,
                                ),
                              ),
                              Text(
                                "minutes",
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onLongPressStart: (_) {
                              timer = Timer.periodic(Duration(milliseconds: 50),
                                  (t) {
                                setDialogState(() => customMinutes++);
                              });
                            },
                            onLongPressEnd: (_) {
                              timer?.cancel();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.surfaceBorder,
                                  width: 1,
                                ),
                              ),
                              child: IconButton(
                                icon: Icon(Icons.add_rounded,
                                    color: AppTheme.accent, size: 24),
                                onPressed: () {
                                  setDialogState(() => customMinutes++);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: AppTheme.borderRadiusMd),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _startMeditation(customMinutes);
                        },
                        child: Text(
                          "Start Meditation",
                          style: AppTheme.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _startMeditation(int minutes) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MeditationCountdownScreen(duration: minutes, mode: selectedMode!),
      ),
    );
  }
}

class RandomPatternPainter extends CustomPainter {
  final int seed;
  final double animationValue;
  late final Random random;

  RandomPatternPainter({required this.seed, required this.animationValue}) {
    random = Random(seed);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw subtle scattered dots like home page
    for (int i = 0; i < 25; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.5 + 0.5;

      final paint = Paint()
        ..color = AppTheme.accent.withOpacity(0.002 * animationValue)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(RandomPatternPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.animationValue != animationValue;
}
