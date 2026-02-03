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

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate:
          onlyDate ? DateTime.now().add(Duration(days: 265)) : DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 5000000)),
    );

    if (pickedDate != null) {
      if (onlyDate) {
        String formattedDate = pickedDate.toIso8601String().split('T')[0];
        controller.text = formattedDate;
      } else {
        TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );

        if (pickedTime != null) {
          String formattedDateTime =
              "${pickedDate.toIso8601String().split('T')[0]} ${pickedTime.format(context)}";

          controller.text = formattedDateTime;
        }
      }
    }
  }

  static Widget whenDue(Task task) {
    try {
      if (task.deadline.trim().isEmpty) {
        return const SizedBox();
      }

      final parts = task.deadline.split(' ');
      final dateStr = parts[0];

      final DateTime deadline = DateTime.parse(dateStr);

      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);
      final DateTime tomorrow = today.add(const Duration(days: 1));

      if (deadline.isBefore(today)) {
        return const Text(
          "Overdue",
          style: TextStyle(
            color: Colors.red,
            fontSize: 11,
          ),
        );
      } else if (deadline.isAtSameMomentAs(today)) {
        String timeStr = parts.length > 1 ? " ${parts[1]}" : "";
        return Text(
          "Today$timeStr",
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 11,
          ),
        );
      } else if (deadline.isAtSameMomentAs(tomorrow)) {
        String timeStr = parts.length > 1 ? " ${parts[1]}" : "";
        return Text(
          "Tomorrow$timeStr",
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 11,
          ),
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        );
      } else {
        String formattedDate = DateFormat('MMM d').format(deadline);
        return Text(
          formattedDate,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        );
      }
    } catch (e) {
      print('Error parsing date: $e');
      return const SizedBox();
    }
  }
}
