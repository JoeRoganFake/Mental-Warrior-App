import 'package:flutter/material.dart';

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
    const primaryColor = Color(0xFF3F8EFC);
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF1A1B1E),
        Color(0xFF26272B),
      ],
    );

    return Scaffold(
      backgroundColor: Color(0xFF1A1B1E),
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
                  ? Color(0xFF4CAF50) // Green when finished
                  : value <= 10
                      ? Color(0xFFE53935) // Red when almost done
                      : Colors.white; // White normally
              
              return Stack(
                children: [
                  // Back button
                  Positioned(
                    top: 16,
                    left: 16,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          value <= 0 ? 'Time\'s Up!' : 'Rest Time',
                          style: TextStyle(
                            fontSize: 28,
                            color: timeColor,
                            fontWeight: FontWeight.bold,
                          ),
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
                                        ? Color(0xFF4CAF50)
                                        : value <= 10
                                            ? Color(0xFFE53935)
                                            : primaryColor,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 64,
                                      color: timeColor,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  if (value > 0)
                                    Text(
                                      'remaining',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white70,
                                      ),
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
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF4CAF50),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                icon: Icon(Icons.check_circle),
                                label: Text('Continue Workout'),
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
        color: highlighted ? Color(0xFF3F8EFC) : Colors.white10,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: highlighted ? Colors.white : Colors.white70,
          size: 32,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
