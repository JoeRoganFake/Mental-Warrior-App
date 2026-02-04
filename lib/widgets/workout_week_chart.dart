import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/utils/app_theme.dart';

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

    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 16),
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppTheme.surfaceBorder, width: 1),
        ),
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(0, 16, 25, 16), // reduced left padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 27.0),
                    child: Text(
                      'Workouts per week',
                      style: AppTheme.headlineMedium.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: AppTheme.textSecondary),
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

        // Use exact max value for geometric precision
        final double maxValue = maxCount.toDouble();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Y-axis labels
            // Y-axis labels aligned with grid lines and goal line
            SizedBox(
              height: constraints.maxHeight,
              width: 36,
              child: Stack(
                children: [
                  // Top label (maxCount)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Text('$maxCount',
                        style: AppTheme.bodySmall
                            .copyWith(color: AppTheme.textSecondary)),
                  ),
                  // Middle label ((maxCount/2).round())
                  Positioned(
                    top: (constraints.maxHeight / 2) - 8,
                    right: 0,
                    child: Text('${(maxCount / 2).round()}',
                        style: AppTheme.bodySmall
                            .copyWith(color: AppTheme.textSecondary)),
                  ),
                  // Bottom label (0)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Text('0',
                        style: AppTheme.bodySmall
                            .copyWith(color: AppTheme.textSecondary)),
                  ),
                  // Goal label (only if not overlapping with grid labels)
                  if (_weeklyGoal != maxCount &&
                      _weeklyGoal != 0 &&
                      _weeklyGoal != (maxCount / 2).round())
                    Positioned(
                      bottom:
                          (_weeklyGoal / maxValue) * constraints.maxHeight - 8,
                      right: 0,
                      child: Text('$_weeklyGoal',
                          style: AppTheme.bodySmall.copyWith(
                            color: const Color.fromARGB(255, 3, 91, 192),
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Bars and X-axis labels
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, innerConstraints) {
                        return Stack(
                          children: [
                            // Horizontal grid lines
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              top: 0,
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                      height: 1,
                                      color: AppTheme.textSecondary
                                          .withOpacity(0.1)),
                                  Container(
                                      height: 1,
                                      color: AppTheme.textSecondary
                                          .withOpacity(0.1)),
                                  Container(
                                      height: 1,
                                      color: AppTheme.textSecondary
                                          .withOpacity(0.1)),
                                ],
                              ),
                            ),
                            // Show only one line if goal and current are identical, otherwise show both
                            if (weeklyData.isNotEmpty &&
                                weeklyData.last.count == _weeklyGoal)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: (_weeklyGoal / maxValue) *
                                        innerConstraints.maxHeight -
                                    1,
                                child: Container(
                                  height: 2,
                                  color: AppTheme.success,
                                ),
                              )
                            else ...[
                              // Goal line
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: (_weeklyGoal / maxValue) *
                                        innerConstraints.maxHeight -
                                    1,
                                child: Container(
                                  height: 2,
                                  color: const Color.fromARGB(255, 3, 91, 192),
                                ),
                              ),
                              // Current week line
                              if (weeklyData.isNotEmpty)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: (weeklyData.last.count / maxValue) *
                                          innerConstraints.maxHeight -
                                      1,
                                  child: Container(
                                    height: 2,
                                    color: weeklyData.last.count >= _weeklyGoal
                                        ? AppTheme.success
                                        : const Color.fromARGB(255, 3, 91, 192),
                                  ),
                                ),
                            ],
                            // Bars
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: weeklyData.map((week) {
                                final double barHeight = week.count > 0
                                    ? (week.count / maxValue) *
                                        innerConstraints.maxHeight
                                    : 0;

                                // Determine bar color based on goal achievement
                                final Color barColor = week.count >= _weeklyGoal
                                    ? AppTheme.success // Goal achieved
                                    : const Color.fromARGB(
                                        255, 3, 91, 192); // Goal not achieved

                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: barWidth *
                                          0.7, // 70% of available width
                                      height: barHeight > 0 ? barHeight : 0,
                                      decoration: barHeight > 0
                                          ? BoxDecoration(
                                              color: Colors.black,
                                              border: Border.all(
                                                color: barColor,
                                                width: 2,
                                              ),
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(6),
                                                topRight: Radius.circular(6),
                                              ),
                                            )
                                          : null,
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      },
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
                          style: AppTheme.bodySmall.copyWith(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
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
      // Calculate the first day of the week (Monday)
      final DateTime today = currentDate.subtract(Duration(days: 7 * i));
      final int daysFromMonday = (today.weekday - DateTime.monday) % 7;
      final DateTime weekStart = today.subtract(Duration(days: daysFromMonday));
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
