import 'package:flutter/material.dart';
import 'package:mental_warior/models/user_xp.dart';
import 'dart:math' as math;

class LevelUpAnimation extends StatefulWidget {
  final int newLevel;
  final String newRank;
  final int xpGained;

  const LevelUpAnimation({
    Key? key,
    required this.newLevel,
    required this.newRank,
    required this.xpGained,
  }) : super(key: key);

  @override
  State<LevelUpAnimation> createState() => _LevelUpAnimationState();
}

class _LevelUpAnimationState extends State<LevelUpAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _particleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;
  final List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();

    // Main animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Particle animation controller
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Scale animation (bounce effect)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 0.95)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ]).animate(_controller);

    // Fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // Glow animation (pulsing effect)
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Generate particles
    _generateParticles();

    // Start animations
    _controller.forward();
    _particleController.repeat();

    // Auto dismiss after animation
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _generateParticles() {
    final random = math.Random();
    for (int i = 0; i < 50; i++) {
      _particles.add(
        Particle(
          x: random.nextDouble() * 2 - 1, // -1 to 1
          y: random.nextDouble() * 2 - 1,
          size: random.nextDouble() * 6 + 2, // 2 to 8
          speed: random.nextDouble() * 0.5 + 0.5, // 0.5 to 1.0
          color: _getRandomParticleColor(random),
        ),
      );
    }
  }

  Color _getRandomParticleColor(math.Random random) {
    final colors = [
      Colors.amber,
      Colors.orange,
      Colors.yellow,
      Colors.purple,
      Colors.pink,
      Colors.blue,
      UserXP.getRankColor(widget.newRank),
    ];
    return colors[random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rankColor = UserXP.getRankColor(widget.newRank);

    return Material(
      color: Colors.black.withOpacity(0.8),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // Animated particles
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: ParticlePainter(
                    particles: _particles,
                    progress: _particleController.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),
            // Main content
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Glow effect
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: rankColor.withOpacity(
                                      0.4 * _glowAnimation.value),
                                  blurRadius: 80 * _glowAnimation.value,
                                  spreadRadius: 30 * _glowAnimation.value,
                                ),
                              ],
                            ),
                          ),
                          // Level up icon
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  rankColor,
                                  rankColor.withOpacity(0.7),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: rankColor.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.military_tech,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 30),
                          // "LEVEL UP!" text
                          Text(
                            'LEVEL UP!',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: rankColor,
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // New level
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  rankColor,
                                  rankColor.withOpacity(0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: rankColor.withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              'Level ${widget.newLevel}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Rank badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: rankColor.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: rankColor,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              widget.newRank,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: rankColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // XP gained
                          Text(
                            '+${widget.xpGained} XP',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[300],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 40),
                          // Tap to dismiss hint
                          Text(
                            'Tap to continue',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Particle model
class Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final Color color;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.color,
  });
}

// Custom painter for particles
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;

  ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (final particle in particles) {
      // Calculate particle position based on progress
      final distance = progress * 500 * particle.speed;
      final x = centerX + (particle.x * distance);
      final y = centerY + (particle.y * distance);

      // Fade out as particles move away
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = particle.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x, y),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

// Function to show level up animation
void showLevelUpAnimation(
  BuildContext context, {
  required int newLevel,
  required String newRank,
  required int xpGained,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (context) => LevelUpAnimation(
      newLevel: newLevel,
      newRank: newRank,
      xpGained: xpGained,
    ),
  );
}
