import 'package:flutter/material.dart';
import 'package:mental_warior/utils/app_theme.dart';

/// Full-screen rest timer with circular countdown indicator
class RestTimerPage extends StatelessWidget {
  final int originalDuration;
  final ValueNotifier<int> remaining;
  final ValueNotifier<bool> isPaused;
  final VoidCallback onPause;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onSkip;
  const RestTimerPage({
    super.key,
    required this.originalDuration,
    required this.remaining,
    required this.isPaused,
    required this.onPause,
    required this.onIncrement,
    required this.onDecrement,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppTheme.surface,
        AppTheme.background,
      ],
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(gradient: bgGradient),
          child: ValueListenableBuilder<int>(
            valueListenable: remaining,
            builder: (context, value, child) {
              final progress = value / originalDuration;
              Duration format(int sec) => Duration(seconds: sec);
              final minutes = format(value).inMinutes;
              final secs = format(value).inSeconds % 60;
              
              final timeColor = value <= 0
                  ? AppTheme.success // Green when finished
                  : value <= 10
                      ? AppTheme.error // Red when almost done
                      : AppTheme.textPrimary; // White normally
              
              return Stack(
                children: [
                  // Back button
                  Positioned(
                    top: 16,
                    left: 16,
                    child: IconButton(
                      icon:
                          Icon(Icons.arrow_back, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          value <= 0 ? 'Time\'s Up!' : 'Rest Time',
                          style: AppTheme.headlineMedium
                              .copyWith(color: timeColor),
                        ),
                        SizedBox(height: 24),

                        // Timer display
                        Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black26,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 240,
                                height: 240,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 16,
                                  backgroundColor: Colors.white10,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    value <= 0
                                        ? AppTheme.success
                                        : value <= 10
                                            ? AppTheme.error
                                            : AppTheme.accent,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                                    style: AppTheme.displayLarge.copyWith(
                                      color: timeColor,
                                      fontSize: 64,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  if (value > 0)
                                    Text(
                                      'remaining',
                                      style: AppTheme.bodyMedium.copyWith(
                                          color: AppTheme.textSecondary),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 40),
                        
                        if (value <= 0)
                          Column(
                            children: [
                              Text(
                                'Ready to continue?',
                                style: AppTheme.bodyMedium
                                    .copyWith(color: AppTheme.textSecondary),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppTheme.borderRadiusMd,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                icon: Icon(Icons.check_circle),
                                label: Text('Continue Workout',
                                    style: AppTheme.labelLarge
                                        .copyWith(color: Colors.white)),
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _TimerControlButton(
                                icon: Icons.remove,
                                onPressed: onDecrement,
                              ),
                              SizedBox(width: 24),
                              ValueListenableBuilder<bool>(
                                valueListenable: isPaused,
                                builder: (_, paused, __) => _TimerControlButton(
                                  icon: paused ? Icons.play_arrow : Icons.pause,
                                  highlighted: true,
                                  onPressed: onPause,
                                ),
                              ),
                              SizedBox(width: 24),
                              _TimerControlButton(
                                icon: Icons.add,
                                onPressed: onIncrement,
                              ),
                            ],
                          ),
                          
                        SizedBox(height: 32),
                        if (value > 0)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () {
                              onSkip();
                              Navigator.of(context).pop();
                            },
                            icon: Icon(Icons.skip_next),
                            label: Text('Skip Rest'),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TimerControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool highlighted;

  const _TimerControlButton({
    required this.icon,
    required this.onPressed,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlighted ? AppTheme.accent : Colors.white10,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: highlighted ? Colors.white : AppTheme.textSecondary,
          size: 32,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
