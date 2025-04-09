import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mental_warior/models/books.dart';
import 'package:mental_warior/models/categories.dart';
import 'package:mental_warior/models/goals.dart';
import 'package:mental_warior/models/habits.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/services/quote_service.dart';
import 'package:mental_warior/utils/functions.dart';
import 'package:mental_warior/models/tasks.dart';
import 'dart:isolate';
import 'package:mental_warior/pages/meditation.dart';
import 'package:permission_handler/permission_handler.dart'; // Import the Meditation page

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
  int _currentIndex = 0; // Add this line
  bool _showDescription = false;
  bool _showDateTime = false;
  final CategoryService _categoryService = CategoryService();
  Category? selectedCategory;

  @override
  void initState() {
    super.initState();
    requestNotificationPermission();
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
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
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
            )
          : null, // Add this line
      backgroundColor: Colors.white,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: _currentIndex == 0
            ? _buildHomePage()
            : MeditationPage(), // Add this line
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home,
                color: _currentIndex == 0 ? Colors.blue : Colors.grey),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.self_improvement,
                color: _currentIndex == 1 ? Colors.blue : Colors.grey),
            label: 'Meditation',
          ),
        ],
      ),
    );
  }

  Widget _buildHomePage() {
    return ListView(
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
        _bookList(),
        const SizedBox(height: 25),
        const Text(
          "All Tasks Details",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _allTaskDetailsList(),
      ],
    );
  }

  Widget _allTaskDetailsList() {
    return FutureBuilder<List<Task>>(
      future: _taskService.getTasks(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No tasks available"));
        }

        final List<Task> tasks = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: tasks.map((task) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            task.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            task.category,
                            style: TextStyle(color: Colors.blue.shade800),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (task.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                        child: Text(
                          "Description: ${task.description}",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    if (task.deadline.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              "Deadline: ${task.deadline}",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Status: ${task.status == 1 ? 'Completed' : 'Pending'}",
                          style: TextStyle(
                            color:
                                task.status == 1 ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () {
                            _labelController.text = task.label;
                            _descriptionController.text = task.description;
                            _dateController.text = task.deadline;
                            taskFormDialog(context, add: false, task: task);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<dynamic> taskFormDialog(
    BuildContext context, {
    Task? task,
    bool add = true,
    bool changeCompletedTask = false,
  }) async {
    final GlobalKey<FormState> taskFormKey = GlobalKey<FormState>();
    Category defaultCategory;

    try {
      defaultCategory = await _categoryService.getDefaultCategory();
    } catch (e) {
      print("BIG BIG BIG PROBLEM, DEFAULT CATEGORY IS NOT FROM");
      defaultCategory = Category(id: 0, label: "Default", isDefault: 1);
    }

    // Set initial states based on whether we're editing
    if (task != null) {
      _labelController.text = task.label;
      _descriptionController.text = task.description;
      _dateController.text = task.deadline;

      // Show fields if they have content
      _showDescription = task.description.isNotEmpty;
      _showDateTime = task.deadline.isNotEmpty;

      // IMPORTANT: Set selectedCategory for existing tasks
      // Find the matching category or use the default
      try {
        final categories = await _categoryService.getCategories();
        selectedCategory = categories.firstWhere(
          (category) => category.label == task.category,
          orElse: () => defaultCategory,
        );
      } catch (e) {
        selectedCategory = defaultCategory;
      }
    } else {
      // Reset states for new task
      selectedCategory = defaultCategory;
      _showDescription = false;
      _showDateTime = false;
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: taskFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                add
                                    ? "New Task"
                                    : changeCompletedTask
                                        ? "Completed Task"
                                        : "Edit Task",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (!add && changeCompletedTask)
                              IconButton(
                                icon:
                                    const Icon(Icons.undo, color: Colors.blue),
                                onPressed: () async {
                                  if (task != null) {
                                    setState(() {
                                      _completedTaskService
                                          .updateCompTaskStatus(
                                        task.id,
                                        0,
                                      );
                                    });

                                    await Future.delayed(
                                        const Duration(milliseconds: 250));
                                    await _taskService.addTask(
                                      task.label,
                                      task.deadline,
                                      task.description,
                                      task.category,
                                    );
                                    await _completedTaskService
                                        .deleteCompTask(task.id);

                                    Navigator.pop(context);
                                    setState(() {});
                                  }
                                },
                              ),
                            if (!add)
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  if (task != null) {
                                    if (changeCompletedTask) {
                                      await _completedTaskService
                                          .deleteCompTask(task.id);
                                    } else {
                                      await _taskService.deleteTask(task.id);
                                    }
                                    Navigator.pop(context);
                                    setState(() {});
                                  }
                                },
                              ),
                          ],
                        ),
                      ),

                      // Label Field
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        child: TextFormField(
                          controller: _labelController,
                          autofocus: add,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            decoration: changeCompletedTask
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor: Colors.white,
                            decorationThickness: 2,
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? "*Required" : null,
                          decoration: InputDecoration(
                            hintText: "Label",
                            hintStyle: TextStyle(
                                color: Colors.grey[400], fontSize: 14),
                            prefixIcon: const Icon(
                              Icons.label,
                              color: Colors.white,
                              size: 20,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 12.0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                          ),
                        ),
                      ),
                      // Category Selection Field
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        child: InkWell(
                          onTap: () async {
                            final TextEditingController newCategoryController =
                                TextEditingController();
                            Category? selected;

                            await showDialog(
                              context: context,
                              builder: (context) {
                                return StatefulBuilder(
                                  builder: (BuildContext context,
                                      StateSetter dialogSetState) {
                                    return AlertDialog(
                                      contentPadding: const EdgeInsets.fromLTRB(
                                          12, 8, 12, 0),
                                      backgroundColor: Colors.grey[900],
                                      title: const Text(
                                        "Select Category",
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 18),
                                      ),
                                      content: SizedBox(
                                        width: 250,
                                        height: 250,
                                        child: Column(
                                          children: [
                                            // New Category Input - More compact
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller:
                                                        newCategoryController,
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13),
                                                    decoration: InputDecoration(
                                                      hintText: "New category",
                                                      contentPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 8,
                                                              vertical: 2),
                                                      isDense: true,
                                                      hintStyle: TextStyle(
                                                          color:
                                                              Colors.grey[400],
                                                          fontSize: 13),
                                                      enabledBorder:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                        borderSide: BorderSide(
                                                            color: Colors
                                                                .grey[700]!),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  iconSize: 16,
                                                  icon: const Icon(
                                                      Icons.add_circle,
                                                      color: Colors.white),
                                                  onPressed: () async {
                                                    if (newCategoryController
                                                        .text
                                                        .trim()
                                                        .isNotEmpty) {
                                                      await _categoryService
                                                          .addCategory(
                                                              newCategoryController
                                                                  .text
                                                                  .trim());
                                                      newCategoryController
                                                          .clear();
                                                      dialogSetState(() {});
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                            Divider(
                                                color: Colors.grey[700],
                                                height: 10),

                                            // Categories List - Fixed size
                                            Expanded(
                                              child:
                                                  FutureBuilder<List<Category>>(
                                                future: _categoryService
                                                    .getCategories(),
                                                builder: (context, snapshot) {
                                                  if (!snapshot.hasData) {
                                                    return const Center(
                                                        child: SizedBox(
                                                            height: 20,
                                                            width: 20,
                                                            child:
                                                                CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2)));
                                                  }

                                                  final categories =
                                                      snapshot.data!;
                                                  return ListView.builder(
                                                    padding: EdgeInsets.zero,
                                                    itemCount:
                                                        categories.length,
                                                    itemBuilder:
                                                        (context, index) {
                                                      final category =
                                                          categories[index];
                                                      return ListTile(
                                                        dense: true,
                                                        visualDensity:
                                                            const VisualDensity(
                                                                horizontal: -4,
                                                                vertical: -4),
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                    8.0),
                                                        title: Text(
                                                          category.label,
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 13),
                                                        ),
                                                        onTap: () {
                                                          selected = category;
                                                          Navigator.pop(
                                                              context);
                                                        },
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );

                            if (selected != null) {
                              modalSetState(() {
                                selectedCategory = selected;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 12.0),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[700]!),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.category,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  selectedCategory!.label,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_drop_down,
                                    color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Add Description Button (when field is hidden)
                      if (!_showDescription)
                        TextButton.icon(
                          icon: Icon(
                            Icons.add,
                            color: Colors.grey[400],
                          ),
                          label: Text(
                            "Add Description",
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          onPressed: () {
                            modalSetState(() {
                              _showDescription = true;
                            });
                          },
                        ),

                      // Description Field with side button (when field is visible)
                      if (_showDescription)
                        Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 4.0),
                                child: TextFormField(
                                  controller: _descriptionController,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  maxLines: 2,
                                  minLines: 1,
                                  keyboardType: TextInputType.multiline,
                                  decoration: InputDecoration(
                                    hintText: "Description",
                                    hintStyle: TextStyle(
                                        color: Colors.grey[400], fontSize: 14),
                                    prefixIcon: const Icon(Icons.description,
                                        color: Colors.white, size: 20),
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 12.0),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide:
                                          BorderSide(color: Colors.grey[700]!),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: Colors.grey[400],
                                size: 20,
                              ),
                              onPressed: () {
                                modalSetState(() {
                                  _showDescription = false;
                                  _descriptionController.clear();
                                });
                              },
                            ),
                          ],
                        ),

                      // Add DateTime Button (when field is hidden)
                      if (!_showDateTime)
                        TextButton.icon(
                          icon: Icon(
                            Icons.add,
                            color: Colors.grey[400],
                          ),
                          label: Text(
                            "Add Due Date",
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          onPressed: () {
                            modalSetState(() {
                              _showDateTime = true;
                            });
                          },
                        ),

                      // DateTime Field with side button (when field is visible)
                      if (_showDateTime)
                        Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 4.0),
                                child: TextFormField(
                                  controller: _dateController,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  readOnly: true,
                                  onTap: () async {
                                    await Functions.dateAndTimePicker(
                                        context, _dateController);
                                    modalSetState(() {});
                                  },
                                  decoration: InputDecoration(
                                    hintText: "Due Date",
                                    hintStyle: TextStyle(
                                        color: Colors.grey[400], fontSize: 14),
                                    prefixIcon: const Icon(Icons.calendar_today,
                                        color: Colors.white, size: 20),
                                    suffixIcon: _dateController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear,
                                                color: Colors.white, size: 18),
                                            onPressed: () => modalSetState(
                                                () => _dateController.clear()),
                                          )
                                        : null,
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 12.0),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide:
                                          BorderSide(color: Colors.grey[700]!),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: Colors.grey[400],
                                size: 20,
                              ),
                              onPressed: () {
                                modalSetState(() {
                                  _showDateTime = false;
                                  _dateController.clear();
                                });
                              },
                            ),
                          ],
                        ),

                      // Save Button
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          onPressed: () async {
                            if (taskFormKey.currentState!.validate()) {
                              Future<void> operation;
                              if (add) {
                                // Clean up the date string before saving
                                final String deadline =
                                    _dateController.text.trim();
                                operation = _taskService.addTask(
                                  _labelController.text,
                                  deadline,
                                  _descriptionController.text,
                                  selectedCategory!.label,
                                );
                              } else if (changeCompletedTask && task != null) {
                                operation = Future.wait([
                                  _completedTaskService.updateCompletedTask(
                                      task.id, "label", _labelController.text),
                                  _completedTaskService.updateCompletedTask(
                                      task.id,
                                      "description",
                                      _descriptionController.text),
                                  _completedTaskService.updateCompletedTask(
                                      task.id,
                                      "deadline",
                                      _dateController.text),
                                ]);
                              } else if (!add && task != null) {
                                // Clean up the date string before saving
                                final String deadline =
                                    _dateController.text.trim();
                                operation = Future.wait([
                                  _taskService.updateTask(
                                      task.id, "label", _labelController.text),
                                  _taskService.updateTask(
                                      task.id,
                                      "description",
                                      _descriptionController.text),
                                  _taskService.updateTask(
                                      task.id, "deadline", deadline),
                                ]);
                              } else {
                                operation = Future.value();
                              }

                              await operation;
                              Navigator.pop(context);
                              setState(() {});
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.add_task_outlined),
                              ),
                              Text(
                                add ? "Add Task" : "Edit Task",
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 100), () {
        _labelController.clear();
        _descriptionController.clear();
        _dateController.clear();
        setState(() {
          _showDescription = false;
          _showDateTime = false;
        });
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

  Widget _completedTaskList() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SizedBox(
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
                                              padding: const EdgeInsets.only(
                                                  left: 30),
                                              child: Text(
                                                ctask.label,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                  decorationColor: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 30),
                                            child: Checkbox(
                                              value: ctask.status == 0,
                                              onChanged: (value) async {
                                                setState(() {
                                                  _completedTaskService
                                                      .updateCompTaskStatus(
                                                    ctask.id,
                                                    value == true ? 0 : 1,
                                                  );
                                                  ;
                                                });

                                                await Future.delayed(
                                                    const Duration(
                                                        milliseconds: 250));
                                                await _taskService.addTask(
                                                    ctask.label,
                                                    ctask.deadline,
                                                    ctask.description,
                                                    ctask.category);

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
      ),
    );
  }

  Widget _taskList() {
    return FutureBuilder(
        future: _taskService.getTasks(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("No tasks yet"));
          }
          return Column(
            children: snapshot.data!.map<Widget>((task) {
              return Padding(
                padding: const EdgeInsets.all(6.0),
                child: GestureDetector(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: const Color.fromARGB(255, 119, 119, 119),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center, // Add this
                      children: [
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min, // Add this
                              children: [
                                Text(
                                  task.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                if (task.deadline.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Functions.whenDue(task),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
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
                                await _completedTaskService.addCompletedTask(
                                  task.label,
                                  task.deadline,
                                  task.description,
                                  task.category,
                                );
                                await _taskService.deleteTask(task.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Task Completed"),
                                    action: SnackBarAction(
                                      label: "UNDO",
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .hideCurrentSnackBar();
                                        _taskService.addTask(
                                          task.label,
                                          task.deadline,
                                          task.description,
                                          task.category,
                                        );
                                        _completedTaskService
                                            .deleteCompTask(task.id);
                                        setState(() {});
                                      },
                                      textColor: Colors.white,
                                    ),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                              setState(() {});
                            },
                          ),
                        )
                      ],
                    ),
                  ),
                  onTap: () {
                    _labelController.text = task.label;
                    _descriptionController.text = task.description;
                    _dateController.text = task.deadline;
                    taskFormDialog(context, add: false, task: task);
                  },
                ),
              );
            }).toList(),
          );
        });
  }

  Widget _habitList() {
    return FutureBuilder(
      future: _habitService.getHabits(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("No habits yet"));
        }

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
      child: FutureBuilder(
        future: _goalService.getGoals(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("No goals yet"));
          }

          List<Goal> goals = snapshot.data!;

          return Column(
            children: goals.map((goal) {
              DateTime deadline;

              try {
                deadline = DateTime.parse(goal.deadline.trim());
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

  Widget _bookList() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 50),
      child: FutureBuilder<List<Book>>(
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
                      subtitle: Text(
                          'Current Page:${book.currentPage} out of ${book.totalPages}'),
                      trailing: SizedBox(
                        width: 80,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                                "${(book.progress * 100).toStringAsFixed(1)}%"),
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
      ),
    );
  }

  Future<dynamic> _showAchievementDialog(BuildContext context, Goal goal) {
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

  Future<dynamic> _showCongratulationsDialog(BuildContext context, Goal goal) {
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

  Future<dynamic> _showUpdateBookDialog(BuildContext context, Book book) {
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
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      Future<bool> isDeleting =
                          _bookServiceLib.updateBookCurrentPage(
                              book.id, int.parse(_currentPageController.text));

                      setState(() {});
                      Navigator.pop(context);

                      if (await isDeleting) {
                        _showBookFinishedDialog(
                          context,
                          book,
                        );
                      }
                    }
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

  Future<dynamic> _showBookFinishedDialog(BuildContext context, Book book) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Book Completed?"),
        content: Text("Did you finish reading '${book.label}'?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _bookServiceLib.updateBookCurrentPage(book.id, book.currentPage);
              setState(() {});
            },
            child: Text("Not Yet"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _bookServiceLib.deleteBook(book.id);
              setState(() {});
            },
            child: Text("Yes!"),
          ),
        ],
      ),
    );
  }

  void requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }
}

class TaskDetailsWidget extends StatelessWidget {
  final Task task;

  const TaskDetailsWidget({Key? key, required this.task}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        "Task Details",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Label: ${task.label}"),
          const SizedBox(height: 8),
          Text(
              "Description: ${task.description.isNotEmpty ? task.description : "No description"}"),
          const SizedBox(height: 8),
          Text(
              "Deadline: ${task.deadline.isNotEmpty ? task.deadline : "No deadline"}"),
          const SizedBox(height: 8),
          Text("Category: ${task.category}"),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    );
  }
}
