import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mental_warior/models/books.dart';
import 'package:mental_warior/models/categories.dart';
import 'package:mental_warior/models/goals.dart';
import 'package:mental_warior/models/habits.dart';
import 'package:mental_warior/pages/categories_page.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/services/quote_service.dart';
import 'package:mental_warior/utils/functions.dart';
import 'package:mental_warior/utils/app_theme.dart';
import 'package:mental_warior/models/tasks.dart';
import 'dart:isolate';
import 'package:mental_warior/pages/meditation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mental_warior/services/background_task_manager.dart';
import 'package:mental_warior/pages/workout/workout_page.dart';
import 'package:mental_warior/widgets/active_workout_bar.dart';
import 'package:mental_warior/widgets/xp_bar.dart';
import 'package:mental_warior/widgets/level_up_animation.dart';
import 'package:mental_warior/widgets/xp_gain_bubble.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();

  // Static method to access the HomePage state from anywhere
  static HomePageState? of(BuildContext context) {
    final state = context.findAncestorStateOfType<HomePageState>();
    return state;
  }
}

class HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin<HomePage> {
  var function = Functions();
  final _dateController = TextEditingController();
  final _labelController = TextEditingController();
  final _descriptionController = TextEditingController();
  final TaskService _taskService = TaskService();
  final CompletedTaskService _completedTaskService = CompletedTaskService();
  final HabitService _habitService = HabitService();
  final GoalService _goalService = GoalService();
  final BookService _bookServiceLib = BookService();
  final XPService _xpService = XPService();
  Map<int, bool> taskDeletedState = {};
  static const String isolateName = 'background_task_port';
  final ReceivePort _receivePort = ReceivePort();
  final QuoteService _quoteService = QuoteService();
  int _currentIndex = 0;
  bool _showDescription = false;
  bool _showDateTime = false;
  final CategoryService _categoryService = CategoryService();
  Category? selectedCategory;
  Quote? _currentDailyQuote;

  @override
  void initState() {
    super.initState();
    requestNotificationPermission();
    IsolateNameServer.registerPortWithName(_receivePort.sendPort, isolateName);

    _receivePort.listen((message) {
      if (message == 'quote_updated') {
        _loadStoredQuote();
      }
      setState(() {});
    });

    _loadStoredQuote();

    // Listen for habit updates
    DatabaseService.habitsUpdatedNotifier.addListener(_onHabitsUpdated);
  }

  void _onHabitsUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadStoredQuote() async {
    // Try to get the stored quote first
    final storedQuote = await BackgroundTaskManager.getStoredDailyQuote();

    // If there's no stored quote, get one from the service and store it
    if (storedQuote == null) {
      final newQuote = _quoteService.getDailyQuote();
      await BackgroundTaskManager.dailyQuoteCallback();

      _currentDailyQuote = newQuote;
    } else {
      _currentDailyQuote = storedQuote;
    }

    setState(() {});
  }

