import 'package:flutter/material.dart';

class XPGainBubble extends StatefulWidget {
  final int xpAmount;
  final Offset position;

  const XPGainBubble({
    Key? key,
    required this.xpAmount,
    required this.position,
  }) : super(key: key);

  @override
  State<XPGainBubble> createState() => _XPGainBubbleState();
}

class _XPGainBubbleState extends State<XPGainBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Fade in quickly, stay visible, then fade out
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);

    // Slide upward
    _slideAnimation = Tween<double>(begin: 0.0, end: -80.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Scale bounce effect
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 65,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.position.dx - 40, // Center the bubble
          top: widget.position.dy + _slideAnimation.value - 20,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.xpAmount >= 0
                        ? [
                            Colors.amber.shade400,
                            Colors.orange.shade500,
                          ]
                        : [
                            Colors.red.shade400,
                            Colors.red.shade600,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.xpAmount >= 0 
                          ? Colors.amber 
                          : Colors.red).withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.xpAmount >= 0 ? Icons.star : Icons.remove_circle,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.xpAmount >= 0 ? '+' : ''}${widget.xpAmount} XP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Function to show XP gain bubble as an overlay
void showXPGainBubble(BuildContext context, int xpAmount) {
  final overlay = Overlay.of(context);
  final renderBox = context.findRenderObject() as RenderBox?;
  
  if (renderBox == null) return;
  
  // Get the position of the widget that triggered this
  final position = renderBox.localToGlobal(Offset.zero);
  final size = renderBox.size;
  
  // Position the bubble at the center of the triggering widget
  final bubblePosition = Offset(
    position.dx + size.width / 2,
    position.dy + size.height / 2,
  );

  late OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => XPGainBubble(
      xpAmount: xpAmount,
      position: bubblePosition,
    ),
  );

  overlay.insert(overlayEntry);

  // Remove the overlay after animation completes
  Future.delayed(const Duration(milliseconds: 2000), () {
    overlayEntry.remove();
  });
}

// Alternative: Show XP bubble at a specific screen position
void showXPGainBubbleAt(BuildContext context, int xpAmount, Offset position) {
  final overlay = Overlay.of(context);

  late OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => XPGainBubble(
      xpAmount: xpAmount,
      position: position,
    ),
  );

  overlay.insert(overlayEntry);

  // Remove the overlay after animation completes
  Future.delayed(const Duration(milliseconds: 2000), () {
    overlayEntry.remove();
  });
}
