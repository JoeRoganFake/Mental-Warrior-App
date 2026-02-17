import 'package:flutter/material.dart';
import 'package:mental_warior/models/user_xp.dart';
import 'package:mental_warior/utils/app_theme.dart';
import 'dart:math' as math;
import 'dart:ui';

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
  late AnimationController _shimmerController;
  late AnimationController _raysController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _textRevealAnimation;
  late Animation<double> _levelRevealAnimation;
  late Animation<double> _rankRevealAnimation;
  late Animation<double> _xpRevealAnimation;
  late Animation<double> _blurAnimation;
  
  final List<Particle> _particles = [];
  final List<Particle> _floatingParticles = [];

  @override
  void initState() {
    super.initState();

    // Main animation controller - longer for elegance
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );

    // Particle animation controller
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );

    // Shimmer effect controller
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    // Rays animation controller
    _raysController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // Elegant scale animation with elastic effect
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 0.98)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.98, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 25,
      ),
    ]).animate(_controller);

    // Smooth fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );

    // Smooth glow pulse
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.7)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    // Icon scale with delay
    _iconScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.5, curve: Curves.elasticOut),
      ),
    );

    // Staggered text reveals for dramatic effect
    _textRevealAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _levelRevealAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _rankRevealAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _xpRevealAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    // Backdrop blur animation
    _blurAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // Generate particles
    _generateParticles();
    _generateFloatingParticles();

    // Start animations
    _controller.forward();
    _particleController.repeat();
    _shimmerController.repeat();
    _raysController.repeat();

    // Auto dismiss after animation - longer duration
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _generateParticles() {
    final random = math.Random();
    // More particles for a richer effect
    for (int i = 0; i < 80; i++) {
      _particles.add(
        Particle(
          x: random.nextDouble() * 2 - 1, // -1 to 1
          y: random.nextDouble() * 2 - 1,
          size: random.nextDouble() * 4 + 1, // 1 to 5 - smaller for elegance
          speed: random.nextDouble() * 0.4 + 0.3, // 0.3 to 0.7 - slower
          color: _getRandomParticleColor(random),
          opacity: random.nextDouble() * 0.5 + 0.5, // varied opacity
        ),
      );
    }
  }

  void _generateFloatingParticles() {
    final random = math.Random();
    // Floating particles that move slowly
    for (int i = 0; i < 30; i++) {
      _floatingParticles.add(
        Particle(
          x: random.nextDouble() * 2 - 1,
          y: random.nextDouble() * 2 - 1,
          size: random.nextDouble() * 3 + 0.5,
          speed: random.nextDouble() * 0.2 + 0.1,
          color: _getRandomParticleColor(random),
          opacity: random.nextDouble() * 0.3 + 0.2,
        ),
      );
    }
  }

  Color _getRandomParticleColor(math.Random random) {
    final rankColor = UserXP.getRankColor(widget.newRank);
    final colors = [
      rankColor,
      rankColor.withOpacity(0.8),
      rankColor.withOpacity(0.6),
      Colors.white.withOpacity(0.9),
      Colors.white.withOpacity(0.7),
    ];
    return colors[random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    _particleController.dispose();
    _shimmerController.dispose();
    _raysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rankColor = UserXP.getRankColor(widget.newRank);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // Animated backdrop blur
            AnimatedBuilder(
              animation: _blurAnimation,
              builder: (context, child) {
                return BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _blurAnimation.value,
                    sigmaY: _blurAnimation.value,
                  ),
                  child: Container(
                    color: Colors.black.withOpacity(0.6 * _fadeAnimation.value),
                  ),
                );
              },
            ),
            // Radial rays effect
            AnimatedBuilder(
              animation: _raysController,
              builder: (context, child) {
                return CustomPaint(
                  painter: RaysPainter(
                    progress: _raysController.value,
                    color: rankColor,
                    opacity: _fadeAnimation.value * 0.3,
                  ),
                  size: Size.infinite,
                );
              },
            ),
            // Expanding particles
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
            // Floating shimmer particles
            AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, child) {
                return CustomPaint(
                  painter: FloatingParticlePainter(
                    particles: _floatingParticles,
                    progress: _shimmerController.value,
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
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Central glow with multiple layers
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer glow
                            Container(
                              width: 280 * _glowAnimation.value,
                              height: 280 * _glowAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    rankColor.withOpacity(
                                        0.15 * _glowAnimation.value),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            // Middle glow ring
                            Container(
                              width: 180 * _glowAnimation.value,
                              height: 180 * _glowAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    rankColor.withOpacity(
                                        0.3 * _glowAnimation.value),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            // Icon container with elegant scaling
                            Transform.scale(
                              scale: _iconScaleAnimation.value,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      rankColor.withOpacity(0.9),
                                      rankColor.withOpacity(0.6),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: rankColor.withOpacity(0.5),
                                      blurRadius: 30,
                                      spreadRadius: 8,
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.3),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.auto_awesome,
                                  size: 70,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),

                        // "Rank Advanced" text with elegant reveal
                        Transform.translate(
                          offset:
                              Offset(0, 20 * (1 - _textRevealAnimation.value)),
                          child: Opacity(
                            opacity: _textRevealAnimation.value,
                            child: Text(
                              'Rank Advanced',
                              style: AppTheme.displayLarge.copyWith(
                                letterSpacing: 3,
                                shadows: [
                                  Shadow(
                                    color: rankColor.withOpacity(0.5),
                                    blurRadius: 15,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // New level with elegant card
                        Transform.translate(
                          offset:
                              Offset(0, 20 * (1 - _levelRevealAnimation.value)),
                          child: Opacity(
                            opacity: _levelRevealAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    rankColor.withOpacity(0.25),
                                    rankColor.withOpacity(0.15),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: rankColor.withOpacity(0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: rankColor.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Rank',
                                    style: AppTheme.bodyLarge.copyWith(
                                      letterSpacing: 2,
                                      color:
                                          AppTheme.textPrimary.withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          rankColor,
                                          rankColor.withOpacity(0.7),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${widget.newLevel}',
                                      style: AppTheme.displayMedium.copyWith(
                                        letterSpacing: 0.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Rank badge with elegant styling
                        Transform.translate(
                          offset:
                              Offset(0, 20 * (1 - _rankRevealAnimation.value)),
                          child: Opacity(
                            opacity: _rankRevealAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: rankColor.withOpacity(0.6),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: rankColor.withOpacity(0.2),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: Text(
                                widget.newRank.toUpperCase(),
                                style: AppTheme.displaySmall.copyWith(
                                  letterSpacing: 3,
                                  color: rankColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // XP gained with subtle animation
                        Transform.translate(
                          offset:
                              Offset(0, 20 * (1 - _xpRevealAnimation.value)),
                          child: Opacity(
                            opacity: _xpRevealAnimation.value * 0.8,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  size: 18,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${widget.xpGained} XP',
                                  style: AppTheme.titleMedium.copyWith(
                                    color: AppTheme.textSecondary,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 56),

                        // Tap to continue hint with fade
                        Opacity(
                          opacity: _xpRevealAnimation.value * 0.5,
                          child: Text(
                            'Tap to continue',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textTertiary.withOpacity(0.6),
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
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

// Particle model with opacity
class Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final Color color;
  final double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.color,
    this.opacity = 1.0,
  });
}

// Custom painter for expanding particles
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
      final distance = progress * 450 * particle.speed;
      final x = centerX + (particle.x * distance);
      final y = centerY + (particle.y * distance);

      // Elegant fade out curve
      final fadeProgress = (1.0 - progress).clamp(0.0, 1.0);
      final opacity =
          (fadeProgress * fadeProgress * particle.opacity).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = particle.color.withOpacity(opacity)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

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

// Custom painter for floating shimmer particles
class FloatingParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;

  FloatingParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (int i = 0; i < particles.length; i++) {
      final particle = particles[i];

      // Circular floating motion
      final angle = progress * 2 * math.pi + (i * 0.5);
      final radius = 200 + (particle.speed * 100);
      final x = centerX + (math.cos(angle + particle.x) * radius);
      final y = centerY + (math.sin(angle + particle.y) * radius);

      // Pulsing opacity
      final pulseOpacity = (math.sin(progress * 2 * math.pi + i) * 0.3 + 0.7);
      final opacity = (particle.opacity * pulseOpacity).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = particle.color.withOpacity(opacity)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawCircle(
        Offset(x, y),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(FloatingParticlePainter oldDelegate) => true;
}

// Custom painter for radial rays
class RaysPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double opacity;

  RaysPainter({
    required this.progress,
    required this.color,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final rayCount = 12;

    for (int i = 0; i < rayCount; i++) {
      final angle = (i / rayCount) * 2 * math.pi + (progress * 0.5);

      // Ray parameters
      final rayLength = size.width * 0.8;
      final rayWidth = 2.0;

      // Calculate ray endpoints
      final startRadius = 100.0;
      final x1 = centerX + math.cos(angle) * startRadius;
      final y1 = centerY + math.sin(angle) * startRadius;
      final x2 = centerX + math.cos(angle) * rayLength;
      final y2 = centerY + math.sin(angle) * rayLength;

      // Gradient for ray
      final gradient = LinearGradient(
        colors: [
          color.withOpacity(opacity * 0.4),
          color.withOpacity(0),
        ],
      );

      final rect = Rect.fromPoints(
        Offset(x1, y1),
        Offset(x2, y2),
      );

      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = rayWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(RaysPainter oldDelegate) =>
      progress != oldDelegate.progress || opacity != oldDelegate.opacity;
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
