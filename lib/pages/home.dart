import 'package:flutter/material.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/utils/functions.dart';
import 'package:mental_warior/models/tasks.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var function = Functions();
  final _dateController = TextEditingController();
  final _labelController = TextEditingController();
  final _descriptionController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TaskService _taskService = TaskService();
  final CompletedTaskService _completedTaskService = CompletedTaskService();
  bool _isExpanded = false;
  Map<int, bool> taskDeletedState = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        splashColor: Colors.blue,
        onPressed: () {
          showMenu(
            context: context,
            position: RelativeRect.fromLTRB(
              MediaQuery.of(context).size.width - 5,
              MediaQuery.of(context).size.height - 200,
              20,
              0,
            ),
            items: [
              PopupMenuItem<String>(
                value: 'task',
                child: Text('Task'),
                onTap: () => taskFormDialog(context),
              ),
              PopupMenuItem<String>(
                value: 'habit',
                child: Text('Habit'),
              ),
            ],
          );
        },
        backgroundColor: const Color.fromARGB(255, 103, 113, 121),
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.white,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Text(
                "Good Productive ${function.getTimeOfDayDescription()}.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 25),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Tasks Today",
                        textAlign: TextAlign.start,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      _taskList(),
                      _completedTaskList(),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Flexible(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Habits Today",
                        textAlign: TextAlign.start,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "No habits added yet.",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Container _completedTaskList() {
    return Container(
      decoration: BoxDecoration(border: Border.all()),
      width: 200,
      child: FutureBuilder(
          future: _completedTaskService.getCompletedTasks(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              _isExpanded = false;
              return SizedBox.shrink();
            }

            return SingleChildScrollView(
              child: ExpansionPanelList(
                expansionCallback: (int index, bool isExpanded) {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                children: [
                  ExpansionPanel(
                    headerBuilder: (context, isExpanded) {
                      return ListTile(
                        title: Text(
                          "Completed Tasks",
                        ),
                      );
                    },
                    body: Column(
                      children: snapshot.data?.map<Widget>((ctask) {
                            bool isTaskDeleted =
                                taskDeletedState[ctask.id] ?? false;
                            return Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: GestureDetector(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: isTaskDeleted ? 0.0 : 1.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: const Color.fromARGB(
                                          255, 119, 119, 119),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Padding(
                                            padding:
                                                const EdgeInsets.only(left: 30),
                                            child: Text(
                                              ctask.label,
                                              style: TextStyle(
                                                color: Colors.white,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 30),
                                          child: Checkbox(
                                            value: ctask.status == 0,
                                            onChanged: (value) async {
                                              setState(() {
                                                _completedTaskService
                                                    .updateCompTaskStatus(
                                                  ctask.id,
                                                  value == true ? 0 : 1,
                                                );
                                              });

                                              await Future.delayed(
                                                  const Duration(
                                                      milliseconds: 250));
                                              await _taskService.addTask(
                                                  ctask.label,
                                                  ctask.deadline,
                                                  ctask.description);
                                              await _completedTaskService
                                                  .deleteCompTask(ctask.id);

                                              setState(() {});
                                            },
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                                onLongPress: () {
                                  setState(() {
                                    taskDeletedState[ctask.id] = true;
                                  });

                                  Future.delayed(
                                      const Duration(milliseconds: 200),
                                      () async {
                                    await _completedTaskService
                                        .deleteCompTask(ctask.id);

                                    setState(() {
                                      taskDeletedState = {};
                                    });
                                  });
                                },
                                onTap: () {
                                  _labelController.text = ctask.label;
                                  _dateController.text = ctask.deadline;
                                  _descriptionController.text =
                                      ctask.description;
                                  taskFormDialog(context,
                                      add: false,
                                      changeCompletedTask: true,
                                      task: ctask);
                                },
                              ),
                            );
                          }).toList() ??
                          [],
                    ),
                    isExpanded: _isExpanded,
                  ),
                ],
              ),
            );
          }),
    );
  }

  Future<dynamic> taskFormDialog(
    BuildContext context, {
    Task? task,
    bool add = true,
    bool changeCompletedTask = false,
  }) {
    return showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        children: [
          Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    add ? "New Task" : "Edit Task",
                  ),
                ),
                TextFormField(
                  controller: _labelController,
                  autofocus: add,
                  validator: (value) {
                    if (value!.isEmpty || value == "") {
                      return "     *Field Is Required";
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                      hintText: "Label",
                      prefixIcon: const Icon(Icons.label),
                      border: InputBorder.none),
                ),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                      hintText: "Description",
                      prefixIcon: const Icon(Icons.description),
                      border: InputBorder.none),
                ),
                TextFormField(
                  controller: _dateController,
                  onTap: () {
                    Functions.dateAndTimePicker(context, _dateController);
                  },
                  readOnly: true,
                  decoration: InputDecoration(
                      hintText: "Due To",
                      prefixIcon: const Icon(Icons.calendar_month),
                      border: InputBorder.none),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      if (add) {
                        _taskService.addTask(
                          _labelController.text,
                          _dateController.text,
                          _descriptionController.text,
                        );
                      } else if (changeCompletedTask && task != null) {
                        _completedTaskService.updateCompletedTask(
                            task.id, "label", _labelController.text);
                        _completedTaskService.updateCompletedTask(task.id,
                            "description", _descriptionController.text);
                        _completedTaskService.updateCompletedTask(
                            task.id, "deadline", _dateController.text);
                      } else if (!add && task != null) {
                        print("EDITING NOT COMPLETED");
                        _taskService.updateTask(
                            task.id, "label", _labelController.text);
                        _taskService.updateTask(task.id, "description",
                            _descriptionController.text);
                        _taskService.updateTask(
                            task.id, "deadline", _dateController.text);
                      }
                    }
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: const Icon(Icons.add_task_outlined),
                      ),
                      Text(
                        add ? "Add Task" : "Edit Task",
                        textAlign: TextAlign.center,
                        style: TextStyle(),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    ).then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _labelController.clear();
        _descriptionController.clear();
        _dateController.clear();
      });
    });
  }

  Widget _taskList() {
    return Container(
      decoration: BoxDecoration(border: Border.all()),
      height: 300,
      width: 200,
      child: FutureBuilder(
          future: _taskService.getTasks(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text("No tasks yet"));
            }
            return ListView.builder(
              scrollDirection: Axis.vertical,
              itemCount: snapshot.data?.length ?? 0,
              itemBuilder: (context, index) {
                Task task = snapshot.data![index];
                bool isTaskDeleted = taskDeletedState[task.id] ?? false;
                return Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: GestureDetector(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isTaskDeleted ? 0.0 : 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: const Color.fromARGB(255, 119, 119, 119),
                        ),
                        child: Column(children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 30),
                                  child: Text(
                                    task.label,
                                    style: TextStyle(
                                      color: Colors.white,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 30),
                                child: Checkbox(
                                  value: task.status == 1,
                                  onChanged: (value) async {
                                    setState(() {
                                      _taskService.updateTaskStatus(
                                          task.id, value == true ? 1 : 0);
                                    });

                                    await Future.delayed(
                                        const Duration(milliseconds: 250));

                                    if (value == true) {
                                      await _completedTaskService
                                          .addCompletedTask(task.label,
                                              task.deadline, task.description);
                                      await _taskService.deleteTask(task.id);
                                    }
                                    setState(() {});
                                  },
                                ),
                              )
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Functions.whenDue(task),
                            ],
                          )
                        ]),
                      ),
                    ),
                    onTap: () {
                      _labelController.text = task.label;
                      _descriptionController.text = task.description;
                      _dateController.text = task.deadline;
                      taskFormDialog(context, add: false, task: task);
                    },
                    onLongPress: () {
                      setState(() {
                        taskDeletedState[task.id] = true;
                      });

                      Future.delayed(const Duration(milliseconds: 200),
                          () async {
                        await _taskService.deleteTask(task.id);

                        setState(() {
                          taskDeletedState = {};
                        });
                      });
                    },
                  ),
                );
              },
            );
          }),
    );
  }
}
