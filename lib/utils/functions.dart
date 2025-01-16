import 'package:flutter/material.dart';

class Functions {
  String getTimeOfDayDescription() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Morning";
    } else if (hour < 18) {
      return "Afternoon";
    } else {
      return "Evening";
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
      String formattedDate = _pickedDate.toIso8601String().split("T")[0];
      String formattedTime = _pickedTime.format(context);

      controller.text = "$formattedDate $formattedTime";
    }
  }
}
