import 'package:flutter/material.dart';
import 'package:mental_warior/models/tasks.dart';
import 'package:intl/intl.dart';

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

  static Widget whenDue(Task task) {
    String deadline = task.deadline;

    if (deadline.isEmpty) {
      return SizedBox.shrink();
    }

    DateTime deadlineDateTime = DateFormat("yyyy-MM-dd h:mm a").parse(deadline);

    DateTime now = DateTime.now();
    DateTime today = DateTime(
        now.year, now.month, now.day, now.hour, now.minute, now.second);
    DateTime tomorrow = today.add(Duration(days: 1));

    // Check conditions
    if (deadlineDateTime.year == today.year &&
        deadlineDateTime.month == today.month &&
        deadlineDateTime.day == today.day) {
      return Text(
        "Today",
      );
    } else if (deadlineDateTime.year == tomorrow.year &&
        deadlineDateTime.month == tomorrow.month &&
        deadlineDateTime.day == tomorrow.day) {
      return Text(
        "Tomorrow",
      );
    } else if (deadlineDateTime.isBefore(today)) {
      return Text(
        "Past Due",
      );
    } else {
      // Return the formatted date for other cases
      String formattedDate = DateFormat("d.M.").format(deadlineDateTime);
      return Text(formattedDate);
    }
  }
}
