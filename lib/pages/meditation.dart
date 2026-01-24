import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mental_warior/pages/meditation_coundown.dart';
import 'package:mental_warior/utils/app_theme.dart';

class MeditationPage extends StatefulWidget {
  const MeditationPage({super.key});

  @override
  MeditationPageState createState() => MeditationPageState();
}

class MeditationPageState extends State<MeditationPage> {
  String? selectedMode;
  final List<int> durations = [5, 10, 15, 20, 25, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.surface,
              AppTheme.background,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accent.withOpacity(0.3),
                    AppTheme.accent.withOpacity(0.1),
                  ],
                ),
              ),
              child: Icon(Icons.spa_outlined, size: 70, color: AppTheme.accent),
            ),
            SizedBox(height: 24),
            Text(
              "Recharge Your Mind",
              style: AppTheme.displayLarge,
            ),
            SizedBox(height: 8),
            Text(
              "Choose your meditation mode",
              style:
                  AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModeButton("Guided", Icons.headset, AppTheme.accent),
                SizedBox(width: 20),
                _buildModeButton(
                    "Unguided", Icons.self_improvement, AppTheme.success),
              ],
            ),
          ],
        ),
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withOpacity(0.7),
            ],
          ),
          borderRadius: AppTheme.borderRadiusLg,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 40),
            SizedBox(height: 10),
            Text(
              title,
              style: AppTheme.labelLarge.copyWith(color: Colors.white),
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
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusXl),
          title: Text("Select Duration", style: AppTheme.headlineSmall),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...durations.map((duration) => ListTile(
                      title:
                          Text("$duration minutes", style: AppTheme.bodyMedium),
                      onTap: () {
                        Navigator.pop(context);
                        _startMeditation(duration);
                      },
                    )),
                ListTile(
                  title: Text(
                    "Custom",
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.accent),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showCustomTimePicker();
                  },
                ),
              ],
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
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape:
                  RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusXl),
              title: Text("Set Custom Time", style: AppTheme.headlineSmall),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onLongPressStart: (_) {
                          timer =
                              Timer.periodic(Duration(milliseconds: 100), (t) {
                            if (customMinutes > 1) {
                              setDialogState(() => customMinutes--);
                            }
                          });
                        },
                        onLongPressEnd: (_) {
                          timer?.cancel();
                        },
                        child: IconButton(
                          icon: Icon(Icons.remove_circle_outline,
                              color: AppTheme.textSecondary),
                          onPressed: () {
                            if (customMinutes > 1) {
                              setDialogState(() => customMinutes--);
                            }
                          },
                        ),
                      ),
                      Text("$customMinutes min",
                          style: AppTheme.displayMedium),
                      GestureDetector(
                        onLongPressStart: (_) {
                          timer =
                              Timer.periodic(Duration(milliseconds: 50), (t) {
                            setDialogState(() => customMinutes++);
                          });
                        },
                        onLongPressEnd: (_) {
                          timer?.cancel();
                        },
                        child: IconButton(
                          icon: Icon(Icons.add_circle_outline,
                              color: AppTheme.textSecondary),
                          onPressed: () {
                            setDialogState(() => customMinutes++);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.borderRadiusMd),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _startMeditation(customMinutes);
                    },
                    child: Text("Start",
                        style:
                            AppTheme.labelLarge.copyWith(color: Colors.white)),
                  ),
                ],
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
