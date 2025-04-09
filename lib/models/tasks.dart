//Used for Task and Goal
class Task {
  final int status, id;
  final String label, description, deadline, category;

  Task({
    required this.description,
    required this.deadline,
    required this.id,
    required this.status,
    required this.label,
    required this.category,
  });
}
