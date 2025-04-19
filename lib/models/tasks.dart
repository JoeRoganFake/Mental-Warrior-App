//Used for Task and Goal
class Task {
  final int status, id;
  final String label, description, deadline, category;
  final String? repeatFrequency; // day, week, month, year
  final int? repeatInterval; // every X days, weeks, etc.
  final String? repeatEndType; // never, on, after
  final String? repeatEndDate; // specific date if endType is 'on'
  final int? repeatOccurrences; // number of occurrences if endType is 'after'

  Task({
    required this.description,
    required this.deadline,
    required this.id,
    required this.status,
    required this.label,
    required this.category,
    this.repeatFrequency,
    this.repeatInterval,
    this.repeatEndType,
    this.repeatEndDate,
    this.repeatOccurrences,
  });
}
