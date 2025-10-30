import 'package:flutter/material.dart';

class CustomExerciseDetailPage extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final String exerciseEquipment;

  const CustomExerciseDetailPage({
    Key? key,
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseEquipment,
  }) : super(key: key);

  @override
  _CustomExerciseDetailPageState createState() => _CustomExerciseDetailPageState();
}

class _CustomExerciseDetailPageState extends State<CustomExerciseDetailPage> {
  // Theme colors consistent with the app
  final Color _backgroundColor = const Color(0xFF1A1B1E);
  final Color _surfaceColor = const Color(0xFF26272B);
  final Color _primaryColor = const Color(0xFF3F8EFC);
  final Color _textPrimaryColor = Colors.white;
  final Color _textSecondaryColor = const Color(0xFFBBBBBB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.exerciseName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _surfaceColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fitness_center,
                size: 64,
                color: _primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Custom Exercise Details',
                style: TextStyle(
                  color: _textPrimaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'This is a custom exercise page for:\n"${widget.exerciseName}"',
                style: TextStyle(
                  color: _textSecondaryColor,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Equipment: ${widget.exerciseEquipment}',
                style: TextStyle(
                  color: _textSecondaryColor,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Exercise ID: ${widget.exerciseId}',
                style: TextStyle(
                  color: _textSecondaryColor,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Custom exercise details and functionality will be implemented here.',
                  style: TextStyle(
                    color: _textPrimaryColor,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}