  @override
  void dispose() {
    DatabaseService.habitsUpdatedNotifier.removeListener(_onHabitsUpdated);
    IsolateNameServer.removePortNameMapping(isolateName);
    super.dispose();
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return _HomePageContent(); // Remove const to allow rebuilding
      case 1:
        return const MeditationPage();
      case 2:
        return const CategoriesPage();
      case 3:
        return const WorkoutPage(); // Added workout page
      default:
        return _HomePageContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      // Add the ActiveWorkoutBar at the bottom of the screen
      // It will automatically show only when a workout is active
      bottomSheet: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: WorkoutService.activeWorkoutNotifier,
        builder: (context, activeWorkout, child) {
          return activeWorkout != null
              ? const ActiveWorkoutBar()
              : const SizedBox.shrink();
        },
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              splashColor: AppTheme.accent,
              onPressed: () {
                showMenu(
                  context: context,
                  color: AppTheme.surface,
                  position: RelativeRect.fromLTRB(
                    MediaQuery.of(context).size.width - 5,
                    MediaQuery.of(context).size.height - 250,
                    20,
                    0,
                  ),
                  items: [
                    PopupMenuItem<String>(
                      value: 'task',
                      child: Text('Task', style: AppTheme.bodyMedium),
                      onTap: () => taskFormDialog(context),
                    ),
                    PopupMenuItem<String>(
                      value: 'habit',
                      child: Text('Habit', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
                      onTap: () => habitFormDialog(),
                    ),
                    PopupMenuItem<String>(
                      value: 'goal',
                      child: Text(
                        'Long Term Goal',
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                      ),
                      onTap: () => goalFormDialog(),
                    ),
                    PopupMenuItem<String>(
                      value: 'book',
                      child: Text('Book', style: AppTheme.bodyMedium),
                      onTap: () => bookFormDialog(context),
                    ),
                  ],
                );
              },
              backgroundColor: AppTheme.accent,
              child: const Icon(
                Icons.add,
                color: Colors.white,
              ),
            )
          : null,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child:
            _getCurrentPage(), // Use the method instead of _pages[_currentIndex]
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: AppTheme.surface,
          selectedItemColor: AppTheme.accent,
          unselectedItemColor: AppTheme.textSecondary,
          currentIndex: _currentIndex,
          onTap: (index) {
            // If we're returning to Home tab from another tab, force refresh data
            if (_currentIndex != 0 && index == 0) {
              // First update the index
              setState(() {
                _currentIndex = index;
              });
              // Then force a rebuild of the home content
              setState(() {});
            } else {
              // Normal tab change
              setState(() {
                _currentIndex = index;
              });
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home,
                  color: _currentIndex == 0 ? AppTheme.accent : AppTheme.textSecondary),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.self_improvement,
                  color: _currentIndex == 1 ? AppTheme.accent : AppTheme.textSecondary),
              label: 'Meditation',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.category,
                  color: _currentIndex == 2 ? AppTheme.accent : AppTheme.textSecondary),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center,
                  color: _currentIndex == 3 ? AppTheme.accent : AppTheme.textSecondary),
              label: 'Workout',
            ),
          ],
          type: BottomNavigationBarType.fixed, // Required for more than 3 items
        ),
      ),
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

    // Add repeat functionality variables
    bool showRepeat = false;
    String repeatFrequency = 'day';
    int repeatInterval = 1;
    String repeatEndType = 'never';
    final TextEditingController repeatEndDateController =
        TextEditingController();
    final TextEditingController repeatOccurrencesController =
        TextEditingController();

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

      // Set repeat functionality fields if this is a repeating task
      showRepeat = task.repeatFrequency != null;
      if (task.repeatFrequency != null) {
        repeatFrequency = task.repeatFrequency!;
        repeatInterval = task.repeatInterval ?? 1;
        repeatEndType = task.repeatEndType ?? 'never';

        if (task.repeatEndDate != null) {
          repeatEndDateController.text = task.repeatEndDate!;
        }

        if (task.repeatOccurrences != null) {
          repeatOccurrencesController.text = task.repeatOccurrences.toString();
        } else {
          repeatOccurrencesController.text = '30';
        }
      }

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
      showRepeat = false;
      repeatFrequency = 'day';
      repeatInterval = 1;
      repeatEndType = 'never';
      repeatEndDateController.clear();
      repeatOccurrencesController.text = '30';
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
                                            onPressed: () => modalSetState(() {
                                              _dateController.clear();
                                              showRepeat =
                                                  false; // Reset repeat when deadline is cleared
                                            }),
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
                                  showRepeat =
                                      false; // Reset repeat when deadline is removed
                                });
                              },
                            ),
                          ],
                        ),

                      // Add Repeat button (only shows if a date is selected and has a valid time)
                      if (_showDateTime &&
                          _dateController.text.isNotEmpty &&
                          _dateController.text.contains(":"))
                        TextButton.icon(
                          icon: Icon(Icons.repeat,
                              color:
                                  showRepeat ? Colors.blue : Colors.grey[400]),
                          label: Text(
                            showRepeat
                                ? "Repeats every $repeatInterval ${repeatFrequency}${repeatInterval > 1 ? 's' : ''}"
                                : "Add Repeat",
                            style: TextStyle(
                                color: showRepeat
                                    ? Colors.blue
                                    : Colors.grey[400]),
                          ),
                          onPressed: () {
                            _showRepeatOptionsDialog(
                                context,
                                modalSetState,
                                repeatFrequency,
                                repeatInterval,
                                repeatEndType,
                                repeatEndDateController,
                                repeatOccurrencesController, onUpdate:
                                    (frequency, interval, endType, endDate,
                                        occurrences) {
                              modalSetState(() {
                                showRepeat = true;
                                repeatFrequency = frequency;
                                repeatInterval = interval;
                                repeatEndType = endType;
                                // The controllers are updated directly
                              });
                            });
                          },
                          // Add trailing remove button to discard repeat options
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.only(left: 12, right: 0),
                          ),
                        ),

                      // Show remove button for repeat options when active
                      if (showRepeat)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red[300],
                                  size: 18,
                                ),
                                label: Text(
                                  "Remove Repeat",
                                  style: TextStyle(color: Colors.red[300]),
                                ),
                                onPressed: () {
                                  modalSetState(() {
                                    // Clear all repeat-related fields
                                    showRepeat = false;
                                    repeatFrequency = 'day';
                                    repeatInterval = 1;
                                    repeatEndType = 'never';
                                    repeatEndDateController.clear();
                                    repeatOccurrencesController.text = '30';
                                  });
                                },
                              ),
                            ],
                          ),
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
                                  // Add repeat functionality parameters
                                  repeatFrequency:
                                      showRepeat ? repeatFrequency : null,
                                  repeatInterval:
                                      showRepeat ? repeatInterval : null,
                                  repeatEndType:
                                      showRepeat ? repeatEndType : null,
                                  repeatEndDate:
                                      showRepeat && repeatEndType == 'on'
                                          ? repeatEndDateController.text
                                          : null,
                                  repeatOccurrences:
                                      showRepeat && repeatEndType == 'after'
                                          ? int.tryParse(
                                              repeatOccurrencesController.text)
                                          : null,
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
                                  _completedTaskService.updateCompletedTask(
                                      task.id,
                                      "category",
                                      selectedCategory!.label),
                                ]);
                              } else if (!add && task != null) {
                                // Clean up the date string before saving
                                final String deadline =
                                    _dateController.text.trim();

                                // Update basic task fields first
                                await Future.wait([
                                  _taskService.updateTask(
                                      task.id, "label", _labelController.text),
                                  _taskService.updateTask(
                                      task.id,
                                      "description",
                                      _descriptionController.text),
                                  _taskService.updateTask(
                                      task.id, "deadline", deadline),
                                  _taskService.updateTask(task.id, "category",
                                      selectedCategory!.label),
                                ]);

                                // Then update repeat fields
                                if (showRepeat) {
                                  await Future.wait([
                                    _taskService.updateTask(task.id,
                                        "repeatFrequency", repeatFrequency),
                                    _taskService.updateTask(task.id,
                                        "repeatInterval", repeatInterval),
                                    _taskService.updateTask(task.id,
                                        "repeatEndType", repeatEndType),
                                  ]);

                                  if (repeatEndType == 'on') {
                                    await _taskService.updateTask(
                                        task.id,
                                        "repeatEndDate",
                                        repeatEndDateController.text);
                                    // Clear the occurrences field when using end date
                                    await _taskService.updateTask(
                                        task.id, "repeatOccurrences", null);
                                  } else if (repeatEndType == 'after') {
                                    await _taskService.updateTask(
                                        task.id,
                                        "repeatOccurrences",
                                        int.tryParse(repeatOccurrencesController
                                                .text) ??
                                            30);
                                    // Clear the end date field when using occurrences
                                    await _taskService.updateTask(
                                        task.id, "repeatEndDate", null);
                                  } else {
                                    // For 'never' end type, clear both end date and occurrences
                                    await Future.wait([
                                      _taskService.updateTask(
                                          task.id, "repeatEndDate", null),
                                      _taskService.updateTask(
                                          task.id, "repeatOccurrences", null),
                                    ]);
                                  }
                                } else {
                                  // If repeat is disabled, clear all repeat fields
                                  await Future.wait([
                                    _taskService.updateTask(
                                        task.id, "repeatFrequency", null),
                                    _taskService.updateTask(
                                        task.id, "repeatInterval", null),
                                    _taskService.updateTask(
                                        task.id, "repeatEndType", null),
                                    _taskService.updateTask(
                                        task.id, "repeatEndDate", null),
                                    _taskService.updateTask(
                                        task.id, "repeatOccurrences", null),
                                  ]);
                                }
                                operation = Future.value();
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

  Future<void> _showRepeatOptionsDialog(
      BuildContext context,
      StateSetter parentSetState,
      String currentFrequency,
      int currentInterval,
      String currentEndType,
      TextEditingController endDateController,
      TextEditingController occurrencesController,
      {required Function(String, int, String, String, String) onUpdate}) async {
    final String oldEndDate = endDateController.text;
    final String oldOccurrences = occurrencesController.text;

    // Always ensure the end date is set to a reasonable value if not already set
    if (currentEndType == 'on' &&
        endDateController.text.isEmpty &&
        _dateController.text.isNotEmpty) {
      try {
        final datePart = _dateController.text.split(" ")[0];
        final parts = datePart.split("-");
        final startDate = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final endDate = startDate.add(Duration(days: 30));
        endDateController.text =
            "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
      } catch (e) {
        print("Error setting default end date: $e");
      }
    }

    String frequency = currentFrequency;
    int interval = currentInterval;
    String endType = currentEndType;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        // This refreshes the dialog with the latest date/time values from the modal bottom sheet
        String timeValue = _dateController.text.isNotEmpty &&
                _dateController.text.contains(":")
            ? _dateController.text.split(" ")[1]
            : "12:00";

        String dateValue = _dateController.text.isNotEmpty &&
                _dateController.text.contains(" ")
            ? _dateController.text.split(" ")[0].replaceAll('-', '/')
            : DateTime.now().toString().split(" ")[0].replaceAll('-', '/');

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Repeats every',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          // Interval input
                          SizedBox(
                            width: 50,
                            child: TextFormField(
                              initialValue: interval.toString(),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8.0, horizontal: 8.0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey[700]!),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  interval = int.tryParse(value) ?? 1;
                                  if (interval < 1) interval = 1;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Frequency dropdown
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.0),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[700]!),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: DropdownButton<String>(
                                value: frequency,
                                isExpanded: true,
                                dropdownColor: Colors.grey[800],
                                style: const TextStyle(color: Colors.white),
                                icon: Icon(Icons.arrow_drop_down,
                                    color: Colors.white),
                                underline: Container(),
                                items: [
                                  DropdownMenuItem(
                                      value: 'day', child: Text('day')),
                                  DropdownMenuItem(
                                      value: 'week', child: Text('week')),
                                  DropdownMenuItem(
                                      value: 'month', child: Text('month')),
                                  DropdownMenuItem(
                                      value: 'year', child: Text('year')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      frequency = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Set time field - Show time from date selection and allow editing
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: TextFormField(
                        initialValue: timeValue, // Use the refreshed time value
                        readOnly: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Set time",
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          prefixIcon:
                              Icon(Icons.access_time, color: Colors.white),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                        ),
                        onTap: () async {
                          // Get current time from date string or use current time as fallback
                          TimeOfDay initialTime;
                          if (_dateController.text.isNotEmpty &&
                              _dateController.text.contains(":")) {
                            final timePart = _dateController.text.split(" ")[1];
                            final parts = timePart.split(":");
                            initialTime = TimeOfDay(
                              hour: int.parse(parts[0]),
                              minute: int.parse(parts[1]),
                            );
                          } else {
                            initialTime = TimeOfDay.now();
                          }

                          // Show time picker
                          final TimeOfDay? selectedTime = await showTimePicker(
                            context: context,
                            initialTime: initialTime,
                          );

                          if (selectedTime != null) {
                            // Parse existing date from the date controller
                            String currentDateStr = "";
                            if (_dateController.text.isNotEmpty &&
                                _dateController.text.contains(" ")) {
                              currentDateStr =
                                  _dateController.text.split(" ")[0];
                            } else {
                              // If no date, use today's date
                              final now = DateTime.now();
                              currentDateStr =
                                  "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                            }

                            // Update the date controller with new time
                            String newTimeStr =
                                "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}";

                            // Update both the original date controller and the current display
                            parentSetState(() {
                              _dateController.text =
                                  "$currentDateStr $newTimeStr";
                            });

                            // Force dialog to rebuild with new values
                            Navigator.of(context).pop();
                            _showRepeatOptionsDialog(
                                context,
                                parentSetState,
                                frequency,
                                interval,
                                endType,
                                endDateController,
                                occurrencesController,
                                onUpdate: onUpdate);
                          }
                        },
                      ),
                    ),
                    // Starts field - Make it editable
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
                      child: Text(
                        'Starts',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextFormField(
                        initialValue: dateValue, // Use the refreshed date value
                        readOnly: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon:
                              Icon(Icons.calendar_today, color: Colors.white),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                        ),
                        onTap: () async {
                          // Get current date from date string or use current date + 30 days as fallback
                          DateTime initialDate;
                          if (_dateController.text.isNotEmpty) {
                            final datePart = _dateController.text.split(" ")[0];
                            final parts = datePart.split("-");
                            initialDate = DateTime(
                              int.parse(parts[0]),
                              int.parse(parts[1]),
                              int.parse(parts[2]),
                            ).add(
                                Duration(days: 30)); // Default to 30 days ahead
                          } else {
                            initialDate =
                                DateTime.now().add(Duration(days: 30));
                          }

                          // Show date picker
                          final DateTime? selectedDate = await showDatePicker(
                            context: context,
                            initialDate: initialDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );

                          if (selectedDate != null) {
                            // Get current time from date string or use current time as fallback
                            TimeOfDay initialTime;
                            if (_dateController.text.isNotEmpty &&
                                _dateController.text.contains(":")) {
                              final timePart =
                                  _dateController.text.split(" ")[1];
                              final parts = timePart.split(":");
                              initialTime = TimeOfDay(
                                hour: int.parse(parts[0]),
                                minute: int.parse(parts[1]),
                              );
                            } else {
                              initialTime = TimeOfDay.now();
                            }

                            // Format the new date string
                            String newDateStr =
                                "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
                            String newTimeStr =
                                "${initialTime.hour.toString().padLeft(2, '0')}:${initialTime.minute.toString().padLeft(2, '0')}";

                            // Update both the original date controller and the current display
                            parentSetState(() {
                              _dateController.text = "$newDateStr $newTimeStr";
                            });

                            // Force dialog to rebuild with new values
                            Navigator.of(context).pop();
                            _showRepeatOptionsDialog(
                                context,
                                parentSetState,
                                frequency,
                                interval,
                                endType,
                                endDateController,
                                occurrencesController,
                                onUpdate: onUpdate);
                          }
                        },
                      ),
                    ),
                    // Ends section
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
                      child: Text(
                        'Ends',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),

                    // Never radio option
                    RadioListTile<String>(
                      title:
                          Text('Never', style: TextStyle(color: Colors.white)),
                      value: 'never',
                      groupValue: endType,
                      activeColor: Colors.blue,
                      onChanged: (value) {
                        setState(() {
                          endType = value!;
                        });
                      },
                    ),

                    // On specific date radio option
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'on',
                            groupValue: endType,
                            activeColor: Colors.blue,
                            onChanged: (value) {
                              setState(() {
                                endType = value!;

                                // Auto-set reasonable end date if not set
                                if (endDateController.text.isEmpty &&
                                    _dateController.text.isNotEmpty) {
                                  try {
                                    final datePart =
                                        _dateController.text.split(" ")[0];
                                    final parts = datePart.split("-");
                                    final startDate = DateTime(
                                      int.parse(parts[0]),
                                      int.parse(parts[1]),
                                      int.parse(parts[2]),
                                    );
                                    final endDate =
                                        startDate.add(Duration(days: 30));
                                    endDateController.text =
                                        "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
                                  } catch (e) {
                                    print("Error setting default end date: $e");
                                  }
                                }
                              });
                            },
                          ),
                          Text('On', style: TextStyle(color: Colors.white)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: endDateController,
                              readOnly: true,
                              enabled: endType == 'on',
                              style: TextStyle(
                                color: endType == 'on'
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                              decoration: InputDecoration(
                                hintText: "End date",
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey[700]!),
                                ),
                              ),
                              onTap: () async {
                                if (endType == 'on') {
                                  // Get current date from date string or use current date + 30 days as fallback
                                  DateTime initialDate;
                                  if (_dateController.text.isNotEmpty) {
                                    final datePart =
                                        _dateController.text.split(" ")[0];
                                    final parts = datePart.split("-");
                                    initialDate = DateTime(
                                      int.parse(parts[0]),
                                      int.parse(parts[1]),
                                      int.parse(parts[2]),
                                    ).add(Duration(
                                        days: 30)); // Default to 30 days ahead
                                  } else {
                                    initialDate =
                                        DateTime.now().add(Duration(days: 30));
                                  }

                                  DateTime? date = await showDatePicker(
                                    context: context,
                                    initialDate: initialDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime(2100),
                                  );

                                  if (date != null) {
                                    setState(() {
                                      // Format the end date properly
                                      endDateController.text =
                                          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                                    });
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // After X occurrences radio option
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'after',
                            groupValue: endType,
                            activeColor: Colors.blue,
                            onChanged: (value) {
                              setState(() {
                                endType = value!;
                                if (occurrencesController.text.isEmpty) {
                                  occurrencesController.text = '30';
                                }
                              });
                            },
                          ),
                          Text('After', style: TextStyle(color: Colors.white)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              controller: occurrencesController,
                              enabled: endType == 'after',
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: endType == 'after'
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8.0, horizontal: 8.0),
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
                          const SizedBox(width: 8),
                          Text('occurrences',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),

                    // Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              // Restore previous values and close dialog
                              endDateController.text = oldEndDate;
                              occurrencesController.text = oldOccurrences;
                              Navigator.of(context).pop();
                            },
                            child: Text('Cancel',
                                style: TextStyle(color: Colors.grey[300])),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              // Apply changes and close dialog
                              onUpdate(
                                  frequency,
                                  interval,
                                  endType,
                                  endDateController.text,
                                  occurrencesController.text);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[300],
                            ),
                            child: Text('Done'),
                          ),
                        ],
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

  Widget _taskList() {
    return FutureBuilder(
        future: _taskService.getTasks(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.5),
                borderRadius: AppTheme.borderRadiusMd,
                border: Border.all(
                  color: AppTheme.textSecondary.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: AppTheme.textSecondary.withOpacity(0.3),
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "No tasks yet",
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return Column(
            children: snapshot.data!.map<Widget>((task) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: GestureDetector(
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: AppTheme.borderRadiusLg,
                      color: AppTheme.surface.withOpacity(0.6),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: AppTheme.accent.withOpacity(0.15),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: task.deadline.isEmpty
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                task.label,
                                style: AppTheme.bodyMedium.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              if (task.deadline.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Functions.whenDue(task),
                                      ),
                                      if (task.repeatFrequency != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 8),
                                          child: Icon(
                                            Icons.repeat,
                                            color: AppTheme.accent,
                                            size: 10,
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              else
                                SizedBox(height: 14),
                            ],
                          ),
                        ),
                        Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: task.status == 1,
                                onChanged: (value) async {
                                  setState(() {
                                    _taskService.updateTaskStatus(
                                        task.id, value == true ? 1 : 0);
                                  });

                                  await Future.delayed(
                                      const Duration(milliseconds: 250));

                                  if (value == false) {
                                    // Task is being unchecked - subtract XP
                                    await _xpService.subtractTaskXP();
                              } else if (value == true) {
                                // Check if this task has repeating functionality
                                String? nextDeadlineStr;
                                if (task.repeatFrequency != null &&
                                    task.repeatInterval != null) {
                                  // Calculate the next occurrence date based on repeat settings
                                  DateTime nextDeadline =
                                      _calculateNextDeadline(task);
                                  nextDeadlineStr =
                                      _formatDateTime(nextDeadline);
                                }

                                // First, add the task to completed_tasks with next deadline info
                                await _completedTaskService.addCompletedTask(
                                  task.label,
                                  task.deadline,
                                  task.description,
                                  task.category,
                                  nextDeadline: nextDeadlineStr,
                                );

                                // Before deleting the original task, check if it has repeat functionality
                                if (task.repeatFrequency != null &&
                                    task.repeatInterval != null) {
                                  // Calculate the next occurrence date based on repeat settings
                                  DateTime nextDeadline =
                                      _calculateNextDeadline(task);

                                  // Check if we should create another occurrence based on end conditions
                                  bool shouldCreateNextOccurrence = true;

                                  // If "on" end type, check if next deadline is after the end date
                                  if (task.repeatEndType == 'on' &&
                                      task.repeatEndDate != null) {
                                    DateTime endDate =
                                        _parseDateTime(task.repeatEndDate!);
                                    shouldCreateNextOccurrence = nextDeadline
                                            .isBefore(endDate) ||
                                        nextDeadline.isAtSameMomentAs(endDate);
                                  }
                                  // If "after" end type, we need to update the occurrence count
                                  else if (task.repeatEndType == 'after' &&
                                      task.repeatOccurrences != null) {
                                    // Get count of occurrences needed to re-create this task
                                    int remainingOccurrences =
                                        task.repeatOccurrences! - 1;
                                    if (remainingOccurrences <= 0) {
                                      shouldCreateNextOccurrence = false;
                                    } else {
                                      // Create a new task with updated occurrence count
                                      await _taskService.addTask(
                                        task.label,
                                        _formatDateTime(nextDeadline),
                                        task.description,
                                        task.category,
                                        repeatFrequency: task.repeatFrequency,
                                        repeatInterval: task.repeatInterval,
                                        repeatEndType: task.repeatEndType,
                                        repeatEndDate: task.repeatEndDate,
                                        repeatOccurrences:
                                            remainingOccurrences, // Decrement occurrences
                                      );
                                      // Skip the standard task creation below since we've already created it with updated occurrence count
                                      shouldCreateNextOccurrence = false;
                                    }
                                  }

                                  // Create the next occurrence if needed (for 'never' end type or 'on' date that hasn't been reached)
                                  if (shouldCreateNextOccurrence) {
                                    // Format the next deadline
                                    String nextDeadlineStr =
                                        _formatDateTime(nextDeadline);

                                    // Get all current tasks to check for duplicates
                                    List<Task> currentTasks =
                                        await _taskService.getTasks();

                                    // Also get all pending tasks to check for duplicates
                                    final pendingTaskService =
                                        PendingTaskService();
                                    List<Task> pendingTasks =
                                        await pendingTaskService
                                            .getPendingTasks();

                                    // Check if a task with the same label and deadline already exists
                                    bool duplicateExists = currentTasks.any(
                                            (existingTask) =>
                                                existingTask.label ==
                                                    task.label &&
                                                existingTask.deadline ==
                                                    nextDeadlineStr) ||
                                        pendingTasks.any((existingTask) =>
                                            existingTask.label == task.label &&
                                            existingTask.deadline ==
                                                nextDeadlineStr);

                                    // Only create the new task if it doesn't already exist
                                    if (!duplicateExists) {
                                      // ALWAYS add to pending tasks instead of active tasks
                                      await pendingTaskService.addPendingTask(
                                        task.label,
                                        nextDeadlineStr,
                                        task.description,
                                        task.category,
                                        repeatFrequency: task.repeatFrequency,
                                        repeatInterval: task.repeatInterval,
                                        repeatEndType: task.repeatEndType,
                                        repeatEndDate: task.repeatEndDate,
                                        repeatOccurrences:
                                            task.repeatOccurrences,
                                      );
                                    }
                                  }
                                }

                                // Delete the original task
                                await _taskService.deleteTask(task.id);

                                // Award XP for completing the task
                                final xpResult = await _xpService.addTaskXP();

                                // Show XP gain bubble
                                showXPGainBubble(context, xpResult['xpGained']);

                                // Show level up animation if leveled up
                                if (xpResult['didLevelUp'] == true) {
                                  Future.delayed(
                                      const Duration(milliseconds: 300), () {
                                    showLevelUpAnimation(
                                      context,
                                      newLevel: xpResult['newLevel'],
                                      newRank: xpResult['userXP'].rank,
                                      xpGained: xpResult['xpGained'],
                                    );
                                  });
                                }
                              }
                              setState(() {});
                            },
                          ),
                        )
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
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface.withOpacity(0.5),
              borderRadius: AppTheme.borderRadiusMd,
              border: Border.all(
                color: AppTheme.textSecondary.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.repeat_rounded,
                    color: AppTheme.textSecondary.withOpacity(0.3),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "No habits yet",
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        List<Widget> habitWidgets = snapshot.data!
            .map<Widget>((habit) => GestureDetector(
                  onHorizontalDragStart: (details) async {
                    final newStatus = habit.status == 0 ? 1 : 0;
                    await _habitService.updateHabitStatus(habit.id, newStatus);

                    if (newStatus == 1) {
                      // Habit is being completed - award XP
                      final xpResult = await _xpService.addHabitXP();

                      // Show XP gain bubble
                      showXPGainBubble(context, xpResult['xpGained']);

                      // Show level up animation if leveled up
                      if (xpResult['didLevelUp'] == true) {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          showLevelUpAnimation(
                            context,
                            newLevel: xpResult['newLevel'],
                            newRank: xpResult['userXP'].rank,
                            xpGained: xpResult['xpGained'],
                          );
                        });
                      }
                    } else {
                      // Habit is being unchecked - subtract XP
                      await _xpService.subtractHabitXP();
                    }

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
    return FutureBuilder(
      future: _goalService.getGoals(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
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
                child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: AppTheme.borderRadiusLg,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.warning.withOpacity(0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                    border: Border.all(
                    color: AppTheme.warning.withOpacity(0.08),
                    width: 1.5,
                    ),
                  ),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                    Text(
                      goal.label,
                      textAlign: TextAlign.center,
                      style: AppTheme.headlineMedium.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                      const SizedBox(height: 12),
                      StreamBuilder(
                      stream: Stream.periodic(Duration(seconds: 1), (_) {
                        return deadline.difference(DateTime.now());
                      }),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return Text("Loading...");

                        Duration remaining = snapshot.data!;
                        if (remaining.isNegative) {
                          return Text(
                            "Overdue",
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          );
                        }

                        int days = remaining.inDays;
                        int hours = remaining.inHours % 24;
                        int minutes = remaining.inMinutes % 60;
                        int seconds = remaining.inSeconds % 60;

                        return Text(
                          "$days days · ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}",
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            letterSpacing: 0.2,
                          ),
                        );
                      },
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
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.15),
                      borderRadius: AppTheme.borderRadiusSm,
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: AppTheme.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Reading Progress",
                    style: AppTheme.headlineMedium.copyWith(fontSize: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                children: books.map((book) {
                  return GestureDetector(
                    onTap: () => _showUpdateBookDialog(context, book),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.surface,
                            AppTheme.surface.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: AppTheme.borderRadiusLg,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: AppTheme.accent.withOpacity(0.25),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.accent.withOpacity(0.25),
                                      AppTheme.accent.withOpacity(0.12),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.menu_book_rounded,
                                  color: AppTheme.accent,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  book.label,
                                  style: AppTheme.headlineSmall.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.background.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Page ${book.currentPage} of ${book.totalPages}',
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            AppTheme.accent.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "${(book.progress * 100).toStringAsFixed(0)}%",
                                        style: AppTheme.bodyMedium.copyWith(
                                          color: AppTheme.accent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppTheme.textSecondary
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: FractionallySizedBox(
                                      widthFactor: book.progress,
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.accent,
                                              AppTheme.accent.withOpacity(0.7),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

  Future<dynamic> _showCongratulationsDialog(
      BuildContext context, Goal goal) async {
    _goalService.deleteGoal(goal.id);

    // Award XP for completing goal
    final xpResult = await _xpService.addGoalXP();

    // Show XP gain bubble
    showXPGainBubble(context, xpResult['xpGained']);

    // Show level up animation if leveled up
    if (xpResult['didLevelUp'] == true) {
      showLevelUpAnimation(
        context,
        newLevel: xpResult['newLevel'],
        newRank: xpResult['userXP'].rank,
        xpGained: xpResult['xpGained'],
      );
    }

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
            SizedBox(height: 12),
            Text(
              "+${XPService.XP_GOAL_COMPLETE} XP",
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
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
            onPressed: () async {
              Navigator.pop(context);
              _bookServiceLib.deleteBook(book.id);

              // Award XP for completing book
              final xpResult = await _xpService.addBookXP();

              // Show XP gain bubble
              showXPGainBubble(context, xpResult['xpGained']);

              // Show level up animation if leveled up
              if (xpResult['didLevelUp'] == true) {
                showLevelUpAnimation(
                  context,
                  newLevel: xpResult['newLevel'],
                  newRank: xpResult['userXP'].rank,
                  xpGained: xpResult['xpGained'],
                );
              }

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

  Widget _buildHomePage() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Header with gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.accent.withOpacity(0.15),
                AppTheme.background,
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Good Productive\n${function.getTimeOfDayDescription()}",
                      style: AppTheme.displayLarge.copyWith(
                        height: 1.2,
                        fontSize: 28,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await BackgroundTaskManager.runAllTasksNow();
                      _loadStoredQuote();
                    },
                    icon: Icon(Icons.refresh_rounded, color: AppTheme.accent),
                    iconSize: 28,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const XPBar(),
              const SizedBox(height: 15),
            ],
          ),
        ),
        
        // Content area
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Daily Quote Card
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: AppTheme.borderRadiusLg,
                    boxShadow: AppTheme.shadowMd,
                    border: Border.all(
                      color: AppTheme.accent.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: _currentDailyQuote == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: CircularProgressIndicator(color: AppTheme.accent),
                          ),
                        )
                      : Column(
                          children: [
                            Icon(
                              Icons.format_quote,
                              color: AppTheme.accent.withOpacity(0.3),
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _currentDailyQuote!.text,
                              textAlign: TextAlign.center,
                              style: AppTheme.bodyLarge.copyWith(
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "— ${_currentDailyQuote!.author}",
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Goals Section
              FutureBuilder(
                future: _goalService.getGoals(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: Text(
                          "Long-Term Goals",
                          style: AppTheme.headlineMedium.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _goalList(),
                      const SizedBox(height: 30),
                    ],
                  );
                },
              ),
              
              // Tasks and Habits Grid
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTasksSection(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildHabitsSection(),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // Books Section
              _bookList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Text(
            "Tasks Today",
            style: AppTheme.headlineMedium.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _taskList(),
      ],
    );
  }

  Widget _buildHabitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.15),
                borderRadius: AppTheme.borderRadiusSm,
              ),
              child: Icon(
                Icons.repeat_rounded,
                color: AppTheme.success,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "Daily Habits",
              style: AppTheme.headlineSmall.copyWith(fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _habitList(),
      ],
    );
  }

  // Helper method  // Helper method to calculate the next deadline based on repeat settings
  DateTime _calculateNextDeadline(Task task) {
    // Parse the current deadline
    DateTime currentDeadline = _parseDateTime(task.deadline);
    int interval = task.repeatInterval ?? 1;

    // Calculate next deadline based on frequency
    DateTime nextDeadline;
    switch (task.repeatFrequency) {
      case 'day':
        nextDeadline = currentDeadline.add(Duration(days: interval));
        break;
      case 'week':
        nextDeadline = currentDeadline.add(Duration(days: 7 * interval));
        break;
      case 'month':
        // Add months by calculating days (approximate)
        int year = currentDeadline.year;
        int month = currentDeadline.month + interval;
        int day = currentDeadline.day;

        // Handle month overflow
        while (month > 12) {
          month -= 12;
          year++;
        }

        // Handle day validity for the month (e.g., Feb 30 -> Feb 28/29)
        int daysInMonth = DateTime(year, month + 1, 0).day;
        if (day > daysInMonth) {
          day = daysInMonth;
        }

        nextDeadline = DateTime(
            year, month, day, currentDeadline.hour, currentDeadline.minute);
        break;
      case 'year':
        // Add years
        nextDeadline = DateTime(
            currentDeadline.year + interval,
            currentDeadline.month,
            currentDeadline.day,
            currentDeadline.hour,
            currentDeadline.minute);
        break;
      default:
        // Default to daily if something goes wrong
        nextDeadline = currentDeadline.add(Duration(days: interval));
    }

    return nextDeadline;
  }

  // Helper method to parse date string into DateTime
  DateTime _parseDateTime(String dateString) {
    try {
      if (dateString.isEmpty) {
        return DateTime.now(); // Default to now if empty
      }

      List<String> parts = dateString.split(' ');
      String datePart = parts[0];
      String timePart = parts.length > 1 ? parts[1] : "00:00";

      List<String> dateParts = datePart.split('-');
      List<String> timeParts = timePart.split(':');

      return DateTime(
        int.parse(dateParts[0]), // year
        int.parse(dateParts[1]), // month
        int.parse(dateParts[2]), // day
        int.parse(timeParts[0]), // hour
        int.parse(timeParts[1]), // minute
      );
    } catch (e) {
      print("Error parsing date: $e for string: $dateString");
      return DateTime.now(); // Default to now if parsing fails
    }
  }

  // Helper method to format DateTime back to string format used by the app
  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} "
        "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  @override
  bool get wantKeepAlive => true;
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

class _HomePageContent extends StatelessWidget {
  const _HomePageContent();

  @override
  Widget build(BuildContext context) {
    final homePageState = context.findAncestorStateOfType<HomePageState>();
    return homePageState!._buildHomePage();
  }
}
