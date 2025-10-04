import 'dart:async';
import 'package:mental_warior/models/goals.dart';
import 'package:mental_warior/models/tasks.dart';
import 'package:mental_warior/models/habits.dart';
import 'package:mental_warior/models/books.dart';
import 'package:mental_warior/models/categories.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:mental_warior/services/foreground_service.dart';
import 'package:mental_warior/utils/functions.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  static Database? _db;
  static final DatabaseService instance = DatabaseService._constructor();
  static final ValueNotifier<bool> habitsUpdatedNotifier = ValueNotifier(false);

  DatabaseService._constructor();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await getDatabase();
    return _db!;
  }

  Future<Database> getDatabase() async {
    final databaseDirPath = await getDatabasesPath();
    final databasePath = join(databaseDirPath, "maste_db.db");

    return openDatabase(
      databasePath,
      version: 6, // Increment version for exercise finished flag
      onConfigure: (db) async {
        // Enable foreign key support
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) {
        TaskService().createTaskTable(db);
        CompletedTaskService().createCompletedTaskTable(db);
        PendingTaskService().createPendingTaskTable(db);
        HabitService().createHabitTable(db);
        GoalService().createGoalTable(db);
        BookService().createbookTable(db);
        CategoryService().createCategoryTable(db);
        WorkoutService().createWorkoutTables(db); // Added workout tables
        WorkoutService().createActiveWorkoutSessionsTable(
            db); // Added active sessions table
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          // Create workout tables if upgrading from a previous version
          await WorkoutService().createWorkoutTables(db);
        }
        if (oldVersion < 5) {
          // Create active workout sessions table for persistent state storage
          await WorkoutService().createActiveWorkoutSessionsTable(db);
        }
        if (oldVersion < 6) {
          // Add finished flag to exercises table
          await db.execute(
              'ALTER TABLE exercises ADD COLUMN finished INTEGER DEFAULT 0');
        }
      },
    );
  }
}

class TaskService {
  static final ValueNotifier<bool> tasksUpdatedNotifier = ValueNotifier(false);
  final String _taskTableName = "tasks";
  final String _taskIdColumnName = "id";
  final String _taskLabelColumnName = "label";
  final String _taskStatusColumnName = "status";
  final String _taskDescriptionColumnName = "description";
  final String _taskDeadlineColumnName = "deadline";
  final String _taskCategoryColumnName = "category";
  final String _taskRepeatFrequencyColumnName = "repeatFrequency";
  final String _taskRepeatIntervalColumnName = "repeatInterval";
  final String _taskRepeatEndTypeColumnName = "repeatEndType";
  final String _taskRepeatEndDateColumnName = "repeatEndDate";
  final String _taskRepeatOccurrencesColumnName = "repeatOccurrences";

  void createTaskTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_taskTableName (
        $_taskIdColumnName INTEGER PRIMARY KEY,
        $_taskLabelColumnName TEXT NOT NULL,
        $_taskStatusColumnName INTEGER NOT NULL,
        $_taskDeadlineColumnName TEXT,
        $_taskDescriptionColumnName TEXT,
        $_taskCategoryColumnName TEXT,
        $_taskRepeatFrequencyColumnName TEXT,
        $_taskRepeatIntervalColumnName INTEGER,
        $_taskRepeatEndTypeColumnName TEXT,
        $_taskRepeatEndDateColumnName TEXT,
        $_taskRepeatOccurrencesColumnName INTEGER
      ) 
    ''');
  }

  Future<void> addTask(
    String label,
    String deadline,
    String description,
    String category, {
    String? repeatFrequency,
    int? repeatInterval,
    String? repeatEndType,
    String? repeatEndDate,
    int? repeatOccurrences,
  }) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      _taskTableName,
      {
        _taskLabelColumnName: label,
        _taskStatusColumnName: 0,
        _taskDeadlineColumnName: deadline,
        _taskDescriptionColumnName: description,
        _taskCategoryColumnName: category,
        _taskRepeatFrequencyColumnName: repeatFrequency,
        _taskRepeatIntervalColumnName: repeatInterval,
        _taskRepeatEndTypeColumnName: repeatEndType,
        _taskRepeatEndDateColumnName: repeatEndDate,
        _taskRepeatOccurrencesColumnName: repeatOccurrences,
      },
    );
    tasksUpdatedNotifier.value = !tasksUpdatedNotifier.value;
  }

  Future<List<Task>> getTasks() async {
    final db = await DatabaseService.instance.database;
    final data = await db.query(
      _taskTableName,
      orderBy: '''
        CASE 
      WHEN $_taskDeadlineColumnName IS NULL OR $_taskDeadlineColumnName = '' THEN 1 
        ELSE 0 
      END, 
     $_taskDeadlineColumnName ASC
      ''',
    );

    return data
        .map(
          (e) => Task(
            id: e[_taskIdColumnName] as int,
            label: e[_taskLabelColumnName] as String,
            status: e[_taskStatusColumnName] as int,
            description: e[_taskDescriptionColumnName] as String,
            deadline: e[_taskDeadlineColumnName] as String,
            category: e[_taskCategoryColumnName] as String,
            repeatFrequency: e[_taskRepeatFrequencyColumnName] as String?,
            repeatInterval: e[_taskRepeatIntervalColumnName] as int?,
            repeatEndType: e[_taskRepeatEndTypeColumnName] as String?,
            repeatEndDate: e[_taskRepeatEndDateColumnName] as String?,
            repeatOccurrences: e[_taskRepeatOccurrencesColumnName] as int?,
          ),
        )
        .toList();
  }

  Future<void> updateTaskStatus(int id, int status) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      _taskTableName,
      {_taskStatusColumnName: status},
      where: "id = ?",
      whereArgs: [id],
    );
  }

  Future<void> deleteTask(int id) async {
    final db = await DatabaseService.instance.database;
    await db.delete(_taskTableName, where: "id = ?", whereArgs: [id]);
  }

  Future<void> updateTask(int id, String fieldToUpdate, dynamic value) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      _taskTableName,
      {fieldToUpdate: value},
      where: "id = ?",
      whereArgs: [id],
    );
    tasksUpdatedNotifier.value = !tasksUpdatedNotifier.value;
  }
}

class CompletedTaskService {
  final String _completedTaskTableName = "completed_tasks";
  final String _taskIdColumnName = "id";
  final String _taskLabelColumnName = "label";
  final String _taskStatusColumnName = "status";
  final String _taskDescriptionColumnName = "description";
  final String _taskDeadlineColumnName = "deadline";
  final String _taskCategoryColumnName = "category";
  final String _taskNextDeadlineColumnName = "nextDeadline";

  void createCompletedTaskTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_completedTaskTableName (
        $_taskIdColumnName INTEGER PRIMARY KEY,
        $_taskLabelColumnName TEXT NOT NULL,
        $_taskStatusColumnName INTEGER NOT NULL,
        $_taskDeadlineColumnName TEXT,
        $_taskDescriptionColumnName TEXT,
        $_taskCategoryColumnName TEXT,
        $_taskNextDeadlineColumnName TEXT
      )
    ''');
  }

  Future addCompletedTask(
      String label, String deadline, String description, String category,
      {String? nextDeadline}) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      _completedTaskTableName,
      {
        _taskLabelColumnName: label,
        _taskStatusColumnName: 0,
        _taskDeadlineColumnName: deadline,
        _taskDescriptionColumnName: description,
        _taskCategoryColumnName: category,
        _taskNextDeadlineColumnName: nextDeadline,
      },
    );
  }

  Future<List<Task>> getCompletedTasks() async {
    final db = await DatabaseService.instance.database;
    final data = await db.query(_completedTaskTableName);

    return data
        .map(
          (e) => Task(
            id: e[_taskIdColumnName] as int,
            label: e[_taskLabelColumnName] as String,
            status: e[_taskStatusColumnName] as int,
            description: e[_taskDescriptionColumnName] as String,
            deadline: e[_taskDeadlineColumnName] as String,
            category: e[_taskCategoryColumnName] as String,
            nextDeadline: e[_taskNextDeadlineColumnName] as String?,
          ),
        )
        .toList();
  }

  Future deleteCompTask(int id) async {
    final db = await DatabaseService.instance.database;
    await db.delete(_completedTaskTableName, where: "id = ?", whereArgs: [id]);
  }

  Future updateCompTaskStatus(int id, int status) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      _completedTaskTableName,
      {_taskStatusColumnName: status},
      where: "id = ?",
      whereArgs: [id],
    );
  }

  Future updateCompletedTask(int id, String fieldToUpdate, String key) async {
    final db = await DatabaseService.instance.database;

    db.update(
      _completedTaskTableName,
      {fieldToUpdate: key},
      where: "id = ?",
      whereArgs: [id],
    );
  }
}

