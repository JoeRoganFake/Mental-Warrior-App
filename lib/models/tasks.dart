//Used for Task and Goal
class Task {
  final int status, id;
  final String label, description, deadline, category;
  // For repeating tasks - all nullable since not all tasks repeat
  final String?
      repeatFrequency; // day, week, month, year - defaults to 'day' if repeat is enabled
  final int?
      repeatInterval; // every X days, weeks, etc. - defaults to 1 if repeat is enabled
  final String?
      repeatEndType; // never, on, after - defaults to 'never' if repeat is enabled
  final String? repeatEndDate; // specific date if endType is 'on'
  final int?
      repeatOccurrences; // number of occurrences if endType is 'after' - defaults to 30 if end type is 'after'
  final String?
      nextDeadline; // next deadline for repeating tasks (used for completed tasks)

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
    this.nextDeadline,
  });
}
