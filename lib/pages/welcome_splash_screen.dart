import 'dart:async';

import 'package:flutter/material.dart';

class WelcomeSplashScreen extends StatefulWidget {
  final String username;
  final VoidCallback onFinish;

  const WelcomeSplashScreen({Key? key, required this.username, required this.onFinish}) : super(key: key);

  @override
  State<WelcomeSplashScreen> createState() => _WelcomeSplashScreenState();
}

class _WelcomeSplashScreenState extends State<WelcomeSplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 700));
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    // Show the splash for a short duration, then pop and call onFinish.
    Timer(Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onFinish();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _opacity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Welcome,',
                  style: TextStyle(color: Colors.white54, fontSize: 22, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  widget.username,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                ),
                SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Text(
                    "You've got this — small, steady actions add up to real change.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