class HabitService {
  final String _habitTableName = "habits";
  final String _habitIdColumnName = "id";
  final String _habitLabelColumnName = "label";
  final String _habitStatusColumnName = "status";
  final String _habitDescriptionColumnName = "description";

  void createHabitTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_habitTableName (
        $_habitIdColumnName INTEGER PRIMARY KEY,
        $_habitLabelColumnName TEXT NOT NULL,
        $_habitStatusColumnName INTEGER NOT NULL,
        $_habitDescriptionColumnName TEXT
      ) 
    ''');
  }

  Future addHabit(String label, String description) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      _habitTableName,
      {
        _habitLabelColumnName: label,
        _habitStatusColumnName: 0,
        _habitDescriptionColumnName: description,
      },
    );
  }

  Future<List<Habit>> getHabits() async {
    final db = await DatabaseService.instance.database;
    final data = await db.query(
      _habitTableName,
    );

    return data
        .map(
          (e) => Habit(
            id: e[_habitIdColumnName] as int,
            label: e[_habitLabelColumnName] as String,
            status: e[_habitStatusColumnName] as int,
            description: e[_habitDescriptionColumnName] as String,
          ),
        )
        .toList();
  }

  Future updateHabitStatus(int id, int status) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      _habitTableName,
      {_habitStatusColumnName: status},
      where: "id = ?",
      whereArgs: [id],
    );
  }

  Future deleteHabit(int id) async {
    final db = await DatabaseService.instance.database;
    await db.delete(
      _habitTableName,
      where: "id = ?",
      whereArgs: [id],
    );
  }

  void updateHabit(int id, String fieldToUpdate, String key) async {
    final db = await DatabaseService.instance.database;

    db.update(
      _habitTableName,
      {fieldToUpdate: key},
      where: "id = ?",
      whereArgs: [id],
    );
  }

  Future<void> resetAllHabits() async {
    try {
      final db = await DatabaseService.instance.database;

      List<Map<String, dynamic>> habitList = await db.query(_habitTableName);

      if (habitList.isEmpty) {
        print("No habits found in database.");
        return;
      }

      for (var habit in habitList) {
        int habitId = habit[_habitIdColumnName];

        await db.update(
          _habitTableName,
          {_habitStatusColumnName: 0},
          where: "id = ?",
          whereArgs: [habitId],
        );
      }
    } catch (e) {
      print("❌ ERROR in resetAllHabits: $e");
    }
  }

  Future<Habit?> getHabitByLabel(String label) async {
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _habitTableName,
      where: "$_habitLabelColumnName = ?",
      whereArgs: [label],
    );

    if (maps.isNotEmpty) {
      return Habit(
        id: maps.first[_habitIdColumnName] as int,
        label: maps.first[_habitLabelColumnName] as String,
        status: maps.first[_habitStatusColumnName] as int,
        description: maps.first[_habitDescriptionColumnName] as String,
      );
    } else {
      return null;
    }
  }

  Future<void> updateHabitStatusByLabel(String label, int status) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      _habitTableName,
      {_habitStatusColumnName: status},
      where: "$_habitLabelColumnName = ?",
      whereArgs: [label],
    );
  }
}

class GoalService {
  final String _goalTableName = "goals";
  final String _goalIdColumnName = "id";
  final String _goalLabelColumnName = "label";
  final String _goalStatusColumnName = "status";
  final String _goalDescriptionColumnName = "description";
  final String _goalDeadlineColumnName = "deadline";

  void createGoalTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_goalTableName (
        $_goalIdColumnName INTEGER PRIMARY KEY,
        $_goalLabelColumnName TEXT NOT NULL,
        $_goalStatusColumnName INTEGER NOT NULL,
        $_goalDeadlineColumnName TEXT,
        $_goalDescriptionColumnName TEXT
      ) 
    ''');
  }

  Future addGoal(String label, String deadline, String description) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      _goalTableName,
      {
        _goalLabelColumnName: label,
        _goalStatusColumnName: 0,
        _goalDeadlineColumnName: deadline,
        _goalDescriptionColumnName: description,
      },
    );
  }

  Future<List<Goal>> getGoals() async {
    final db = await DatabaseService.instance.database;
    final data = await db.query(
      _goalTableName,
    );

    return data
        .map(
          (e) => Goal(
            id: e[_goalIdColumnName] as int,
            label: e[_goalLabelColumnName] as String,
            status: e[_goalStatusColumnName] as int,
            description: e[_goalDescriptionColumnName] as String,
            deadline: e[_goalDeadlineColumnName] as String,
          ),
        )
        .toList();
  }

  void updateGoalStatus(int id, int status) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      _goalTableName,
      {_goalStatusColumnName: status},
      where: "id = ?",
      whereArgs: [id],
    );
  }

  Future deleteGoal(int id) async {
    final db = await DatabaseService.instance.database;
    await db.delete(_goalTableName, where: "id = ?", whereArgs: [id]);
  }

  void updateGoal(int id, String fieldToUpdate, String key) async {
    final db = await DatabaseService.instance.database;

    db.update(
      _goalTableName,
      {fieldToUpdate: key},
      where: "id = ?",
      whereArgs: [id],
    );
  }
}

class BookService {
  final String _bookTableName = "books";
  final String _bookIdColumnName = "id";
  final String _bookLabelColumnName = "label";
  final String _bookTimeStampColumnName = "timeStamp";
  final String _bookTotalPagesColumnName = "totalPages";
  final String _bookCurrentPageColmunName = "currentPage";

  void createbookTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_bookTableName (
        $_bookIdColumnName INTEGER PRIMARY KEY,
        $_bookLabelColumnName TEXT NOT NULL,
        $_bookTimeStampColumnName TEXT,
        $_bookTotalPagesColumnName INTEGER NOT NULL,
        $_bookCurrentPageColmunName INTEGER
      ) 
    ''');
  }

  Future addBook(
    String label,
    int totalPages,
  ) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      _bookTableName,
      {
        _bookLabelColumnName: label,
        _bookTimeStampColumnName: TimeOfDay.now().toString(),
        _bookTotalPagesColumnName: totalPages,
        _bookCurrentPageColmunName: 0,
      },
    );
  }

  Future<List<Book>> getBooks() async {
    final db = await DatabaseService.instance.database;
    final data = await db.query(
      _bookTableName,
    );

    return data
        .map(
          (e) => Book(
            id: e[_bookIdColumnName] as int,
            label: e[_bookLabelColumnName] as String,
            timeStamp: e[_bookTimeStampColumnName] as String,
            totalPages: e[_bookTotalPagesColumnName] as int,
            currentPage: e[_bookCurrentPageColmunName] as int,
          ),
        )
        .toList();
  }

  Future deleteBook(int id) async {
    final db = await DatabaseService.instance.database;
    await db.delete(_bookTableName, where: "id = ?", whereArgs: [id]);
  }

  Future<bool> updateBookCurrentPage(int id, int page) async {
    final db = await DatabaseService.instance.database;

    await db.update(
      _bookTableName,
      {_bookCurrentPageColmunName: page},
      where: "id = ?",
      whereArgs: [id],
    );

    final List<Map<String, dynamic>> result = await db.query(
      _bookTableName,
      where: "id = ?",
      whereArgs: [id],
    );

    if (result.isEmpty) return false;

    Book book = Book.fromMap(result.first);

    if (book.currentPage == book.totalPages) {
      return true;
    }

    return false;
  }
}

class CategoryService {
  final String _categoryTableName = "categories";
  final String _categoryIdColumnName = "id";
  final String _categoryLabelColumnName = "label";
  final String _categoryIsDefaultColumnName = "isDefault";

  void createCategoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_categoryTableName (
        $_categoryIdColumnName INTEGER PRIMARY KEY,
        $_categoryLabelColumnName TEXT NOT NULL UNIQUE,
        $_categoryIsDefaultColumnName INTEGER NOT NULL
      ) 
    ''');

    // Insert the default category if it doesn't already exist
    await db.insert(
      _categoryTableName,
      {
        _categoryLabelColumnName: "Default",
        _categoryIsDefaultColumnName: 1,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore, // Prevent duplicate entries
    );
  }

  Future addCategory(String label) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      _categoryTableName,
      {
        _categoryLabelColumnName: label,
        _categoryIsDefaultColumnName: 0,
      },
    );
  }

  Future<List<Category>> getCategories() async {
    final db = await DatabaseService.instance.database;
    final data = await db.query(
      _categoryTableName,
    );

    return data
        .map(
          (e) => Category(
            id: e[_categoryIdColumnName] as int,
            label: e[_categoryLabelColumnName] as String,
            isDefault: e[_categoryIsDefaultColumnName] as int,
          ),
        )
        .toList();
  }

  Future<bool> deleteCategory(int id) async {
    final db = await DatabaseService.instance.database;

    // Check if the category is the default category
    final category = await db.query(
      _categoryTableName,
      where: "$_categoryIdColumnName = ?",
      whereArgs: [id],
    );

    if (category.isNotEmpty &&
        category.first[_categoryIsDefaultColumnName] == 1) {
      // Prevent deletion of the default category
      return false;
    }

    // Proceed with deletion for non-default categories
    await db.delete(_categoryTableName, where: "id = ?", whereArgs: [id]);
    return true;
  }

  Future<Category> getDefaultCategory() async {
    final db = await DatabaseService.instance.database;

    // Query the database for the default category
    final List<Map<String, dynamic>> result = await db.query(
      _categoryTableName,
      where: "$_categoryIsDefaultColumnName = ?",
      whereArgs: [1],
    );

    // Return the default category if it exists
    if (result.isNotEmpty) {
      return Category(
        id: result.first[_categoryIdColumnName] as int,
        label: result.first[_categoryLabelColumnName] as String,
        isDefault: result.first[_categoryIsDefaultColumnName] as int,
      );
    }

    // Throw an exception if no default category is found
    throw Exception("Default category not found");
  }
}

