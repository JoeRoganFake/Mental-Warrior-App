import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:mental_warior/services/database_services.dart';

class WorkoutWeekChart extends StatefulWidget {
  final List<Workout> workouts;
  final Function onChangeGoal;

  const WorkoutWeekChart({
    super.key,
    required this.workouts,
    required this.onChangeGoal,
  });

  @override
  State<WorkoutWeekChart> createState() => _WorkoutWeekChartState();
}

class _WorkoutWeekChartState extends State<WorkoutWeekChart> {
  int _weeklyGoal = 5; // Default goal
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadWeeklyGoal();

    // Listen for settings changes
    SettingsService.settingsUpdatedNotifier.addListener(_onSettingsUpdated);
  }

  @override
  void dispose() {
    SettingsService.settingsUpdatedNotifier.removeListener(_onSettingsUpdated);
    super.dispose();
  }

  void _onSettingsUpdated() {
    _loadWeeklyGoal();
  }

  Future<void> _loadWeeklyGoal() async {
    final goal = await _settingsService.getWeeklyWorkoutGoal();
    setState(() {
      _weeklyGoal = goal;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Generate data for the past 8 weeks (including current week)
    final DateTime now = DateTime.now();
    final List<WeekData> weeklyData = _generateWeeklyData(now);

    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.transparent,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Workouts per week',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => widget.onChangeGoal(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildChart(weeklyData),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<WeekData> weeklyData) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double barWidth = (constraints.maxWidth - 40) / weeklyData.length;

        // Find the max count to properly scale the chart
        int maxCount = _weeklyGoal;
        for (var week in weeklyData) {
          if (week.count > maxCount) {
            maxCount = week.count;
          }
        }

        // Add 20% more space above the max value for better visualization
        final double maxValue = (maxCount * 1.2).ceilToDouble();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Y-axis labels
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$maxCount'),
                Text('${(maxCount / 2).round()}'),
                const Text('0'),
              ],
            ),
            const SizedBox(width: 10),
            // Bars and X-axis labels
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        // Goal line
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: (_weeklyGoal / maxValue) *
                              constraints.maxHeight *
                              0.9,
                          child: Container(
                            height: 1,
                            color: Colors.grey.withOpacity(0.5),
                          ),
                        ),
                        // Goal label
                        Positioned(
                          right: 0,
                          bottom: (_weeklyGoal / maxValue) *
                                  constraints.maxHeight *
                                  0.9 +
                              2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              'Goal: $_weeklyGoal',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                        // Bars
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: weeklyData.map((week) {
                            final double barHeight = week.count > 0
                                ? (week.count / maxValue) *
                                    constraints.maxHeight *
                                    0.9
                                : 0;

                            // Determine bar color based on goal achievement
                            final Color barColor = week.count >= _weeklyGoal
                                ? Colors.purple.shade800 // Goal achieved
                                : Colors.purple.shade400; // Goal not achieved

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  width:
                                      barWidth * 0.7, // 70% of available width
                                  height: barHeight == 0 ? 2 : barHeight,
                                  decoration: BoxDecoration(
                                    color: barColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: weeklyData.map((week) {
                      return SizedBox(
                        width: barWidth * 0.7,
                        child: Text(
                          '${week.startDate.month}/${week.startDate.day}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<WeekData> _generateWeeklyData(DateTime currentDate) {
    List<WeekData> weeklyData = [];

    // Generate data for the past 8 weeks
    for (int i = 7; i >= 0; i--) {
      // Calculate the first day of the week (Sunday)
      final DateTime weekStart =
          currentDate.subtract(Duration(days: currentDate.weekday + (7 * i)));
      final DateTime weekEnd = weekStart.add(const Duration(days: 6));

      // Count workouts in this week
      int count = 0;
      for (final workout in widget.workouts) {
        try {
          final workoutDate = DateFormat('yyyy-MM-dd').parse(workout.date);
          if (workoutDate
                  .isAfter(weekStart.subtract(const Duration(days: 1))) &&
              workoutDate.isBefore(weekEnd.add(const Duration(days: 1)))) {
            count++;
          }
        } catch (e) {
          // Skip invalid dates
        }
      }

      weeklyData.add(WeekData(weekStart, count));
    }

    return weeklyData;
  }
}

class WeekData {
  final DateTime startDate;
  final int count;

  WeekData(this.startDate, this.count);
}
