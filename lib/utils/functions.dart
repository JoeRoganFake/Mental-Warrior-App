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
      final combinedDateTime = DateTime(
        _pickedDate.year,
        _pickedDate.month,
        _pickedDate.day,
        _pickedTime.hour,
        _pickedTime.minute,
      );

      String formattedDateTime =
          "${combinedDateTime.toIso8601String().split('T')[0]} ${_pickedTime.format(context)}";

      controller.text = formattedDateTime;
    }
  }
}
