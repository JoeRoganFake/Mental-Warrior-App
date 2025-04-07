//Used for Task and Goal
class Task {
  final int status, id;
  final String label, description, deadline;
  // Add this field

  Task({
    required this.description,
    required this.deadline,
    required this.id,
    required this.status,
    required this.label,
    // Default value
  });
}
