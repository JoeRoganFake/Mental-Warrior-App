import 'package:flutter/material.dart';

class MeditationPage extends StatefulWidget {
  @override
  _MeditationPageState createState() => _MeditationPageState();
}

class _MeditationPageState extends State<MeditationPage> {
  String? selectedMode;
  int? selectedDuration;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.spa_outlined, size: 70, color: Colors.blue),
                SizedBox(height: 10),
                Text(
                  "Get your focus back",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Choose your path to mental clarity.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                      child: _buildModeButton(
                          "Guided", Icons.headset, Colors.blue)),
                  SizedBox(width: 20),
                  Expanded(
                      child: _buildModeButton(
                          "Unguided", Icons.headset_off, Colors.green)),
                ],
              ),
            ),
          ),

          // Duration Selection Section
          Expanded(
            flex: 3,
            child: Column(
              children: [
                if (selectedMode != null) ...[
                  Text(
                    "How long would you like to grow today?",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),

                  // Grid of Duration Options
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [5, 10, 15, 20, 30, 45, 60].map((minutes) {
                        return _buildDurationButton(minutes);
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Start Button
                  if (selectedDuration != null)
                    ElevatedButton(
                      onPressed: _startMeditation,
                      child: Text("Start $selectedMode Meditation"),
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        textStyle: TextStyle(fontSize: 18),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Meditation Mode Button
  Widget _buildModeButton(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => setState(() => selectedMode = title),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(
          color: selectedMode == title ? color.withOpacity(0.9) : color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 6, spreadRadius: 2),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            SizedBox(height: 10),
            Text(title,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }

  /// Duration Button
  Widget _buildDurationButton(int minutes) {
    return ElevatedButton(
      onPressed: () => setState(() => selectedDuration = minutes),
      child: Text("$minutes min"),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Start Meditation Function
  void _startMeditation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MeditationSessionPage(
          mode: selectedMode!,
          duration: selectedDuration!,
        ),
      ),
    );
  }
}

/// Meditation Session Page (Placeholder)
class MeditationSessionPage extends StatelessWidget {
  final String mode;
  final int duration;

  MeditationSessionPage({required this.mode, required this.duration});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$mode Meditation")),
      body: Center(
        child: Text(
            "Meditating for $duration minutes...\n\nEmbrace the calm and clarity.",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