// Add a new PendingTaskService for storing future repeating tasks
class PendingTaskService {
  final String _pendingTaskTableName = "pending_tasks";
  final String _taskIdColumnName = "id";
  final String _taskLabelColumnName = "label";
  final String _taskStatusColumnName = "status";
  final String _taskDescriptionColumnName = "description";
  final String _taskDeadlineColumnName = "deadline";
  final String _taskCategoryColumnName = "category";
  final String _taskRepeatFrequencyColumnName = "repeatFrequency";
  final String _taskRepeatIntervalColumnName = "repeatInterval";
  final String _taskRepeatEndTypeColumnName = "repeatEndType";
  final String _taskRepeatEndDateColumnName = "repeatEndDate";
  final String _taskRepeatOccurrencesColumnName = "repeatOccurrences";

  void createPendingTaskTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_pendingTaskTableName (
        $_taskIdColumnName INTEGER PRIMARY KEY,
        $_taskLabelColumnName TEXT NOT NULL,
        $_taskStatusColumnName INTEGER NOT NULL,
        $_taskDeadlineColumnName TEXT NOT NULL,
        $_taskDescriptionColumnName TEXT,
        $_taskCategoryColumnName TEXT,
        $_taskRepeatFrequencyColumnName TEXT,
        $_taskRepeatIntervalColumnName INTEGER,
        $_taskRepeatEndTypeColumnName TEXT,
        $_taskRepeatEndDateColumnName TEXT,
        $_taskRepeatOccurrencesColumnName INTEGER
      ) 
    ''');
  }

  Future<void> addPendingTask(
    String label,
    String deadline,
    String description,
    String category, {
    String? repeatFrequency,
    int? repeatInterval,
    String? repeatEndType,
    String? repeatEndDate,
    int? repeatOccurrences,
  }) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      _pendingTaskTableName,
      {
        _taskLabelColumnName: label,
        _taskStatusColumnName: 0,
        _taskDeadlineColumnName: deadline,
        _taskDescriptionColumnName: description,
        _taskCategoryColumnName: category,
        _taskRepeatFrequencyColumnName: repeatFrequency,
        _taskRepeatIntervalColumnName: repeatInterval,
        _taskRepeatEndTypeColumnName: repeatEndType,
        _taskRepeatEndDateColumnName: repeatEndDate,
        _taskRepeatOccurrencesColumnName: repeatOccurrences,
      },
    );
  }

  Future<List<Task>> getPendingTasks() async {
    final db = await DatabaseService.instance.database;
    final data = await db.query(_pendingTaskTableName);

    return data
        .map(
          (e) => Task(
            id: e[_taskIdColumnName] as int,
            label: e[_taskLabelColumnName] as String,
            status: e[_taskStatusColumnName] as int,
            description: e[_taskDescriptionColumnName] as String,
            deadline: e[_taskDeadlineColumnName] as String,
            category: e[_taskCategoryColumnName] as String,
            repeatFrequency: e[_taskRepeatFrequencyColumnName] as String?,
            repeatInterval: e[_taskRepeatIntervalColumnName] as int?,
            repeatEndType: e[_taskRepeatEndTypeColumnName] as String?,
            repeatEndDate: e[_taskRepeatEndDateColumnName] as String?,
            repeatOccurrences: e[_taskRepeatOccurrencesColumnName] as int?,
          ),
        )
        .toList();
  }

  Future<void> deletePendingTask(int id) async {
    final db = await DatabaseService.instance.database;
    await db.delete(_pendingTaskTableName, where: "id = ?", whereArgs: [id]);
  }

  // Check for pending tasks that are due today (on the actual day of the deadline)
  Future<void> checkForDueTasks() async {
    final TaskService taskService = TaskService();

    // Get today's date at the start of the day (midnight)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Get all pending tasks
    final pendingTasks = await getPendingTasks();

    for (final task in pendingTasks) {
      try {
        // Parse the task deadline
        final deadlineStr =
            task.deadline.split(" ")[0]; // Get just the date part
        final parts = deadlineStr.split("-");
        final taskDate = DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));

        // Only activate tasks that are due today (exactly on the deadline date)
        // This ensures tasks appear only on the day they're due, not a day before
        if (taskDate.year == today.year &&
            taskDate.month == today.month &&
            taskDate.day == today.day) {
          print(
              "📅 Activating task '${task.label}' due today on ${task.deadline}");

          // Add to active tasks
          await taskService.addTask(
            task.label,
            task.deadline,
            task.description,
            task.category,
            repeatFrequency: task.repeatFrequency,
            repeatInterval: task.repeatInterval,
            repeatEndType: task.repeatEndType,
            repeatEndDate: task.repeatEndDate,
            repeatOccurrences: task.repeatOccurrences,
          );

          // Remove from pending tasks
          await deletePendingTask(task.id);
        }
      } catch (e) {
        print("Error processing pending task: $e");
      }
    }

    // Notify listeners that tasks may have changed
    TaskService.tasksUpdatedNotifier.value =
        !TaskService.tasksUpdatedNotifier.value;
  }
}

// Add a new WorkoutService class at the end of the file
class WorkoutService {
  static final ValueNotifier<bool> workoutsUpdatedNotifier =
      ValueNotifier(false);
  
  // Add a ValueNotifier to track temporary workouts
  static final ValueNotifier<Map<int, dynamic>> tempWorkoutsNotifier =
      ValueNotifier({});

  // Add a ValueNotifier to track the active workout
  static final ValueNotifier<Map<String, dynamic>?> activeWorkoutNotifier =
      ValueNotifier(null);

  // Counter to ensure unique temporary IDs
  static int _tempIdCounter = 0;

  // Table & column names
  final String _workoutTableName = "workouts";
  final String _workoutIdColumnName = "id";
  final String _workoutNameColumnName = "name";
  final String _workoutDateColumnName = "date";
  final String _workoutDurationColumnName = "duration";

  final String _exerciseTableName = "exercises";
  final String _exerciseIdColumnName = "id";
  final String _exerciseWorkoutIdColumnName = "workoutId";
  final String _exerciseNameColumnName = "name";
  final String _exerciseEquipmentColumnName = "equipment";
  final String _exerciseFinishedColumnName = "finished";

  final String _setTableName = "exercise_sets";
  final String _setIdColumnName = "id";
  final String _setExerciseIdColumnName = "exerciseId";
  final String _setNumberColumnName = "setNumber";
  final String _setWeightColumnName = "weight";
  final String _setRepsColumnName = "reps";
  final String _setRestTimeColumnName = "restTime";
  final String _setCompletedColumnName = "completed";
  final String _setVolumeColumnName = "volume";
  final String _setIsPRColumnName = "isPR";

  // Active workout sessions table (for persistent state storage across app restarts)
  final String _activeWorkoutSessionsTableName = "active_workout_sessions";
  final String _activeSessionIdColumnName = "id";
  final String _activeSessionWorkoutIdColumnName = "workout_id";
  final String _activeSessionWorkoutDataColumnName = "workout_data";
  final String _activeSessionElapsedSecondsColumnName = "elapsed_seconds";
  final String _activeSessionStartTimeColumnName = "start_time";
  final String _activeSessionIsTemporaryColumnName = "is_temporary";
  final String _activeSessionCreatedAtColumnName = "created_at";
  final String _activeSessionUpdatedAtColumnName = "updated_at";

  // Create tables for workouts, exercises, and sets
  Future<void> createWorkoutTables(Database db) async {
    // Create workout table
    await db.execute('''
      CREATE TABLE $_workoutTableName (
        $_workoutIdColumnName INTEGER PRIMARY KEY,
        $_workoutNameColumnName TEXT NOT NULL,
        $_workoutDateColumnName TEXT NOT NULL,
        $_workoutDurationColumnName INTEGER NOT NULL
      )
    ''');

    // Create exercise table
    await db.execute('''
      CREATE TABLE $_exerciseTableName (
        $_exerciseIdColumnName INTEGER PRIMARY KEY,
        $_exerciseWorkoutIdColumnName INTEGER NOT NULL,
        $_exerciseNameColumnName TEXT NOT NULL,
        $_exerciseEquipmentColumnName TEXT NOT NULL,
        $_exerciseFinishedColumnName INTEGER DEFAULT 0,
        FOREIGN KEY ($_exerciseWorkoutIdColumnName) REFERENCES $_workoutTableName ($_workoutIdColumnName) ON DELETE CASCADE
      )
    ''');

    // Create sets table
    await db.execute('''
      CREATE TABLE $_setTableName (
        $_setIdColumnName INTEGER PRIMARY KEY,
        $_setExerciseIdColumnName INTEGER NOT NULL,
        $_setNumberColumnName INTEGER NOT NULL,
        $_setWeightColumnName REAL NOT NULL,
        $_setRepsColumnName INTEGER NOT NULL,
        $_setRestTimeColumnName INTEGER NOT NULL,
        $_setCompletedColumnName INTEGER NOT NULL,
        $_setVolumeColumnName REAL NOT NULL,
        $_setIsPRColumnName INTEGER DEFAULT 0,
        FOREIGN KEY ($_setExerciseIdColumnName) REFERENCES $_exerciseTableName ($_exerciseIdColumnName) ON DELETE CASCADE
      )
    ''');
  }

  // Create active workout sessions table for persistent state storage
  Future<void> createActiveWorkoutSessionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_activeWorkoutSessionsTableName (
        $_activeSessionIdColumnName INTEGER PRIMARY KEY,
        $_activeSessionWorkoutIdColumnName INTEGER NOT NULL,
        $_activeSessionWorkoutDataColumnName TEXT NOT NULL,
        $_activeSessionElapsedSecondsColumnName INTEGER NOT NULL,
        $_activeSessionStartTimeColumnName INTEGER,
        $_activeSessionIsTemporaryColumnName INTEGER NOT NULL,
        $_activeSessionCreatedAtColumnName INTEGER NOT NULL,
        $_activeSessionUpdatedAtColumnName INTEGER NOT NULL
      )
    ''');
  }

  // Save active workout session state to database
  Future<void> saveActiveWorkoutSession({
    required int workoutId,
    required String workoutData,
    required int elapsedSeconds,
    required bool isTemporary,
    DateTime? startTime,
  }) async {
    final db = await DatabaseService.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // First, clear any existing active sessions to ensure only one active session at a time
    await clearActiveWorkoutSessions();

    await db.insert(
      _activeWorkoutSessionsTableName,
      {
        _activeSessionWorkoutIdColumnName: workoutId,
        _activeSessionWorkoutDataColumnName: workoutData,
        _activeSessionElapsedSecondsColumnName: elapsedSeconds,
        _activeSessionStartTimeColumnName: startTime?.millisecondsSinceEpoch,
        _activeSessionIsTemporaryColumnName: isTemporary ? 1 : 0,
        _activeSessionCreatedAtColumnName: now,
        _activeSessionUpdatedAtColumnName: now,
      },
    );

    print(
        'Active workout session saved to database for workout ID: $workoutId');
  }

  // Update existing active workout session
  Future<void> updateActiveWorkoutSession({
    required int workoutId,
    required String workoutData,
    required int elapsedSeconds,
  }) async {
    final db = await DatabaseService.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final result = await db.update(
      _activeWorkoutSessionsTableName,
      {
        _activeSessionWorkoutDataColumnName: workoutData,
        _activeSessionElapsedSecondsColumnName: elapsedSeconds,
        _activeSessionUpdatedAtColumnName: now,
      },
      where: '$_activeSessionWorkoutIdColumnName = ?',
      whereArgs: [workoutId],
    );

    // If no existing session was updated, create a new one
    if (result == 0) {
      await saveActiveWorkoutSession(
        workoutId: workoutId,
        workoutData: workoutData,
        elapsedSeconds: elapsedSeconds,
        isTemporary: workoutId < 0,
      );
    }
  }

  // Retrieve active workout session
  Future<Map<String, dynamic>?> getActiveWorkoutSession() async {
    final db = await DatabaseService.instance.database;

    final result = await db.query(
      _activeWorkoutSessionsTableName,
      limit: 1,
      orderBy: '$_activeSessionUpdatedAtColumnName DESC',
    );

    if (result.isNotEmpty) {
      final row = result.first;
      return {
        'workoutId': row[_activeSessionWorkoutIdColumnName] as int,
        'workoutData': row[_activeSessionWorkoutDataColumnName] as String,
        'elapsedSeconds': row[_activeSessionElapsedSecondsColumnName] as int,
        'startTime': row[_activeSessionStartTimeColumnName] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                row[_activeSessionStartTimeColumnName] as int)
            : null,
        'isTemporary': (row[_activeSessionIsTemporaryColumnName] as int) == 1,
        'createdAt': DateTime.fromMillisecondsSinceEpoch(
            row[_activeSessionCreatedAtColumnName] as int),
        'updatedAt': DateTime.fromMillisecondsSinceEpoch(
            row[_activeSessionUpdatedAtColumnName] as int),
      };
    }

    return null;
  }

  // Clear all active workout sessions
  Future<void> clearActiveWorkoutSessions() async {
    final db = await DatabaseService.instance.database;
    await db.delete(_activeWorkoutSessionsTableName);
    print('Active workout sessions cleared from database');
  }

  // Check if there's an active workout session in the database
  Future<bool> hasActiveWorkoutSession() async {
    final session = await getActiveWorkoutSession();
    return session != null;
  }

  // Add a new workout
  Future<int> addWorkout(String name, String date, int duration) async {
    final db = await DatabaseService.instance.database;
    final workoutId = await db.insert(
      _workoutTableName,
      {
        _workoutNameColumnName: name,
        _workoutDateColumnName: date,
        _workoutDurationColumnName: duration,
      },
    );
    workoutsUpdatedNotifier.value = !workoutsUpdatedNotifier.value;
    return workoutId;
  }
  
  // Create a temporary workout that's not saved to database yet
  int createTemporaryWorkout(String name, String date, int duration) {
    // Generate a unique negative ID to avoid conflicts with database IDs
    _tempIdCounter++;
    final tempId = -(DateTime.now().microsecondsSinceEpoch + _tempIdCounter);

    // Store workout data in memory
    final tempWorkouts = tempWorkoutsNotifier.value;
    tempWorkouts[tempId] = {
      'name': name,
      'date': date,
      'duration': duration,
      'exercises': <Map<String, dynamic>>[],
    };

    // Notify listeners
    tempWorkoutsNotifier.value = Map.from(tempWorkouts);

    return tempId;
  }

  // Save a temporary workout to the database
  Future<int> saveTemporaryWorkout(int tempId) async {
    final tempWorkouts = tempWorkoutsNotifier.value;
    if (!tempWorkouts.containsKey(tempId)) {
      throw Exception('Temporary workout not found');
    }

    final workout = tempWorkouts[tempId];

    // Save workout to database
    final workoutId =
        await addWorkout(workout['name'], workout['date'], workout['duration']);

    // Save exercises and sets - but only exercises that have valid sets
    for (final exercise in workout['exercises']) {
      // First, check if this exercise has any valid sets
      bool hasValidSets = false;
      List<Map<String, dynamic>> validSets = [];
      
      for (final set in exercise['sets']) {
        final double weight = (set['weight'] ?? 0.0).toDouble();
        final int reps = (set['reps'] ?? 0);
        final bool completed = set['completed'] ?? false;

        final bool hasValidWeight = weight > 0;
        final bool hasValidReps = reps > 0;

        // Only include sets that have valid data or are marked as completed
        if (hasValidWeight || hasValidReps || completed) {
          hasValidSets = true;
          validSets.add(set);
        }
      }

      // Only save the exercise if it has at least one valid set
      if (hasValidSets) {
        final exerciseId = await addExercise(
            workoutId, exercise['name'], exercise['equipment']);

        // Save all valid sets for this exercise
        for (final set in validSets) {
          final double weight = (set['weight'] ?? 0.0).toDouble();
          final int reps = (set['reps'] ?? 0);
          final bool completed = set['completed'] ?? false;
          
          final setId = await addSet(
              exerciseId, set['setNumber'], weight, reps, set['restTime']);
          
          // If the set was completed in the temporary workout, mark it as completed
          // This will trigger the proper PR calculation
          if (completed) {
            await updateSetStatus(setId, true);
          }
        }
      }
    }

    // Mark all exercises in this workout as finished
    await markWorkoutAsFinished(workoutId);
    print('✅ Marked workout as finished with all exercises flagged');

    // Remove temporary workout from memory
    tempWorkouts.remove(tempId);
    tempWorkoutsNotifier.value = Map.from(tempWorkouts);

    return workoutId;
  }

  // Discard a temporary workout
  Future<void> discardTemporaryWorkout(int tempId) async {
    print('🗑️ Attempting to discard temporary workout with ID: $tempId');
    
    final tempWorkouts = tempWorkoutsNotifier.value;
    final activeWorkout = activeWorkoutNotifier.value;

    // Debug information
    print('Current temp workouts: ${tempWorkouts.keys.toList()}');
    print(
        'Active workout: ${activeWorkout != null ? activeWorkout['id'] : 'null'} (isTemporary: ${activeWorkout?['isTemporary']})');

    // Check if this workout exists in temp workouts (this means it was a temporary workout)
    bool wasTemporaryWorkout =
        tempWorkouts.containsKey(tempId) || isTemporaryWorkout(tempId);

    // Check if this is the currently active workout (with improved matching)
    bool isActiveWorkout = false;
    if (activeWorkout != null) {
      // Check if the active workout matches the tempId
      final activeWorkoutId = activeWorkout['id'];
      final isTemporaryActive = activeWorkout['isTemporary'] as bool? ?? false;

      // Match by ID or if it's a temporary workout with the same ID
      isActiveWorkout = (activeWorkoutId == tempId) ||
          (isTemporaryActive &&
              isTemporaryWorkout(tempId) &&
              activeWorkoutId == tempId);

      print(
          'Active workout match check: activeWorkoutId=$activeWorkoutId, tempId=$tempId, isTemporaryActive=$isTemporaryActive, isActiveWorkout=$isActiveWorkout');
    }

    // Also check if there's saved data for this specific workout ID in SharedPreferences
    bool hasSavedData = false;
    try {
      final savedData = await WorkoutForegroundService.getSavedWorkoutData();
      if (savedData != null) {
        final savedWorkoutId = savedData['workout_id'] as int?;
        if (savedWorkoutId == tempId) {
          hasSavedData = true;
          print('Found saved data for workout ID: $tempId');
        }
      }
    } catch (e) {
      print('Error checking saved data: $e');
    }

    // Remove from temporary workouts if it exists
    if (tempWorkouts.containsKey(tempId)) {
      tempWorkouts.remove(tempId);
      tempWorkoutsNotifier.value = Map.from(tempWorkouts);
      print('✅ Removed workout from temp workouts');
    } else {
      print('⚠️ Workout not found in temp workouts');
    }
    
    // If this is/was a temporary workout OR has saved data, we need to clear everything
    if (isActiveWorkout || wasTemporaryWorkout || hasSavedData) {
      print(
          '🛑 Clearing workout data (isActive: $isActiveWorkout, wasTemporary: $wasTemporaryWorkout, hasSavedData: $hasSavedData)...');
      try {
        // Mark workout as discarded FIRST to prevent restoration after hot restart
        await WorkoutForegroundService.markWorkoutAsDiscarded();
        print('✅ Marked workout as discarded');

        // Stop the service FIRST and wait for it to complete
        await WorkoutForegroundService.stopWorkoutService();
        print('✅ Stopped workout service');

        // Clear the active workout notifier if it's currently active
        if (isActiveWorkout) {
          activeWorkoutNotifier.value = null;
          print('✅ Cleared active workout notifier');
        }

        // Always clear saved data for temporary workouts or if saved data exists
        await WorkoutForegroundService.clearSavedWorkoutData();
        print('✅ Cleared saved workout data');

        print('✅ Successfully discarded temporary workout with ID: $tempId');
      } catch (e) {
        print('❌ Error clearing workout data during discard: $e');
        // Still clear the active workout even if there was an error
        if (isActiveWorkout) {
          activeWorkoutNotifier.value = null;
        }
        try {
          await WorkoutForegroundService.clearSavedWorkoutData();
          print('✅ Cleared saved workout data after error');
        } catch (clearError) {
          print('❌ Error clearing saved workout data: $clearError');
        }
      }
    } else {
      print(
          'ℹ️ Workout is not active, not temporary, and has no saved data - skipping cleanup');
    }
  }

  // Check if a workout ID is temporary
  bool isTemporaryWorkout(int workoutId) {
    return workoutId < 0;
  }
  // Add a new exercise to a workout
  Future<int> addExercise(int workoutId, String name, String equipment) async {
    // Handle temporary workouts
    if (isTemporaryWorkout(workoutId)) {
      // Generate a unique negative ID for the temporary exercise using counter and microseconds
      _tempIdCounter++;
      final tempExerciseId =
          -(DateTime.now().microsecondsSinceEpoch + _tempIdCounter);

      // Add exercise to temporary workout in memory
      final tempWorkouts = tempWorkoutsNotifier.value;
      if (!tempWorkouts.containsKey(workoutId)) {
        // Create workout if it doesn't exist
        // Get time-based greeting (Morning/Afternoon/Evening)
        final greeting = Functions().getTimeOfDayDescription();
        tempWorkouts[workoutId] = {
          'name': '$greeting Workout',
          'date': DateTime.now().toString().split(' ')[0], // YYYY-MM-DD
          'duration': 0,
          'exercises': [],
        };
      }

      // Add the exercise
      tempWorkouts[workoutId]['exercises'].add({
        'id': tempExerciseId,
        'name': name,
        'equipment': equipment,
        'finished': false,
        'sets': [],
      });

      // Update the notifier to trigger UI refresh
      tempWorkoutsNotifier.value = Map.from(tempWorkouts);
      workoutsUpdatedNotifier.value = !workoutsUpdatedNotifier.value;

      return tempExerciseId;
    }

    // Normal database workflow
    final db = await DatabaseService.instance.database;
    final exerciseId = await db.insert(
      _exerciseTableName,
      {
        _exerciseWorkoutIdColumnName: workoutId,
        _exerciseNameColumnName: name,
        _exerciseEquipmentColumnName: equipment,
        _exerciseFinishedColumnName: 0, // Not finished by default
      },
    );
    workoutsUpdatedNotifier.value = !workoutsUpdatedNotifier.value;
    return exerciseId;
  }
  // Add a new set to an exercise
  Future<int> addSet(int exerciseId, int setNumber, double weight, int reps,
      int restTime) async {
    // Handle temporary workouts
    if (exerciseId < 0) {
      // Negative IDs are temporary
      // Generate a unique negative ID for the temporary set using counter and microseconds
      _tempIdCounter++;
      final tempSetId =
          -(DateTime.now().microsecondsSinceEpoch + _tempIdCounter);

      // Find the workout containing this exercise
      final tempWorkouts = tempWorkoutsNotifier.value;
      for (var workoutId in tempWorkouts.keys) {
        final exercises = tempWorkouts[workoutId]['exercises'];
        for (int i = 0; i < exercises.length; i++) {
          if (exercises[i]['id'] == exerciseId) {
            // Found the exercise, add the set
            if (!exercises[i].containsKey('sets')) {
              exercises[i]['sets'] = [];
            }

            exercises[i]['sets'].add({
              'id': tempSetId,
              'setNumber': setNumber,
              'weight': weight,
              'reps': reps,
              'restTime': restTime,
              'completed': false,
              'volume': weight * reps,
              'isPR': false, // Will be calculated when completed
            });

            // Update the notifier to trigger UI refresh
            tempWorkoutsNotifier.value = Map.from(tempWorkouts);
            workoutsUpdatedNotifier.value = !workoutsUpdatedNotifier.value;

            return tempSetId;
          }
        }
      }

      // If we got here, we couldn't find the exercise
      throw Exception('Exercise not found');
    }

    // Normal database workflow
    final db = await DatabaseService.instance.database;
    final setId = await db.insert(
      _setTableName,
      {
        _setExerciseIdColumnName: exerciseId,
        _setNumberColumnName: setNumber,
        _setWeightColumnName: weight,
        _setRepsColumnName: reps,
        _setRestTimeColumnName: restTime,
        _setCompletedColumnName: 0, // Not completed by default
        _setVolumeColumnName: weight * reps,
        _setIsPRColumnName: 0, // Will be calculated when completed
      },
    );
    workoutsUpdatedNotifier.value = !workoutsUpdatedNotifier.value;
    return setId;
  }

  // Check if a set is a Personal Record (PR) based on volume
  Future<bool> isPersonalRecord(String exerciseName, double volume,
      {int? excludeSetId}) async {
    final db = await DatabaseService.instance.database;

    // Clean the exercise name to ensure consistent comparison
    final String cleanExerciseName =
        exerciseName.replaceAll(RegExp(r'##API_ID:[^#]+##'), '');

    // Query to find all completed sets for exercises that match the clean name
    // We'll clean the names in Dart for more reliable comparison
    String query = '''
      SELECT es.volume, e.name, es.id
      FROM exercise_sets es
      INNER JOIN exercises e ON es.exerciseId = e.id
      WHERE es.completed = 1
    ''';

    List<dynamic> queryArgs = [];

    // If excludeSetId is provided, exclude that set from the comparison
    if (excludeSetId != null) {
      query += ' AND es.id != ?';
      queryArgs.add(excludeSetId);
    }

    final result = await db.rawQuery(query, queryArgs);

    // Filter results by clean exercise name and find maximum volume
    double maxVolume = 0.0;
    bool hasAnyResults = false;

    for (final row in result) {
      final String dbExerciseName = row['name'] as String;
      final String cleanDbExerciseName =
          dbExerciseName.replaceAll(RegExp(r'##API_ID:[^#]+##'), '');

      if (cleanDbExerciseName == cleanExerciseName) {
        hasAnyResults = true;
        final double rowVolume = row['volume'] as double;
        if (rowVolume > maxVolume) {
          maxVolume = rowVolume;
        }
      }
    }

    if (!hasAnyResults) {
      // First time doing this exercise, so it's a PR
      return true;
    }

    // Current volume is a PR if it's greater than or equal to the previous max
    // We use >= to allow ties, but we'll handle duplicates in the recalculation logic
    return volume >= maxVolume;
  }

  // Delete a set
  Future<void> deleteSet(int setId) async {
    // Handle temporary sets (negative IDs)
    if (setId < 0) {
      // For temporary workouts, we're handling this in the UI layer
      // by modifying the tempWorkoutsNotifier directly
      return;
    }

    // Normal database operation for permanent sets
    final db = await DatabaseService.instance.database;
    await db.delete(
      _setTableName,
      where: "$_setIdColumnName = ?",
      whereArgs: [setId],
    );
    workoutsUpdatedNotifier.value = !workoutsUpdatedNotifier.value;
  }

  // Recalculate PR status for all completed sets of a specific exercise
  // This ensures only sets that exceed previous records are marked as PRs
  Future<void> recalculatePRStatusForExercise(String exerciseName) async {
    final db = await DatabaseService.instance.database;

    // Clean the exercise name to ensure consistent comparison
    final String cleanExerciseName =
        exerciseName.replaceAll(RegExp(r'##API_ID:[^#]+##'), '');

    // Get all completed sets for this exercise, ordered by volume descending
    final result = await db.rawQuery('''
      SELECT es.id, es.volume, e.name, w.date
      FROM exercise_sets es
      INNER JOIN exercises e ON es.exerciseId = e.id
      INNER JOIN workouts w ON e.workoutId = w.id
      WHERE es.completed = 1
      ORDER BY w.date ASC, es.id ASC
    ''');

    // Filter by clean exercise name
    List<Map<String, dynamic>> exerciseSets = [];
    for (final row in result) {
      final String dbExerciseName = row['name'] as String;
      final String cleanDbExerciseName =
          dbExerciseName.replaceAll(RegExp(r'##API_ID:[^#]+##'), '');

      if (cleanDbExerciseName == cleanExerciseName) {
        exerciseSets.add(row);
      }
    }

    if (exerciseSets.isEmpty) return;

    // First, mark all sets as non-PR
    List<int> allSetIds = exerciseSets.map((s) => s['id'] as int).toList();
    if (allSetIds.isNotEmpty) {
      String placeholders = List.filled(allSetIds.length, '?').join(',');
      await db.rawUpdate('''
        UPDATE $_setTableName 
        SET $_setIsPRColumnName = 0 
        WHERE $_setIdColumnName IN ($placeholders)
      ''', allSetIds);
    }

    // Track the maximum volume seen so far (chronologically)
    double currentMaxVolume = 0.0;
    List<int> prSetIds = [];
    
    for (final set in exerciseSets) {
      final double volume = set['volume'] as double;

      // If this volume is greater than any previous volume, it's a PR
      if (volume > currentMaxVolume) {
        currentMaxVolume = volume;
        prSetIds.add(set['id'] as int);
      }
    }

    // Mark only the true PRs (sets that exceeded previous records)
    if (prSetIds.isNotEmpty) {
      String placeholders = List.filled(prSetIds.length, '?').join(',');
      await db.rawUpdate('''
        UPDATE $_setTableName 
        SET $_setIsPRColumnName = 1 
        WHERE $_setIdColumnName IN ($placeholders)
      ''', prSetIds);
    }

    workoutsUpdatedNotifier.value = !workoutsUpdatedNotifier.value;
  }

  // Update set completion status
  Future<void> updateSetStatus(int setId, bool completed) async {
    final db = await DatabaseService.instance.database;
    
    String? exerciseName;
    
    // If completing the set, get the exercise name for PR recalculation
    if (completed) {
      final setResult = await db.rawQuery('''
        SELECT e.name 
        FROM $_setTableName es
        INNER JOIN $_exerciseTableName e ON es.$_setExerciseIdColumnName = e.$_exerciseIdColumnName
        WHERE es.$_setIdColumnName = ?
      ''', [setId]);

      if (setResult.isNotEmpty) {
        exerciseName = setResult.first['name'] as String;
      }
    }

    // Update the set completion status
    Map<String, dynamic> updateData = {
      _setCompletedColumnName: completed ? 1 : 0
    };

    // If uncompleting the set, it's no longer a PR
    if (!completed) {
      updateData[_setIsPRColumnName] = 0;
    }
    
    await db.update(
      _setTableName,
      updateData,
      where: "$_setIdColumnName = ?",
      whereArgs: [setId],
    );

    // If completing a set, recalculate PR status for all sets of this exercise
    if (completed && exerciseName != null) {
      await recalculatePRStatusForExercise(exerciseName);
    }

    workoutsUpdatedNotifier.value = !workoutsUpdatedNotifier.value;
  }

  // Update workout duration
  Future<void> updateWorkoutDuration(int workoutId, int duration) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      _workoutTableName,
      {_workoutDurationColumnName: duration},
      where: "$_workoutIdColumnName = ?",
      whereArgs: [workoutId],
    );
    workoutsUpdatedNotifier.value = !workoutsUpdatedNotifier.value;
  }

  // Update workout name and date
  Future<void> updateWorkout(
      int workoutId, String name, String date, int duration) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      _workoutTableName,
      {
        _workoutNameColumnName: name,
        _workoutDateColumnName: date,
        _workoutDurationColumnName: duration,
      },
      where: "$_workoutIdColumnName = ?",
      whereArgs: [workoutId],
    );
    workoutsUpdatedNotifier.value = !workoutsUpdatedNotifier.value;
  }

  // Mark all exercises in a workout as finished
  Future<void> markWorkoutAsFinished(int workoutId) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      _exerciseTableName,
      {_exerciseFinishedColumnName: 1},
      where: "$_exerciseWorkoutIdColumnName = ?",
      whereArgs: [workoutId],
    );
    workoutsUpdatedNotifier.value = !workoutsUpdatedNotifier.value;
    print('✅ Marked all exercises in workout $workoutId as finished');
  }

  // Add updateExercise method to WorkoutService
  Future<void> updateExercise(
      int exerciseId, String name, String equipment) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      _exerciseTableName,
      {
        _exerciseNameColumnName: name,
        _exerciseEquipmentColumnName: equipment,
      },
      where: "$_exerciseIdColumnName = ?",
      whereArgs: [exerciseId],
    );
    workoutsUpdatedNotifier.value = !workoutsUpdatedNotifier.value;
  }

  // Get all workouts with their exercises and sets
  Future<List<Workout>> getWorkouts() async {
    final db = await DatabaseService.instance.database;
    final workoutMaps = await db.query(_workoutTableName,
        orderBy: "$_workoutDateColumnName DESC, $_workoutIdColumnName DESC");

    List<Workout> workouts = [];

    for (var workoutMap in workoutMaps) {
      final workoutId = workoutMap[_workoutIdColumnName] as int;

      // Get exercises for this workout
      final exerciseMaps = await db.query(
        _exerciseTableName,
        where: "$_exerciseWorkoutIdColumnName = ?",
        whereArgs: [workoutId],
      );

      List<Exercise> exercises = [];

      for (var exerciseMap in exerciseMaps) {
        final exerciseId = exerciseMap[_exerciseIdColumnName] as int;

        // Get sets for this exercise
        final setMaps = await db.query(
          _setTableName,
          where: "$_setExerciseIdColumnName = ?",
          whereArgs: [exerciseId],
          orderBy: "$_setNumberColumnName ASC",
        );

        List<ExerciseSet> sets = setMaps
            .map(
                (setMap) => ExerciseSet.fromMap(setMap as Map<String, dynamic>))
            .toList();
        exercises
            .add(Exercise.fromMap(exerciseMap as Map<String, dynamic>, sets));
      }

      workouts
          .add(Workout.fromMap(workoutMap as Map<String, dynamic>, exercises));
    }

    return workouts;
  }

  // Get a specific workout with its exercises and sets
  Future<Workout?> getWorkout(int workoutId) async {
    final db = await DatabaseService.instance.database;
    final workoutMaps = await db.query(
      _workoutTableName,
      where: "$_workoutIdColumnName = ?",
      whereArgs: [workoutId],
    );

    if (workoutMaps.isEmpty) {
      return null;
    }

    // Get exercises for this workout
    final exerciseMaps = await db.query(
      _exerciseTableName,
      where: "$_exerciseWorkoutIdColumnName = ?",
      whereArgs: [workoutId],
    );

    List<Exercise> exercises = [];

    for (var exerciseMap in exerciseMaps) {
      final exerciseId = exerciseMap[_exerciseIdColumnName] as int;

      // Get sets for this exercise
      final setMaps = await db.query(
        _setTableName,
        where: "$_setExerciseIdColumnName = ?",
        whereArgs: [exerciseId],
        orderBy: "$_setNumberColumnName ASC",
      );

      List<ExerciseSet> sets = setMaps
          .map((setMap) => ExerciseSet.fromMap(setMap as Map<String, dynamic>))
          .toList();
      exercises
          .add(Exercise.fromMap(exerciseMap as Map<String, dynamic>, sets));
    }

    return Workout.fromMap(
        workoutMaps.first as Map<String, dynamic>, exercises);
  }

  // Get the total count of completed workouts
  Future<int> getWorkoutCount() async {
    final db = await DatabaseService.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_workoutTableName');
    return (result.first['count'] as int?) ?? 0;
  }

  // Delete a workout and all related exercises and sets
  Future<void> deleteWorkout(int workoutId) async {
    final db = await DatabaseService.instance.database;
    await db.delete(
      _workoutTableName,
      where: "$_workoutIdColumnName = ?",
      whereArgs: [workoutId],
    );
    workoutsUpdatedNotifier.value = !workoutsUpdatedNotifier.value;
    
    // If this is the currently active workout, clear it and stop the foreground service
    final activeWorkout = activeWorkoutNotifier.value;
    if (activeWorkout != null && activeWorkout['id'] == workoutId) {
      activeWorkoutNotifier.value = null;
      WorkoutForegroundService.stopWorkoutService();
      // Also explicitly clear any saved data
      WorkoutForegroundService.clearSavedWorkoutData();
    }
  }
  // Delete an exercise and all its sets
  Future<void> deleteExercise(int exerciseId) async {
    // Handle temporary exercises (negative IDs)
    if (exerciseId < 0) {
      // For temporary workouts, we're handling this in the UI layer
      // by modifying the tempWorkoutsNotifier directly
      return;
    }

    // Normal database operation for permanent exercises
    final db = await DatabaseService.instance.database;
    await db.delete(
      _exerciseTableName,
      where: "$_exerciseIdColumnName = ?",
      whereArgs: [exerciseId],
    );
    workoutsUpdatedNotifier.value = !workoutsUpdatedNotifier.value;
  }

  // Get all exercises for a specific workout
  Future<List<Exercise>> getExercisesForWorkout(int workoutId) async {
    // If this is a temporary workout, get from memory
    if (isTemporaryWorkout(workoutId)) {
      final tempWorkouts = tempWorkoutsNotifier.value;
      if (!tempWorkouts.containsKey(workoutId)) {
        return [];
      }

      final workout = tempWorkouts[workoutId];
      List<Exercise> exercises = [];

      for (var exerciseData in workout['exercises']) {
        List<ExerciseSet> sets = [];
        int exerciseId =
            -(DateTime.now().millisecondsSinceEpoch + exercises.length);

        for (var setData in exerciseData['sets']) {
          final setId = -(DateTime.now().millisecondsSinceEpoch + sets.length);
          sets.add(ExerciseSet(
            id: setId,
            exerciseId: exerciseId,
            setNumber: setData['setNumber'],
            weight: setData['weight'],
            reps: setData['reps'],
            restTime: setData['restTime'],
            completed: setData['completed'] ?? false,
          ));
        }

        exercises.add(Exercise(
          id: exerciseId,
          workoutId: workoutId,
          name: exerciseData['name'],
          equipment: exerciseData['equipment'],
          finished: exerciseData['finished'] ?? false,
          sets: sets,
        ));
      }

      return exercises;
    }

    // Otherwise get from database
    final db = await DatabaseService.instance.database;
    final exerciseMaps = await db.query(
      _exerciseTableName,
      where: "$_exerciseWorkoutIdColumnName = ?",
      whereArgs: [workoutId],
    );

    List<Exercise> exercises = [];

    for (var exerciseMap in exerciseMaps) {
      final exerciseId = exerciseMap[_exerciseIdColumnName] as int;

      // Get sets for this exercise
      final setMaps = await db.query(
        _setTableName,
        where: "$_setExerciseIdColumnName = ?",
        whereArgs: [exerciseId],
        orderBy: "$_setNumberColumnName ASC",
      );

      List<ExerciseSet> sets = setMaps
          .map((setMap) => ExerciseSet.fromMap(setMap as Map<String, dynamic>))
          .toList();
      exercises
          .add(Exercise.fromMap(exerciseMap as Map<String, dynamic>, sets));
    }

    return exercises;
  }

  // Restore saved workout from foreground service data
  Future<void> restoreSavedWorkout(Map<String, dynamic> savedData) async {
    try {
      print('🔄 Restoring saved workout...');
      
      final startTime = savedData['start_time'] as DateTime;
      final workoutName = savedData['workout_name'] as String;

      // Calculate the actual elapsed time based on when the workout started
      final actualElapsedSeconds =
          DateTime.now().difference(startTime).inSeconds;

      // Get additional saved data
      final workoutData = savedData['workout_data'] as Map<String, dynamic>?;
      final workoutId = savedData['workout_id'] as int?;
      final isTemporary = savedData['is_temporary'] as bool? ?? false;
      final completeState =
          savedData['complete_state'] as Map<String, dynamic>?;

      print(
          'Restoration data: workoutId=$workoutId, isTemporary=$isTemporary, name=$workoutName');

      // Create active workout data for the notifier
      Map<String, dynamic> activeWorkoutData;

      // If we have complete state, use it for exact restoration
      if (completeState != null && completeState.containsKey('activeWorkout')) {
        activeWorkoutData =
            Map<String, dynamic>.from(completeState['activeWorkout']);

        // Update the duration to account for time passed during app restart
        final savedTimestamp = completeState['timestamp'] as int?;
        if (savedTimestamp != null) {
          final timePassed =
              (DateTime.now().millisecondsSinceEpoch - savedTimestamp) ~/ 1000;
          final savedDuration = activeWorkoutData['duration'] as int? ?? 0;
          activeWorkoutData['duration'] = savedDuration + timePassed;
        } else {
          // Fallback to calculated elapsed time
          activeWorkoutData['duration'] = actualElapsedSeconds;
        }

        // Ensure we have the correct workout ID and isTemporary flag from saved data
        if (workoutId != null) {
          activeWorkoutData['id'] = workoutId;
        }
        activeWorkoutData['isTemporary'] = isTemporary;

        // Update rest timer state if it was active
        final workoutDataFromState =
            activeWorkoutData['workoutData'] as Map<String, dynamic>?;
        if (workoutDataFromState?.containsKey('restTimerState') == true) {
          final restState =
              workoutDataFromState!['restTimerState'] as Map<String, dynamic>;
          final bool isActive = restState['isActive'] as bool? ?? false;
          final bool isPaused = restState['isPaused'] as bool? ?? false;

          if (isActive && !isPaused) {
            // Update rest timer remaining time based on real time elapsed
            final restStartTime = restState['startTime'] as int?;
            final originalTime = restState['originalTime'] as int? ?? 0;

            if (restStartTime != null) {
              final restElapsed =
                  (DateTime.now().millisecondsSinceEpoch - restStartTime) ~/
                      1000;
              final newTimeRemaining =
                  (originalTime - restElapsed).clamp(0, originalTime);
              restState['timeRemaining'] = newTimeRemaining;
            }
          }
        }

        print('✅ Using complete state for exact restoration');
      } else {
        // Fallback to basic restoration
        activeWorkoutData = {
          'id': workoutId ?? -1, // Use saved workout ID or temporary ID
          'name': workoutName,
          'startTime': startTime,
          'duration': actualElapsedSeconds,
          'isTemporary': isTemporary,
          'workoutData': workoutData ??
              <String, dynamic>{}, // Use saved workout data if available
        };
      }

      // If we have complete workout data, restore to temporary workouts if needed
      if (isTemporary && workoutData != null && workoutId != null) {
        // Restore the temporary workout to memory
        final tempWorkouts =
            Map<int, Map<String, dynamic>>.from(tempWorkoutsNotifier.value);

        // Create a complete temporary workout structure
        final tempWorkoutData = {
          'name': workoutName,
          'date': DateTime.now().toIso8601String(),
          'duration': activeWorkoutData['duration'],
          'exercises': workoutData['exercises'] ?? [],
        };

        tempWorkouts[workoutId] = tempWorkoutData;
        tempWorkoutsNotifier.value = tempWorkouts;

        print(
            '✅ Restored temporary workout to memory: $workoutName (ID: $workoutId)');
      }

      // Set the active workout notifier
      activeWorkoutNotifier.value = activeWorkoutData;

      print(
          '✅ Restored active workout: $workoutName (${activeWorkoutData['duration']}s elapsed, ID: ${activeWorkoutData['id'] ?? -1})');
    } catch (e) {
      print('❌ Error restoring saved workout: $e');
    }
  }

  // Get the most recent exercise history for a given exercise name
  Future<List<ExerciseSet>?> getRecentExerciseHistory(
      String exerciseName,
      {int? excludeWorkoutId}) async {
    try {
      final workouts = await getWorkouts();

      // Clean the exercise name to remove API ID markers
      final String cleanExerciseName =
          exerciseName.replaceAll(RegExp(r'##API_ID:[^#]+##'), '').trim();

      print('🔍 EXERCISE HISTORY SEARCH STARTING');
      print('🔍 Looking for: "$cleanExerciseName"');
      print('🔍 Excluding workout ID: $excludeWorkoutId');
      print('🔍 Total workouts to check: ${workouts.length}');

      // Additional explicit sorting by date and ID to ensure most recent first
      workouts.sort((a, b) {
        // First sort by date (most recent first)
        final dateComparison = b.date.compareTo(a.date);
        if (dateComparison != 0) return dateComparison;

        // If dates are equal, sort by ID (higher ID = more recent)
        return b.id.compareTo(a.id);
      });
      print('🔍 Workouts sorted by date+ID (most recent first)');

      // Find the most recent workout that contains this exercise with completed sets
      for (int i = 0; i < workouts.length; i++) {
        final workout = workouts[i];

        print('🔍 WORKOUT ${i + 1}/${workouts.length}:');
        print('🔍   ID: ${workout.id}');
        print('🔍   Name: "${workout.name}"');
        print('🔍   Date: ${workout.date}');
        print('🔍   Duration: ${workout.duration} seconds');
        print('🔍   Exercises: ${workout.exercises.length}');

        // Skip the current workout if excludeWorkoutId is provided
        // Note: temporary workouts have negative IDs, so they won't match database workouts
        if (excludeWorkoutId != null && workout.id == excludeWorkoutId) {
          print('🔍   ⏭️  SKIPPING - matches excludeWorkoutId');
          continue;
        }

        for (int j = 0; j < workout.exercises.length; j++) {
          final exercise = workout.exercises[j];
          // Clean the database exercise name for comparison
          final String cleanDbExerciseName =
              exercise.name.replaceAll(RegExp(r'##API_ID:[^#]+##'), '').trim();

          print('🔍   Exercise ${j + 1}: "$cleanDbExerciseName"');
          print('🔍     Finished: ${exercise.finished}');
          print('🔍     Total Sets: ${exercise.sets.length}');
          
          // Check for exact match (case insensitive)
          if (cleanDbExerciseName.toLowerCase() ==
              cleanExerciseName.toLowerCase()) {
            
            print('🔍     ✅ EXERCISE NAME MATCH!');

            // Check if this exercise has any completed sets
            final completedSets =
                exercise.sets.where((set) => set.completed).toList();

            print(
                '🔍     Completed sets: ${completedSets.length}/${exercise.sets.length}');

            // Also check if the exercise itself is marked as finished (additional validation)
            final isExerciseFinished = exercise.finished;
            print('🔍     Exercise finished flag: $isExerciseFinished');

            // Only return sets if the exercise has completed sets OR is marked as finished
            if (completedSets.isNotEmpty || isExerciseFinished) {
              print('📋 ✅ FOUND VALID EXERCISE HISTORY!');
              print('📋     Workout: ${workout.id} ("${workout.name}")');
              print('📋     Date: ${workout.date}');
              print('📋     Total Sets: ${exercise.sets.length}');
              print('📋     Completed Sets: ${completedSets.length}');
              print('📋     Exercise Finished: $isExerciseFinished');
              print('📋     Set details:');
              for (int k = 0; k < exercise.sets.length; k++) {
                final set = exercise.sets[k];
                print(
                    '📋       Set ${k + 1}: ${set.weight}kg x ${set.reps} (completed: ${set.completed})');
              }
              return exercise
                  .sets; // Return all sets (including completed and uncompleted for full history)
            } else {
              print(
                  '🔍     ❌ No completed sets and exercise not finished, continuing search...');
            }
          } else {
            print(
                '🔍     ❌ Name mismatch: "${cleanDbExerciseName}" != "${cleanExerciseName}"');
          }
        }
        print('�   End of workout ${i + 1}');
        print('🔍 ─────────────────────────────────');
      }

      print('📋 ❌ NO EXERCISE HISTORY FOUND for: "$cleanExerciseName"');
      return null;
    } catch (e) {
      print('❌ ERROR in getRecentExerciseHistory: $e');
      return null;
    }
  }
}

// Add a new SettingsService class at the end of the file
class SettingsService {
  // Singleton instance
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // Notifier to inform listeners when settings change
  static final ValueNotifier<bool> settingsUpdatedNotifier =
      ValueNotifier(false);

  // Keys for SharedPreferences
  static const String _weeklyWorkoutGoalKey = 'weekly_workout_goal';

  // Default values
  static const int defaultWeeklyWorkoutGoal = 5;

  // Get the weekly workout goal
  Future<int> getWeeklyWorkoutGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_weeklyWorkoutGoalKey) ?? defaultWeeklyWorkoutGoal;
  }

  // Set the weekly workout goal
  Future<void> setWeeklyWorkoutGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_weeklyWorkoutGoalKey, goal);
    settingsUpdatedNotifier.value = !settingsUpdatedNotifier.value;
  }
}
