import 'package:flutter/material.dart';

class Functions {
  String getTimeOfDayDescription() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "morning";
    } else if (hour < 18) {
      return "afternoon";
    } else {
      return "evening";
    }
  }

  static Future<void> dateAndTimePicker(
      BuildContext context, TextEditingController controller) async {
    controller.clear();

    DateTime? _pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 5000)),
    );

    TimeOfDay? _pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (_pickedDate != null && _pickedTime != null) {
      String formattedDate = _pickedDate.toString().split(" ")[0];
      String formattedTime = _pickedTime.toString().split("y")[1].trim();

      controller.text = "$formattedDate $formattedTime";
    }
  }
}
