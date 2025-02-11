import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mental_warior/models/books.dart';
import 'package:mental_warior/models/habits.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/services/quote_service.dart';
import 'package:mental_warior/utils/functions.dart';
import 'package:mental_warior/models/tasks.dart';
import 'dart:isolate';

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
  final TaskService _taskService = TaskService();
  final CompletedTaskService _completedTaskService = CompletedTaskService();
  final HabitService _habitService = HabitService();
  final GoalService _goalService = GoalService();
  final BookService _bookServiceLib = BookService();
  bool _isExpanded = false;
  Map<int, bool> taskDeletedState = {};
  static const String isolateName = 'background_task_port';
  final ReceivePort _receivePort = ReceivePort();
  final QuoteService _quoteService = QuoteService();

  @override
  void initState() {
    super.initState();

    IsolateNameServer.registerPortWithName(_receivePort.sendPort, isolateName);

    _receivePort.listen((message) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping(isolateName);
    super.dispose();
  }

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
              MediaQuery.of(context).size.height - 250,
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
                child: Text('Habit',
                    style: TextStyle(
                        color: const Color.fromARGB(255, 107, 107, 107))),
                onTap: () => habitFormDialog(),
              ),
              PopupMenuItem<String>(
                value: 'goal',
                child: Text(
                  'Long Term Goal',
                  style: TextStyle(
                      color: const Color.fromARGB(255, 107, 107, 107)),
                ),
                onTap: () => goalFormDialog(),
              ),
              PopupMenuItem<String>(
                value: 'book',
                child: Text('Book'),
                onTap: () => bookFormDialog(context),
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
          padding: const EdgeInsets.all(20),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Text(
                "Good Productive ${function.getTimeOfDayDescription()}.",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              " Daily Quote",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              '"${_quoteService.getDailyQuote().text}"',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 20),
            Text(
              "- ${_quoteService.getDailyQuote().author}",
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.normal),
            ),
            const SizedBox(height: 25),
            Text(
              "Goals",
              textAlign: TextAlign.left,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            _goalList(),
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
                      const SizedBox(height: 20),
                      _taskList(),
                      _completedTaskList(),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Flexible(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Habits Today",
                        textAlign: TextAlign.start,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 20),
                      _habitList()
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            _bookProgress(),
          ],
        ),
      ),
    );
  }

  FutureBuilder<List<Book>> _bookProgress() {
    return FutureBuilder<List<Book>>(
      future: _bookServiceLib.getBooks(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final books = snapshot.data;

        if (books == null || books.isEmpty) {
          return const Center(child: Text("No books yet"));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Books Progress",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Column(
              children: books.map((book) {
                return GestureDetector(
                  onTap: () => _showUpdateBookDialog(context, book),
                  child: ListTile(
                    title: Text(book.label),
                    subtitle: Text('Total Pages: ${book.totalPages}'),
                    trailing: SizedBox(
                      width: 80,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("${(book.progress * 100).toStringAsFixed(1)}%"),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: book.progress,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Future<dynamic> taskFormDialog(
    BuildContext context, {
    Task? task,
    bool add = true,
    bool changeCompletedTask = false,
  }) {
    final GlobalKey<FormState> taskFormKey = GlobalKey<FormState>();
    return showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        children: [
          Form(
            key: taskFormKey,
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
                    if (taskFormKey.currentState!.validate()) {
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
                        _taskService.updateTask(
                            task.id, "label", _labelController.text);
                        _taskService.updateTask(task.id, "description",
                            _descriptionController.text);
                        _taskService.updateTask(
                            task.id, "deadline", _dateController.text);
                      }
                      Navigator.pop(context);
                      setState(() {});
                    }
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

  Future<dynamic> habitFormDialog({bool add = true, Habit? habit}) {
    final GlobalKey<FormState> habitFormKey = GlobalKey<FormState>();
    return showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        children: [
          Form(
            key: habitFormKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    add ? "New Habit" : "Edit Habit",
                  ),
                ),
                TextFormField(
                  controller: _labelController,
                  autofocus: true,
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
                ElevatedButton(
                  onPressed: () {
                    if (add) {
                      if (habitFormKey.currentState!.validate()) {
                        _habitService.addHabit(
                          _labelController.text,
                          _descriptionController.text,
                        );
                        Navigator.pop(context);
                        setState(() {});
                      }
                    } else {
                      if (habitFormKey.currentState!.validate()) {
                        _habitService.updateHabit(
                            habit!.id, "label", _labelController.text);
                        _habitService.updateHabit(habit.id, "description",
                            _descriptionController.text);
                        Navigator.pop(context);
                        setState(() {});
                      }
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: const Icon(Icons.add_task_outlined),
                      ),
                      Text(
                        add ? "Add Habit" : "Edit Habit",
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
      });
    });
  }

  Future<dynamic> goalFormDialog() {
    final GlobalKey<FormState> goalFormKey = GlobalKey<FormState>();
    return showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        children: [
          Form(
            key: goalFormKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    "New Long-Term Goal",
                  ),
                ),
                TextFormField(
                  controller: _labelController,
                  autofocus: true,
                  validator: (value) {
                    if (value!.isEmpty || value == "") {
                      return "     *Field Is Required";
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                      hintText: "Goal",
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
                  validator: (value) {
                    if (value!.isEmpty || value == "") {
                      return "     *Field Is Required";
                    }
                    return null;
                  },
                  onTap: () {
                    Functions.dateAndTimePicker(context, _dateController,
                        onlyDate: true);
                  },
                  readOnly: true,
                  decoration: InputDecoration(
                      hintText: "Due To",
                      prefixIcon: const Icon(Icons.calendar_month),
                      border: InputBorder.none),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (goalFormKey.currentState!.validate()) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("Confirm Goal"),
                          content: Text(
                            "Are you sure that "
                            "goal ${_labelController.text} is a achievable until  ${_dateController.text}\n\n"
                            "Long-Term goals are not easily updated.\n"
                            "Think about it first!",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context), // Cancel
                              child: Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _goalService.addGoal(
                                  _labelController.text,
                                  _dateController.text,
                                  _descriptionController.text,
                                );
                                Navigator.pop(
                                    context); // Close confirmation dialog
                                Navigator.pop(
                                    context); // Close goal form dialog
                                setState(() {});
                              },
                              child: Text("Confirm"),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.add_task_outlined),
                      ),
                      Text(
                        "Add Goal",
                        textAlign: TextAlign.center,
                      )
                    ],
                  ),
                ),
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

  Future<dynamic> bookFormDialog(BuildContext context) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController pagesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Manual Book Entry"),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    hintText: "Book Title",
                    prefixIcon: Icon(Icons.book),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? "Field is required" : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: pagesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: "Total Pages",
                    prefixIcon: Icon(Icons.pages),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value!.isEmpty) return "Field is required";
                    if (int.tryParse(value) == null || int.parse(value) <= 2) {
                      return "Must be greater than 2";
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  _bookServiceLib.addBook(
                      titleController.text, int.parse(pagesController.text));
                  Navigator.pop(context);
                }
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
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

  Widget _habitList() {
    return FutureBuilder(
      future: _habitService.getHabits(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("No habits yet"));
        }

        // Create a list of Habit widgets
        List<Widget> habitWidgets = snapshot.data!
            .map<Widget>((habit) => GestureDetector(
                  onHorizontalDragStart: (details) async {
                    await _habitService.updateHabitStatus(
                        habit.id, habit.status == 0 ? 1 : 0);
                    setState(() {});
                  },
                  onVerticalDragEnd: (details) => setState(() {}),
                  onLongPress: () async {
                    await _habitService.deleteHabit(habit.id);
                    setState(() {});
                  },
                  onTap: () {
                    _labelController.text = habit.label;
                    _descriptionController.text = habit.description;
                    habitFormDialog(add: false, habit: habit);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey.shade100,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Flexible(
                            child: Text(
                              habit.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: habit.status == 0
                                    ? Color.fromARGB(255, 0, 0, 0)
                                    : Colors.grey,
                                decoration: habit.status == 0
                                    ? TextDecoration.none
                                    : TextDecoration.lineThrough,
                                decorationThickness: 2,
                                decorationColor:
                                    const Color.fromARGB(255, 255, 0, 0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ))
            .toList();

        return Column(
          children: habitWidgets,
        );
      },
    );
  }

  Widget _goalList() {
    return Container(
      decoration: BoxDecoration(border: Border.all()),
      height: 140,
      child: FutureBuilder(
        future: _goalService.getGoals(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("No goals yet"));
          }

          List<Task> goals = snapshot.data!;

          return ListView(
            children: goals.map((goal) {
              DateTime deadline;

              try {
                deadline =
                    DateTime.parse(goal.deadline.trim()); // Correct parsing
              } catch (e) {
                return Text("Raw deadline string: ${goal.deadline}");
              }

              return GestureDetector(
                onLongPress: () {
                  _goalService.deleteGoal(goal.id);
                  setState(() {});
                },
                onTap: () {
                  _showAchievementDialog(context, goal);
                },
                child: Column(
                  children: [
                    Text(
                      goal.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    StreamBuilder(
                      stream: Stream.periodic(Duration(seconds: 1), (_) {
                        return deadline.difference(DateTime.now());
                      }),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return Text("Loading...");

                        Duration remaining = snapshot.data!;
                        if (remaining.isNegative) {
                          return Text(
                            "Deadline Passed!",
                            style: TextStyle(color: Colors.red),
                          );
                        }

                        int days = remaining.inDays;
                        int hours = remaining.inHours % 24;
                        int minutes = remaining.inMinutes % 60;
                        int seconds = remaining.inSeconds % 60;

                        return Text(
                          "$days days, $hours h, $minutes m, $seconds s",
                          style: TextStyle(color: Colors.grey),
                        );
                      },
                    ),
                    Divider(),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Future<dynamic> _showAchievementDialog(BuildContext context, Task goal) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Goal Achieved?"),
        content: Text("Have you completed '${goal.label}' ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Close dialog
            child: Text("Not Yet"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close first dialog
              _showCongratulationsDialog(context, goal); // Show Congrats
            },
            child: Text("Yes!"),
          ),
        ],
      ),
    );
  }

  Future<dynamic> _showCongratulationsDialog(BuildContext context, Task goal) {
    _goalService.deleteGoal(goal.id);
    setState(() {});
    List<String> quotes = [
      "Success is not final, failure is not fatal: It is the courage to continue that counts. – Winston Churchill",
      "The only limit to our realization of tomorrow is our doubts of today. – Franklin D. Roosevelt",
      "Dream big and dare to fail. – Norman Vaughan",
      "Believe you can, and you're halfway there. – Theodore Roosevelt",
      "What you get by achieving your goals is not as important as what you become by achieving them. – Zig Ziglar",
      "Don’t watch the clock; do what it does. Keep going. – Sam Levenson",
      "Act as if what you do makes a difference. It does. – William James"
    ];

    String randomQuote =
        quotes[Random().nextInt(quotes.length)]; // Pick a random quote

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Congratulations!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                "You achieved your goal: '${goal.label}'! Keep up the great work!"),
            SizedBox(height: 20),
            Text(
              randomQuote,
              textAlign: TextAlign.center,
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _showUpdateBookDialog(BuildContext context, Book book) {
    final TextEditingController _currentPageController =
        TextEditingController(text: book.currentPage.toString());
    final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            book.label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                Text(
                  "Update your progress",
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      child: TextFormField(
                        controller: _currentPageController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          hintText: "Enter page",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Enter a valid page number";
                          }
                          final int? currentPage = int.tryParse(value);
                          if (currentPage == null || currentPage <= 0) {
                            return "Page must be greater than 0";
                          }
                          if (currentPage > book.totalPages) {
                            return "Page cannot exceed ${book.totalPages}";
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "/ ${book.totalPages}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final int currentPage =
                          int.parse(_currentPageController.text);
                      _bookServiceLib.updateBookCurrentPage(
                          book.id, currentPage);

                      setState(() {});
                      Navigator.pop(context);
                    }
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Update",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
}
