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
      version: 4,
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          // Create workout tables if upgrading from a previous version
          await WorkoutService().createWorkoutTables(db);
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

  final String _setTableName = "exercise_sets";
  final String _setIdColumnName = "id";
  final String _setExerciseIdColumnName = "exerciseId";
  final String _setNumberColumnName = "setNumber";
  final String _setWeightColumnName = "weight";
  final String _setRepsColumnName = "reps";
  final String _setRestTimeColumnName = "restTime";
  final String _setCompletedColumnName = "completed";

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
        FOREIGN KEY ($_setExerciseIdColumnName) REFERENCES $_exerciseTableName ($_exerciseIdColumnName) ON DELETE CASCADE
      )
    ''');
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
    // Generate a negative ID to avoid conflicts with database IDs
    final tempId = -(DateTime.now().millisecondsSinceEpoch);

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

    // Save exercises and sets
    for (final exercise in workout['exercises']) {
      final exerciseId =
          await addExercise(workoutId, exercise['name'], exercise['equipment']);

      for (final set in exercise['sets']) {
        await addSet(exerciseId, set['setNumber'], set['weight'], set['reps'],
            set['restTime']);
      }
    }

    // Remove temporary workout from memory
    tempWorkouts.remove(tempId);
    tempWorkoutsNotifier.value = Map.from(tempWorkouts);

    return workoutId;
  }

  // Discard a temporary workout
  Future<void> discardTemporaryWorkout(int tempId) async {
    final tempWorkouts = tempWorkoutsNotifier.value;
    if (tempWorkouts.containsKey(tempId)) {
      tempWorkouts.remove(tempId);
      tempWorkoutsNotifier.value = Map.from(tempWorkouts);
      
      // If this is the currently active workout, stop the service first, then clear it
      final activeWorkout = activeWorkoutNotifier.value;
      if (activeWorkout != null && activeWorkout['id'] == tempId) {
        try {
          // Stop the service FIRST and wait for it to complete
          await WorkoutForegroundService.stopWorkoutService();
          // Only clear the active workout AFTER the service is stopped
          activeWorkoutNotifier.value = null;
          await WorkoutForegroundService.clearSavedWorkoutData();
        } catch (e) {
          print('Error clearing workout data during discard: $e');
          // Still clear the active workout even if there was an error
          activeWorkoutNotifier.value = null;
        }
      }
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
      // Generate a negative ID for the temporary exercise
      final tempExerciseId = -(DateTime.now().millisecondsSinceEpoch);

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
      // Generate a negative ID for the temporary set
      final tempSetId = -(DateTime.now().millisecondsSinceEpoch);

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
      },
    );
    workoutsUpdatedNotifier.value = !workoutsUpdatedNotifier.value;
    return setId;
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

  // Update set completion status
  Future<void> updateSetStatus(int setId, bool completed) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      _setTableName,
      {_setCompletedColumnName: completed ? 1 : 0},
      where: "$_setIdColumnName = ?",
      whereArgs: [setId],
    );
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
        orderBy: "$_workoutDateColumnName DESC");

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
      final startTime = savedData['start_time'] as DateTime;
      final workoutName = savedData['workout_name'] as String;

      // Calculate the actual elapsed time based on when the workout started
      final actualElapsedSeconds =
          DateTime.now().difference(startTime).inSeconds;

      // Get additional saved data
      final workoutData = savedData['workout_data'] as Map<String, dynamic>?;
      final workoutId = savedData['workout_id'] as int?;
      final isTemporary = savedData['is_temporary'] as bool? ?? false;

      // Create active workout data for the notifier
      final activeWorkoutData = {
        'id': workoutId ?? -1, // Use saved workout ID or temporary ID
        'name': workoutName,
        'startTime': startTime,
        'duration': actualElapsedSeconds,
        'isTemporary': isTemporary,
        'workoutData': workoutData ??
            <String, dynamic>{}, // Use saved workout data if available
      };

      // If we have complete workout data, restore to temporary workouts if needed
      if (isTemporary && workoutData != null && workoutId != null) {
        // Restore the temporary workout to memory
        final tempWorkouts =
            Map<int, Map<String, dynamic>>.from(tempWorkoutsNotifier.value);

        // Create a complete temporary workout structure
        final tempWorkoutData = {
          'name': workoutName,
          'date': DateTime.now().toIso8601String(),
          'duration': actualElapsedSeconds,
          'exercises': workoutData['exercises'] ?? [],
        };

        tempWorkouts[workoutId] = tempWorkoutData;
        tempWorkoutsNotifier.value = tempWorkouts;

        print(
            'Restored temporary workout to memory: $workoutName (ID: $workoutId)');
      }

      // Set the active workout notifier
      activeWorkoutNotifier.value = activeWorkoutData;

      print(
          'Restored active workout: $workoutName (${actualElapsedSeconds}s elapsed)');
    } catch (e) {
      print('Error restoring saved workout: $e');
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
