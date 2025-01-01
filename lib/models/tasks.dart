class TasksModel {
  String name;
  bool isCompleted;
  DateTime timeStamp;
  DateTime deadline;

  TasksModel({
    required this.name,
    required this.isCompleted,
    required this.timeStamp,
    required this.deadline,
  });

  static List<TasksModel> getTasks() {
    List<TasksModel> tasks = [];

    // tasks.add(
    //   TasksModel(
    //     name: 'Oprat Boty',
    //     isCompleted: false,
    //     timeStamp: DateTime.now(),
    //     deadline: DateTime.now().add(Duration(days: 2)),
    //   ),
    // );

    // tasks.add(
    //   TasksModel(
    //     name: 'Umyt sa',
    //     isCompleted: true,
    //     timeStamp: DateTime.now(),
    //     deadline: DateTime.now().add(
    //       Duration(days: 2),
    //     ),
    //   ),
    // );

    return tasks;
  }
}
