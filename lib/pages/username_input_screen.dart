import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mental_warior/pages/welcome_splash_screen.dart';

class UsernameInputScreen extends StatefulWidget {
  final void Function(String username) onSubmit;
  const UsernameInputScreen({Key? key, required this.onSubmit}) : super(key: key);

  @override
  State<UsernameInputScreen> createState() => _UsernameInputScreenState();
}

class _UsernameInputScreenState extends State<UsernameInputScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'What should we call you?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 50),
              LayoutBuilder(
                builder: (context, constraints) {
                  final lineWidth = constraints.maxWidth * 0.75;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: lineWidth),
                          child: TextField(
                            controller: _controller,
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              hintText: 'Your name',
                              hintStyle: TextStyle(color: Colors.white54, fontSize: 20),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: Colors.transparent,
                            ),
                            cursorColor: Colors.white,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(top: 6),
                        width: lineWidth,
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.grey.shade300, Colors.black],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 70),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white, width: 2),
                  padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  foregroundColor: Colors.white,
                  textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  final name = _controller.text.trim();
                  if (name.isNotEmpty) {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        opaque: false,
                        pageBuilder: (context, a1, a2) => WelcomeSplashScreen(
                          username: name,
                          onFinish: () {
                            widget.onSubmit(name);
                          },
                        ),
                        transitionsBuilder: (context, a1, a2, child) {
                          return FadeTransition(opacity: a1, child: child);
                        },
                      ),
                    );
                  }
                },
                child: Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
