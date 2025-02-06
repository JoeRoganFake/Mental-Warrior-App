import 'package:flutter/material.dart';
import 'package:mental_warior/models/tasks.dart';
import 'package:intl/intl.dart';

class Functions {
  String getTimeOfDayDescription({onlyDate = false}) {
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
      BuildContext context, TextEditingController controller,
      {bool onlyDate = false}) async {
    controller.clear();

    DateTime? _pickedDate = await showDatePicker(
      context: context,
      initialDate:
          onlyDate ? DateTime.now().add(Duration(days: 265)) : DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 5000000)),
    );

    if (_pickedDate != null) {
      if (onlyDate) {
        String formattedDate = _pickedDate.toIso8601String().split('T')[0];
        controller.text = formattedDate;
      } else {
        TimeOfDay? _pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );

        if (_pickedTime != null) {
          String formattedDateTime =
              "${_pickedDate.toIso8601String().split('T')[0]} ${_pickedTime.format(context)}";

          controller.text = formattedDateTime;
        }
      }
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
