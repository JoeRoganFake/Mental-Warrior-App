// class TaskModel {
//   int id;
//   String label;
//   int status;
//   String description;
//   String deadline;

//   TaskModel({
//     required this.id,
//     required this.label,
//     required this.status,
//     required this.description,
//     required this.deadline,
//   });
// }

class Task {
  final int status, id;
  final String content;

  Task({
    required this.id,
    required this.status,
    required this.content,
  });
}
