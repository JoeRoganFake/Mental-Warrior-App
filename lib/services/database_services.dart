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
      version: 11, // Increment version for superset support
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
        CustomExerciseService()
            .createCustomExerciseTable(db); // Added custom exercises table
        ExerciseStickyNoteService()
            .createStickyNotesTable(db); // Added sticky notes table
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
        if (oldVersion < 7) {
          // Create custom exercises table
          await CustomExerciseService().createCustomExerciseTable(db);
        }
        if (oldVersion < 8) {
          // Add unique constraint to custom exercises name
          // Need to recreate the table since SQLite doesn't support ALTER TABLE ADD CONSTRAINT
          await db.execute(
              'ALTER TABLE custom_exercises RENAME TO custom_exercises_old');
          await CustomExerciseService().createCustomExerciseTable(db);
          await db.execute('''
            INSERT INTO custom_exercises (id, name, equipment, type, description, secondary_muscles, created_at)
            SELECT id, name, equipment, type, description, secondary_muscles, created_at
            FROM custom_exercises_old
          ''');
          await db.execute('DROP TABLE custom_exercises_old');
        }
        if (oldVersion < 9) {
          // Add notes column to exercises table
          await db.execute('ALTER TABLE exercises ADD COLUMN notes TEXT');
        }
        if (oldVersion < 10) {
          // Create sticky notes table
          await ExerciseStickyNoteService().createStickyNotesTable(db);
        }
        if (oldVersion < 11) {
          // Add superset_group column to exercises table
          await db
              .execute('ALTER TABLE exercises ADD COLUMN superset_group TEXT');
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
  final String _exerciseNotesColumnName = "notes";
  final String _exerciseSupersetGroupColumnName = "superset_group";

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
        $_exerciseNotesColumnName TEXT,
        $_exerciseSupersetGroupColumnName TEXT,
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

  // Create a temporary workout from a template (existing workout)
  int createTemporaryWorkoutFromTemplate(
      String name, String date, List<Exercise> templateExercises) {
    // Generate a unique negative ID to avoid conflicts with database IDs
    _tempIdCounter++;
    final tempId = -(DateTime.now().microsecondsSinceEpoch + _tempIdCounter);

    // Convert template exercises to the temporary format with proper IDs
    final exercisesData = templateExercises.map((exercise) {
      // Generate unique negative ID for this exercise
      _tempIdCounter++;
      final tempExerciseId =
          -(DateTime.now().microsecondsSinceEpoch + _tempIdCounter);

      // Create sets with unique IDs based on the template's set count
      final setsData = exercise.sets.map((set) {
        _tempIdCounter++;
        final tempSetId =
            -(DateTime.now().microsecondsSinceEpoch + _tempIdCounter);

        return {
          'id': tempSetId,
          'setNumber': set.setNumber,
          'weight':
              set.weight > 0 ? set.weight : 0.0, // Use template weight if set
          'reps': set.reps > 0 ? set.reps : 0, // Use template reps if set
          'restTime': set.restTime,
          'completed': false,
          'volume': 0.0,
          'isPR': false,
        };
      }).toList();

      return {
        'id': tempExerciseId,
        'name': exercise.name,
        'equipment': exercise.equipment,
        'finished': false,
        'notes': exercise.notes,
        'supersetGroup': exercise.supersetGroup,
        'sets': setsData,
      };
    }).toList();

    // Store workout data in memory
    final tempWorkouts = tempWorkoutsNotifier.value;
    tempWorkouts[tempId] = {
      'name': name,
      'date': date,
      'duration': 0,
      'exercises': exercisesData,
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
            workoutId, exercise['name'], exercise['equipment'],
            notes: exercise['notes'] as String?,
            supersetGroup: exercise['supersetGroup'] as String?);

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
  Future<int> addExercise(int workoutId, String name, String equipment,
      {String? notes, String? supersetGroup}) async {
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
        'notes': notes,
        'supersetGroup': supersetGroup,
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
        _exerciseNotesColumnName: notes,
        _exerciseSupersetGroupColumnName: supersetGroup,
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
    // Remove both API_ID and CUSTOM markers
    final String cleanExerciseName =
        exerciseName
        .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
        .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
        .trim();

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
          dbExerciseName
          .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
          .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
          .trim();

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
  // This marks new PRs without removing old PR flags (preserves historical context)
  Future<void> recalculatePRStatusForExercise(String exerciseName) async {
    final db = await DatabaseService.instance.database;

    // Clean the exercise name to ensure consistent comparison
    // Remove both API_ID and CUSTOM markers
    final String cleanExerciseName =
        exerciseName
        .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
        .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
        .trim();

    // Get all completed sets for this exercise, ordered chronologically
    final result = await db.rawQuery('''
      SELECT es.id, es.volume, es.weight, es.reps, e.name, w.date, w.id as workout_id
      FROM exercise_sets es
      INNER JOIN exercises e ON es.exerciseId = e.id
      INNER JOIN workouts w ON e.workoutId = w.id
      WHERE es.completed = 1 
      AND (e.name LIKE ? OR e.name LIKE ?)
      ORDER BY w.date ASC, w.id ASC, es.id ASC
    ''', ['%$cleanExerciseName%', cleanExerciseName]);

    // Filter by exact clean exercise name match
    List<Map<String, dynamic>> exerciseSets = [];
    for (final row in result) {
      final String dbExerciseName = row['name'] as String;
      final String cleanDbExerciseName =
          dbExerciseName
          .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
          .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
          .trim();

      if (cleanDbExerciseName == cleanExerciseName) {
        exerciseSets.add(row);
      }
    }

    if (exerciseSets.isEmpty) return;

    // First, clear all existing PR flags for this exercise
    await db.rawUpdate('''
      UPDATE $_setTableName
      SET $_setIsPRColumnName = 0
      WHERE $_setIdColumnName IN (
        SELECT es.id
        FROM exercise_sets es
        INNER JOIN exercises e ON es.exerciseId = e.id
        WHERE e.name LIKE ? OR e.name LIKE ?
      )
    ''', ['%$cleanExerciseName%', cleanExerciseName]);

    // Find the set with maximum volume (only one PR per exercise)
    double maxVolume = 0.0;
    int? maxSetId;
    
    for (final set in exerciseSets) {
      final int setId = set['id'] as int;
      final double volume = set['volume'] as double;
      final double weight = set['weight'] as double;
      final int reps = set['reps'] as int;

      // Only consider valid volumes (weight > 0 and reps > 0)
      if (weight > 0 && reps > 0 && volume > 0) {
        if (volume > maxVolume) {
          maxVolume = volume;
          maxSetId = setId;
        }
      }
    }

    // Mark only the single set with maximum volume as PR
    if (maxSetId != null) {
      await db.rawUpdate('''
        UPDATE $_setTableName 
        SET $_setIsPRColumnName = 1 
        WHERE $_setIdColumnName = ?
      ''', [maxSetId]);
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

    // If uncompleting the set, clear the PR flag
    // (uncompleted sets shouldn't count in statistics, even if they were PRs)
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

  // Update set completion status without triggering PR recalculation
  // Use this during bulk operations where PR recalculation will be done separately
  Future<void> updateSetStatusWithoutPRRecalculation(
      int setId, bool completed) async {
    final db = await DatabaseService.instance.database;

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

    // Note: PR recalculation should be done separately after all updates
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
      int exerciseId, String name, String equipment,
      {String? notes, String? supersetGroup}) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      _exerciseTableName,
      {
        _exerciseNameColumnName: name,
        _exerciseEquipmentColumnName: equipment,
        _exerciseNotesColumnName: notes,
        _exerciseSupersetGroupColumnName: supersetGroup,
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
          notes: exerciseData['notes'] as String?,
          supersetGroup: exerciseData['supersetGroup'] as String?,
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

      // Clean the exercise name to remove API ID and CUSTOM markers
      final String cleanExerciseName =
          exerciseName
          .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
          .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
          .trim();

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
              exercise.name
              .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
              .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
              .trim();

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

  /// Convert all workout set weights from one unit to another
  /// [factor] - the conversion factor to multiply weights by
  /// [newUnit] - the new unit being used (for logging purposes)
  Future<void> convertAllWorkoutWeights(double factor, String newUnit) async {
    final db = await DatabaseService.instance.database;

    // Get all sets with their weights
    final sets = await db.query(_setTableName);

    int convertedCount = 0;

    for (final set in sets) {
      final setId = set[_setIdColumnName] as int;
      final oldWeight = set[_setWeightColumnName] as double;
      final oldVolume = set[_setVolumeColumnName] as double;

      // Convert weight and recalculate volume
      final newWeight = double.parse((oldWeight * factor).toStringAsFixed(2));
      final newVolume = double.parse((oldVolume * factor).toStringAsFixed(2));

      await db.update(
        _setTableName,
        {
          _setWeightColumnName: newWeight,
          _setVolumeColumnName: newVolume,
        },
        where: '$_setIdColumnName = ?',
        whereArgs: [setId],
      );

      convertedCount++;
    }

    print('✅ Converted $convertedCount workout sets to $newUnit');

    // Notify listeners that workouts have been updated
    workoutsUpdatedNotifier.value = !workoutsUpdatedNotifier.value;
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
  static const String _defaultRestTimerKey = 'default_rest_timer';
  static const String _autoStartRestTimerKey = 'auto_start_rest_timer';
  static const String _vibrateOnRestCompleteKey = 'vibrate_on_rest_complete';
  static const String _soundOnRestCompleteKey = 'sound_on_rest_complete';
  static const String _keepScreenOnKey = 'keep_screen_on';
  static const String _showWeightInLbsKey = 'show_weight_in_lbs';
  static const String _defaultWeightIncrementKey = 'default_weight_increment';
  static const String _showRestTimerKey = 'show_rest_timer';
  static const String _confirmFinishWorkoutKey = 'confirm_finish_workout';
  static const String _useMeasurementInInchesKey = 'use_measurement_in_inches';

  // Default values
  static const int defaultWeeklyWorkoutGoal = 5;
  static const int defaultRestTimerSeconds = 90;
  static const bool defaultAutoStartRestTimer = true;
  static const bool defaultVibrateOnRestComplete = true;
  static const bool defaultSoundOnRestComplete = true;
  static const bool defaultKeepScreenOn = true;
  static const bool defaultShowWeightInLbs = false;
  static const double defaultWeightIncrement = 2.5;
  static const bool defaultShowRestTimer = true;
  static const bool defaultConfirmFinishWorkout = true;
  static const bool defaultUseMeasurementInInches = false;

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

  // Rest Timer Settings
  Future<int> getDefaultRestTimer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_defaultRestTimerKey) ?? defaultRestTimerSeconds;
  }

  Future<void> setDefaultRestTimer(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_defaultRestTimerKey, seconds);
    settingsUpdatedNotifier.value = !settingsUpdatedNotifier.value;
  }

  Future<bool> getAutoStartRestTimer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoStartRestTimerKey) ?? defaultAutoStartRestTimer;
  }

  Future<void> setAutoStartRestTimer(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoStartRestTimerKey, value);
    settingsUpdatedNotifier.value = !settingsUpdatedNotifier.value;
  }

  Future<bool> getVibrateOnRestComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_vibrateOnRestCompleteKey) ??
        defaultVibrateOnRestComplete;
  }

  Future<void> setVibrateOnRestComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrateOnRestCompleteKey, value);
    settingsUpdatedNotifier.value = !settingsUpdatedNotifier.value;
  }

  Future<bool> getSoundOnRestComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundOnRestCompleteKey) ?? defaultSoundOnRestComplete;
  }

  Future<void> setSoundOnRestComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundOnRestCompleteKey, value);
    settingsUpdatedNotifier.value = !settingsUpdatedNotifier.value;
  }

  Future<bool> getShowRestTimer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showRestTimerKey) ?? defaultShowRestTimer;
  }

  Future<void> setShowRestTimer(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showRestTimerKey, value);
    settingsUpdatedNotifier.value = !settingsUpdatedNotifier.value;
  }

  // Workout Settings
  Future<bool> getKeepScreenOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keepScreenOnKey) ?? defaultKeepScreenOn;
  }

  Future<void> setKeepScreenOn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepScreenOnKey, value);
    settingsUpdatedNotifier.value = !settingsUpdatedNotifier.value;
  }

  Future<bool> getConfirmFinishWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_confirmFinishWorkoutKey) ??
        defaultConfirmFinishWorkout;
  }

  Future<void> setConfirmFinishWorkout(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_confirmFinishWorkoutKey, value);
    settingsUpdatedNotifier.value = !settingsUpdatedNotifier.value;
  }

  // Weight Settings
  Future<bool> getShowWeightInLbs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showWeightInLbsKey) ?? defaultShowWeightInLbs;
  }

  Future<void> setShowWeightInLbs(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showWeightInLbsKey, value);
    settingsUpdatedNotifier.value = !settingsUpdatedNotifier.value;
  }

  Future<double> getDefaultWeightIncrement() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_defaultWeightIncrementKey) ??
        defaultWeightIncrement;
  }

  Future<void> setDefaultWeightIncrement(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_defaultWeightIncrementKey, value);
    settingsUpdatedNotifier.value = !settingsUpdatedNotifier.value;
  }

  // Measurement Settings
  Future<bool> getUseMeasurementInInches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useMeasurementInInchesKey) ??
        defaultUseMeasurementInInches;
  }

  Future<void> setUseMeasurementInInches(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useMeasurementInInchesKey, value);
    settingsUpdatedNotifier.value = !settingsUpdatedNotifier.value;
  }

  // Get all settings at once (useful for settings page)
  Future<Map<String, dynamic>> getAllSettings() async {
    return {
      'weeklyWorkoutGoal': await getWeeklyWorkoutGoal(),
      'defaultRestTimer': await getDefaultRestTimer(),
      'autoStartRestTimer': await getAutoStartRestTimer(),
      'vibrateOnRestComplete': await getVibrateOnRestComplete(),
      'soundOnRestComplete': await getSoundOnRestComplete(),
      'showRestTimer': await getShowRestTimer(),
      'keepScreenOn': await getKeepScreenOn(),
      'confirmFinishWorkout': await getConfirmFinishWorkout(),
      'showWeightInLbs': await getShowWeightInLbs(),
      'defaultWeightIncrement': await getDefaultWeightIncrement(),
      'useMeasurementInInches': await getUseMeasurementInInches(),
    };
  }
}

// Add a new CustomExerciseService class for managing user-created exercises
class CustomExerciseService {
  // Singleton instance
  static final CustomExerciseService _instance =
      CustomExerciseService._internal();
  factory CustomExerciseService() => _instance;
  CustomExerciseService._internal();

  // Notifier to inform listeners when custom exercises change
  static final ValueNotifier<bool> customExercisesUpdatedNotifier =
      ValueNotifier(false);

  // Table & column names
  final String _customExerciseTableName = "custom_exercises";
  final String _exerciseIdColumnName = "id";
  final String _exerciseNameColumnName = "name";
  final String _exerciseEquipmentColumnName = "equipment";
  final String _exerciseTypeColumnName = "type";
  final String _exerciseDescriptionColumnName = "description";
  final String _exerciseSecondaryMusclesColumnName = "secondary_muscles";
  final String _exerciseCreatedAtColumnName = "created_at";
  final String _exerciseHiddenColumnName = "hidden";

  // Create custom exercises table
  Future<void> createCustomExerciseTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_customExerciseTableName (
        $_exerciseIdColumnName INTEGER PRIMARY KEY AUTOINCREMENT,
        $_exerciseNameColumnName TEXT NOT NULL UNIQUE,
        $_exerciseEquipmentColumnName TEXT NOT NULL,
        $_exerciseTypeColumnName TEXT NOT NULL,
        $_exerciseDescriptionColumnName TEXT,
        $_exerciseSecondaryMusclesColumnName TEXT,
        $_exerciseCreatedAtColumnName TEXT NOT NULL,
        $_exerciseHiddenColumnName INTEGER DEFAULT 0
      )
    ''');
    
    // Migration: Add hidden column to existing tables
    try {
      await db.execute('''
        ALTER TABLE $_customExerciseTableName 
        ADD COLUMN $_exerciseHiddenColumnName INTEGER DEFAULT 0
      ''');
      print('✅ Added hidden column to custom exercises table');
    } catch (e) {
      // Column might already exist, ignore error
      print('ℹ️ Hidden column may already exist: $e');
    }
  }

  // Add a new custom exercise
  Future<int> addCustomExercise({
    required String name,
    required String equipment,
    required String type,
    String? description,
    List<String>? secondaryMuscles,
  }) async {
    final db = await DatabaseService.instance.database;

    final exerciseData = {
      _exerciseNameColumnName: name,
      _exerciseEquipmentColumnName: equipment,
      _exerciseTypeColumnName: type,
      _exerciseDescriptionColumnName: description ?? '',
      _exerciseSecondaryMusclesColumnName: secondaryMuscles?.join(',') ?? '',
      _exerciseCreatedAtColumnName: DateTime.now().toIso8601String(),
      _exerciseHiddenColumnName: 0, // New exercises are not hidden by default
    };

    final id = await db.insert(_customExerciseTableName, exerciseData);
    customExercisesUpdatedNotifier.value =
        !customExercisesUpdatedNotifier.value;
    return id;
  }

  // Get all custom exercises
  Future<List<Map<String, dynamic>>> getCustomExercises({bool includeHidden = true}) async {
    final db = await DatabaseService.instance.database;
    
    String? whereClause;
    if (!includeHidden) {
      whereClause = '$_exerciseHiddenColumnName = 0';
    }
    
    final data = await db.query(
      _customExerciseTableName,
      where: whereClause,
      orderBy: '$_exerciseNameColumnName ASC',
    );

    return data.map((exerciseMap) {
      final secondaryMusclesString =
          exerciseMap[_exerciseSecondaryMusclesColumnName] as String? ?? '';
      final secondaryMuscles = secondaryMusclesString.isEmpty
          ? <String>[]
          : secondaryMusclesString.split(',');

      return {
        'id': exerciseMap[_exerciseIdColumnName],
        'name': exerciseMap[_exerciseNameColumnName],
        'equipment': exerciseMap[_exerciseEquipmentColumnName],
        'type': exerciseMap[_exerciseTypeColumnName],
        'description': exerciseMap[_exerciseDescriptionColumnName],
        'secondaryMuscles': secondaryMuscles,
        'apiId':
            'custom_${exerciseMap[_exerciseIdColumnName]}', // Mark as custom with unique ID
        'isCustom': true, // Flag to identify custom exercises
        'createdAt': exerciseMap[_exerciseCreatedAtColumnName],
        'hidden': (exerciseMap[_exerciseHiddenColumnName] as int? ?? 0) == 1,
      };
    }).toList();
  }

  // Get only hidden custom exercises
  Future<List<Map<String, dynamic>>> getHiddenCustomExercises() async {
    final db = await DatabaseService.instance.database;
    
    final data = await db.query(
      _customExerciseTableName,
      where: '$_exerciseHiddenColumnName = 1',
      orderBy: '$_exerciseNameColumnName ASC',
    );

    return data.map((exerciseMap) {
      final secondaryMusclesString =
          exerciseMap[_exerciseSecondaryMusclesColumnName] as String? ?? '';
      final secondaryMuscles = secondaryMusclesString.isEmpty
          ? <String>[]
          : secondaryMusclesString.split(',');

      return {
        'id': exerciseMap[_exerciseIdColumnName],
        'name': exerciseMap[_exerciseNameColumnName],
        'equipment': exerciseMap[_exerciseEquipmentColumnName],
        'type': exerciseMap[_exerciseTypeColumnName],
        'description': exerciseMap[_exerciseDescriptionColumnName],
        'secondaryMuscles': secondaryMuscles,
        'apiId':
            'custom_${exerciseMap[_exerciseIdColumnName]}',
        'isCustom': true,
        'createdAt': exerciseMap[_exerciseCreatedAtColumnName],
        'hidden': true,
      };
    }).toList();
  }

  // Update a custom exercise
  Future<void> updateCustomExercise({
    required int id,
    required String name,
    required String equipment,
    required String type,
    String? description,
    List<String>? secondaryMuscles,
  }) async {
    final db = await DatabaseService.instance.database;

    final exerciseData = {
      _exerciseNameColumnName: name,
      _exerciseEquipmentColumnName: equipment,
      _exerciseTypeColumnName: type,
      _exerciseDescriptionColumnName: description ?? '',
      _exerciseSecondaryMusclesColumnName: secondaryMuscles?.join(',') ?? '',
    };

    await db.update(
      _customExerciseTableName,
      exerciseData,
      where: '$_exerciseIdColumnName = ?',
      whereArgs: [id],
    );
    customExercisesUpdatedNotifier.value =
        !customExercisesUpdatedNotifier.value;
  }

  // Delete a custom exercise
  Future<void> deleteCustomExercise(int id) async {
    final db = await DatabaseService.instance.database;
    await db.delete(
      _customExerciseTableName,
      where: '$_exerciseIdColumnName = ?',
      whereArgs: [id],
    );
    customExercisesUpdatedNotifier.value =
        !customExercisesUpdatedNotifier.value;
  }

  // Hide a custom exercise (soft delete)
  Future<void> hideCustomExercise(int id) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      _customExerciseTableName,
      {_exerciseHiddenColumnName: 1},
      where: '$_exerciseIdColumnName = ?',
      whereArgs: [id],
    );
    customExercisesUpdatedNotifier.value =
        !customExercisesUpdatedNotifier.value;
    print('✅ Hidden custom exercise with ID: $id');
  }

  // Unhide a custom exercise
  Future<void> unhideCustomExercise(int id) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      _customExerciseTableName,
      {_exerciseHiddenColumnName: 0},
      where: '$_exerciseIdColumnName = ?',
      whereArgs: [id],
    );
    customExercisesUpdatedNotifier.value =
        !customExercisesUpdatedNotifier.value;
    print('✅ Unhidden custom exercise with ID: $id');
  }

  // Check if a custom exercise with the same name already exists
  Future<bool> exerciseExists(String name) async {
    final db = await DatabaseService.instance.database;
    final result = await db.query(
      _customExerciseTableName,
      where: '$_exerciseNameColumnName = ?',
      whereArgs: [name],
      limit: 1,
    );
    return result.isNotEmpty;
  }
}

// Service for managing sticky notes on exercises
class ExerciseStickyNoteService {
  // Singleton instance
  static final ExerciseStickyNoteService _instance =
      ExerciseStickyNoteService._internal();
  factory ExerciseStickyNoteService() => _instance;
  ExerciseStickyNoteService._internal();

  // Notifier to inform listeners when sticky notes change
  static final ValueNotifier<bool> stickyNotesUpdatedNotifier =
      ValueNotifier(false);

  // Table & column names
  final String _stickyNotesTableName = "exercise_sticky_notes";
  final String _idColumnName = "id";
  final String _exerciseNameColumnName =
      "exercise_name"; // Clean name without markers
  final String _noteColumnName = "note";
  final String _createdAtColumnName = "created_at";
  final String _updatedAtColumnName = "updated_at";

  // Create sticky notes table
  Future<void> createStickyNotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_stickyNotesTableName (
        $_idColumnName INTEGER PRIMARY KEY AUTOINCREMENT,
        $_exerciseNameColumnName TEXT NOT NULL UNIQUE,
        $_noteColumnName TEXT NOT NULL,
        $_createdAtColumnName TEXT NOT NULL,
        $_updatedAtColumnName TEXT NOT NULL
      )
    ''');
    print('✅ Created exercise_sticky_notes table');
  }

  // Helper to clean exercise name (remove API_ID and CUSTOM markers)
  String _cleanExerciseName(String name) {
    return name
        .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
        .replaceAll('##CUSTOM##', '')
        .trim();
  }

  // Get sticky note for an exercise
  Future<String?> getStickyNote(String exerciseName) async {
    final db = await DatabaseService.instance.database;
    final cleanName = _cleanExerciseName(exerciseName);

    final result = await db.query(
      _stickyNotesTableName,
      where: '$_exerciseNameColumnName = ?',
      whereArgs: [cleanName],
    );

    if (result.isNotEmpty) {
      return result.first[_noteColumnName] as String?;
    }
    return null;
  }

  // Set or update sticky note for an exercise
  Future<void> setStickyNote(String exerciseName, String note) async {
    final db = await DatabaseService.instance.database;
    final cleanName = _cleanExerciseName(exerciseName);
    final now = DateTime.now().toIso8601String();

    // Check if sticky note already exists
    final existing = await db.query(
      _stickyNotesTableName,
      where: '$_exerciseNameColumnName = ?',
      whereArgs: [cleanName],
    );

    if (existing.isNotEmpty) {
      // Update existing sticky note
      await db.update(
        _stickyNotesTableName,
        {
          _noteColumnName: note,
          _updatedAtColumnName: now,
        },
        where: '$_exerciseNameColumnName = ?',
        whereArgs: [cleanName],
      );
    } else {
      // Insert new sticky note
      await db.insert(
        _stickyNotesTableName,
        {
          _exerciseNameColumnName: cleanName,
          _noteColumnName: note,
          _createdAtColumnName: now,
          _updatedAtColumnName: now,
        },
      );
    }

    stickyNotesUpdatedNotifier.value = !stickyNotesUpdatedNotifier.value;
  }

  // Delete sticky note for an exercise
  Future<void> deleteStickyNote(String exerciseName) async {
    final db = await DatabaseService.instance.database;
    final cleanName = _cleanExerciseName(exerciseName);

    await db.delete(
      _stickyNotesTableName,
      where: '$_exerciseNameColumnName = ?',
      whereArgs: [cleanName],
    );

    stickyNotesUpdatedNotifier.value = !stickyNotesUpdatedNotifier.value;
  }

  // Check if an exercise has a sticky note
  Future<bool> hasStickyNote(String exerciseName) async {
    final note = await getStickyNote(exerciseName);
    return note != null && note.isNotEmpty;
  }

  // Get all sticky notes
  Future<List<Map<String, dynamic>>> getAllStickyNotes() async {
    final db = await DatabaseService.instance.database;
    return await db.query(_stickyNotesTableName);
  }
}

// TemplateService for managing workout templates
class TemplateService {
  static final ValueNotifier<bool> templatesUpdatedNotifier =
      ValueNotifier(false);
  static final ValueNotifier<bool> foldersUpdatedNotifier =
      ValueNotifier(false);

  // Table and column names
  static const String _templatesTableName = 'workout_templates';
  static const String _templateExercisesTableName = 'template_exercises';
  static const String _templateSetsTableName = 'template_sets';
  static const String _templateFoldersTableName = 'template_folders';

  // Create template tables
  Future<void> createTemplateTables(Database db) async {
    // Create folders table first (templates reference this)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_templateFoldersTableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER,
        order_index INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_templatesTableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        folder_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (folder_id) REFERENCES $_templateFoldersTableName (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_templateExercisesTableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        equipment TEXT,
        order_index INTEGER NOT NULL,
        superset_group TEXT,
        FOREIGN KEY (template_id) REFERENCES $_templatesTableName (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_templateSetsTableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_id INTEGER NOT NULL,
        set_number INTEGER NOT NULL,
        target_reps INTEGER,
        target_weight REAL,
        rest_time INTEGER DEFAULT 150,
        FOREIGN KEY (exercise_id) REFERENCES $_templateExercisesTableName (id) ON DELETE CASCADE
      )
    ''');

    // Add new columns if they don't exist (for migration)
    try {
      await db.execute(
          'ALTER TABLE $_templateExercisesTableName ADD COLUMN superset_group TEXT');
    } catch (e) {
      // Column already exists
    }
    try {
      await db.execute(
          'ALTER TABLE $_templateSetsTableName ADD COLUMN target_weight REAL');
    } catch (e) {
      // Column already exists
    }
    try {
      await db.execute(
          'ALTER TABLE $_templateSetsTableName ADD COLUMN rest_time INTEGER DEFAULT 150');
    } catch (e) {
      // Column already exists
    }
    // Add folder_id column to templates if it doesn't exist
    try {
      await db.execute(
          'ALTER TABLE $_templatesTableName ADD COLUMN folder_id INTEGER');
    } catch (e) {
      // Column already exists
    }
  }

  // Ensure tables exist (for dynamic creation without migration)
  Future<void> ensureTablesExist() async {
    final db = await DatabaseService.instance.database;
    await createTemplateTables(db);
  }

  // ========== FOLDER OPERATIONS ==========

  // Get all folders
  Future<List<TemplateFolder>> getFolders() async {
    await ensureTablesExist();
    final db = await DatabaseService.instance.database;

    final foldersData = await db.query(
      _templateFoldersTableName,
      orderBy: 'order_index ASC, name ASC',
    );

    return foldersData
        .map((data) => TemplateFolder(
              id: data['id'] as int,
              name: data['name'] as String,
              color: data['color'] as int?,
              orderIndex: data['order_index'] as int? ?? 0,
              createdAt: DateTime.parse(data['created_at'] as String),
            ))
        .toList();
  }

  // Create a new folder
  Future<int> createFolder(String name, {int? color}) async {
    await ensureTablesExist();
    final db = await DatabaseService.instance.database;
    final now = DateTime.now().toIso8601String();

    // Get the next order index
    final result = await db.rawQuery(
        'SELECT MAX(order_index) as max_order FROM $_templateFoldersTableName');
    final maxOrder = (result.first['max_order'] as int?) ?? -1;

    final folderId = await db.insert(_templateFoldersTableName, {
      'name': name,
      'color': color,
      'order_index': maxOrder + 1,
      'created_at': now,
      'updated_at': now,
    });

    foldersUpdatedNotifier.value = !foldersUpdatedNotifier.value;
    return folderId;
  }

  // Update a folder
  Future<void> updateFolder(int id, {String? name, int? color}) async {
    await ensureTablesExist();
    final db = await DatabaseService.instance.database;
    final now = DateTime.now().toIso8601String();

    final updates = <String, dynamic>{'updated_at': now};
    if (name != null) updates['name'] = name;
    if (color != null) updates['color'] = color;

    await db.update(
      _templateFoldersTableName,
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );

    foldersUpdatedNotifier.value = !foldersUpdatedNotifier.value;
  }

  // Delete a folder (templates in it become uncategorized)
  Future<void> deleteFolder(int id) async {
    await ensureTablesExist();
    final db = await DatabaseService.instance.database;

    // Templates with this folder_id will have it set to NULL due to ON DELETE SET NULL
    await db.delete(
      _templateFoldersTableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    foldersUpdatedNotifier.value = !foldersUpdatedNotifier.value;
    templatesUpdatedNotifier.value = !templatesUpdatedNotifier.value;
  }

  // Move a template to a folder (or null to remove from folder)
  Future<void> moveTemplateToFolder(int templateId, int? folderId) async {
    await ensureTablesExist();
    final db = await DatabaseService.instance.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      _templatesTableName,
      {
        'folder_id': folderId,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [templateId],
    );

    templatesUpdatedNotifier.value = !templatesUpdatedNotifier.value;
  }

  // Get templates in a specific folder (null for uncategorized)
  Future<List<WorkoutTemplate>> getTemplatesInFolder(int? folderId) async {
    await ensureTablesExist();
    final db = await DatabaseService.instance.database;

    final templatesData = await db.query(
      _templatesTableName,
      where: folderId == null ? 'folder_id IS NULL' : 'folder_id = ?',
      whereArgs: folderId == null ? null : [folderId],
      orderBy: 'updated_at DESC',
    );

    List<WorkoutTemplate> templates = [];
    for (final templateData in templatesData) {
      final exercises = await _getTemplateExercises(templateData['id'] as int);
      templates.add(WorkoutTemplate(
        id: templateData['id'] as int,
        name: templateData['name'] as String,
        folderId: templateData['folder_id'] as int?,
        exercises: exercises,
        createdAt: DateTime.parse(templateData['created_at'] as String),
      ));
    }

    return templates;
  }

  // ========== TEMPLATE OPERATIONS ==========

  // Get all templates
  Future<List<WorkoutTemplate>> getTemplates() async {
    await ensureTablesExist();
    final db = await DatabaseService.instance.database;

    final templatesData = await db.query(
      _templatesTableName,
      orderBy: 'updated_at DESC',
    );

    List<WorkoutTemplate> templates = [];
    for (final templateData in templatesData) {
      final exercises = await _getTemplateExercises(templateData['id'] as int);
      templates.add(WorkoutTemplate(
        id: templateData['id'] as int,
        name: templateData['name'] as String,
        folderId: templateData['folder_id'] as int?,
        exercises: exercises,
        createdAt: DateTime.parse(templateData['created_at'] as String),
      ));
    }

    return templates;
  }

  // Get a single template
  Future<WorkoutTemplate?> getTemplate(int id) async {
    await ensureTablesExist();
    final db = await DatabaseService.instance.database;

    final templatesData = await db.query(
      _templatesTableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (templatesData.isEmpty) return null;

    final templateData = templatesData.first;
    final exercises = await _getTemplateExercises(id);

    return WorkoutTemplate(
      id: templateData['id'] as int,
      name: templateData['name'] as String,
      folderId: templateData['folder_id'] as int?,
      exercises: exercises,
      createdAt: DateTime.parse(templateData['created_at'] as String),
    );
  }

  // Get exercises for a template
  Future<List<TemplateExercise>> _getTemplateExercises(int templateId) async {
    final db = await DatabaseService.instance.database;

    final exercisesData = await db.query(
      _templateExercisesTableName,
      where: 'template_id = ?',
      whereArgs: [templateId],
      orderBy: 'order_index ASC',
    );

    List<TemplateExercise> exercises = [];
    for (final exerciseData in exercisesData) {
      final sets = await _getTemplateSets(exerciseData['id'] as int);
      exercises.add(TemplateExercise(
        name: exerciseData['name'] as String,
        equipment: exerciseData['equipment'] as String? ?? '',
        sets: sets,
        supersetGroup: exerciseData['superset_group'] as String?,
      ));
    }

    return exercises;
  }

  // Get sets for a template exercise
  Future<List<TemplateSet>> _getTemplateSets(int exerciseId) async {
    final db = await DatabaseService.instance.database;

    final setsData = await db.query(
      _templateSetsTableName,
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
      orderBy: 'set_number ASC',
    );

    return setsData
        .map((setData) => TemplateSet(
              setNumber: setData['set_number'] as int,
              targetReps: setData['target_reps'] as int?,
              targetWeight: (setData['target_weight'] as num?)?.toDouble(),
              restTime: (setData['rest_time'] as int?) ?? 150,
            ))
        .toList();
  }

  // Create a new template
  Future<int> createTemplate(
      String name, List<TemplateExercise> exercises,
      {int? folderId}) async {
    await ensureTablesExist();
    final db = await DatabaseService.instance.database;
    final now = DateTime.now().toIso8601String();

    final templateId = await db.insert(_templatesTableName, {
      'name': name,
      'folder_id': folderId,
      'created_at': now,
      'updated_at': now,
    });

    await _saveTemplateExercises(templateId, exercises);

    templatesUpdatedNotifier.value = !templatesUpdatedNotifier.value;
    return templateId;
  }

  // Update an existing template
  Future<void> updateTemplate(
      int id, String name, List<TemplateExercise> exercises,
      {int? folderId}) async {
    await ensureTablesExist();
    final db = await DatabaseService.instance.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      _templatesTableName,
      {
        'name': name,
        'folder_id': folderId,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    // Delete existing exercises and sets (cascade will handle sets)
    await db.delete(
      _templateExercisesTableName,
      where: 'template_id = ?',
      whereArgs: [id],
    );

    await _saveTemplateExercises(id, exercises);

    templatesUpdatedNotifier.value = !templatesUpdatedNotifier.value;
  }

  // Save template exercises
  Future<void> _saveTemplateExercises(
      int templateId, List<TemplateExercise> exercises) async {
    final db = await DatabaseService.instance.database;

    for (int i = 0; i < exercises.length; i++) {
      final exercise = exercises[i];
      final exerciseId = await db.insert(_templateExercisesTableName, {
        'template_id': templateId,
        'name': exercise.name,
        'equipment': exercise.equipment,
        'order_index': i,
        'superset_group': exercise.supersetGroup,
      });

      for (final set in exercise.sets) {
        await db.insert(_templateSetsTableName, {
          'exercise_id': exerciseId,
          'set_number': set.setNumber,
          'target_reps': set.targetReps,
          'target_weight': set.targetWeight,
          'rest_time': set.restTime,
        });
      }
    }
  }

  // Delete a template
  Future<void> deleteTemplate(int id) async {
    await ensureTablesExist();
    final db = await DatabaseService.instance.database;

    await db.delete(
      _templatesTableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    templatesUpdatedNotifier.value = !templatesUpdatedNotifier.value;
  }
}

// Template data models
class TemplateExercise {
  final String name;
  final String equipment;
  final List<TemplateSet> sets;
  final String? supersetGroup;

  TemplateExercise({
    required this.name,
    required this.equipment,
    required this.sets,
    this.supersetGroup,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'equipment': equipment,
      'sets': sets.map((s) => s.toMap()).toList(),
      'supersetGroup': supersetGroup,
    };
  }

  factory TemplateExercise.fromMap(Map<String, dynamic> map) {
    return TemplateExercise(
      name: map['name'] ?? '',
      equipment: map['equipment'] ?? '',
      sets: (map['sets'] as List<dynamic>?)
              ?.map((s) => TemplateSet.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [],
      supersetGroup: map['supersetGroup'],
    );
  }
}

class TemplateSet {
  final int setNumber;
  final int? targetReps;
  final double? targetWeight;
  final int restTime;

  TemplateSet({
    required this.setNumber,
    this.targetReps,
    this.targetWeight,
    this.restTime = 150,
  });

  Map<String, dynamic> toMap() {
    return {
      'setNumber': setNumber,
      'targetReps': targetReps,
      'targetWeight': targetWeight,
      'restTime': restTime,
    };
  }

  factory TemplateSet.fromMap(Map<String, dynamic> map) {
    return TemplateSet(
      setNumber: map['setNumber'] ?? 1,
      targetReps: map['targetReps'],
      targetWeight: map['targetWeight']?.toDouble(),
      restTime: map['restTime'] ?? 150,
    );
  }
}

// Template Folder model
class TemplateFolder {
  final int id;
  final String name;
  final int? color;
  final int orderIndex;
  final DateTime createdAt;

  TemplateFolder({
    required this.id,
    required this.name,
    this.color,
    this.orderIndex = 0,
    required this.createdAt,
  });

  // Get color as Color object with default
  Color getColor() {
    if (color == null) return const Color(0xFF3F8EFC);
    return Color(color!);
  }
}

// Workout Template model
class WorkoutTemplate {
  final int id;
  final String name;
  final int? folderId;
  final List<TemplateExercise> exercises;
  final DateTime createdAt;

  WorkoutTemplate({
    required this.id,
    required this.name,
    this.folderId,
    required this.exercises,
    required this.createdAt,
  });
}

// ========== BODY MEASUREMENTS ==========

// Body Measurement Service for tracking muscle measurements over time
class MeasurementService {
  // Singleton instance
  static final MeasurementService _instance = MeasurementService._internal();
  factory MeasurementService() => _instance;
  MeasurementService._internal();

  // Notifier to inform listeners when measurements change
  static final ValueNotifier<bool> measurementsUpdatedNotifier =
      ValueNotifier(false);

  // Table & column names
  static const String _measurementsTableName = 'body_measurements';
  static const String _idColumnName = 'id';
  static const String _muscleTypeColumnName = 'muscle_type';
  static const String _valueColumnName = 'value';
  static const String _unitColumnName = 'unit';
  static const String _dateColumnName = 'date';
  static const String _notesColumnName = 'notes';
  static const String _createdAtColumnName = 'created_at';

  // Predefined muscle types for measurements
  static const List<MuscleType> muscleTypes = [
    MuscleType(id: 'neck', name: 'Neck', icon: 0xe3e3),
    MuscleType(id: 'shoulders', name: 'Shoulders', icon: 0xe574),
    MuscleType(id: 'chest', name: 'Chest', icon: 0xe574),
    MuscleType(id: 'left_bicep', name: 'Left Bicep', icon: 0xe566),
    MuscleType(id: 'right_bicep', name: 'Right Bicep', icon: 0xe566),
    MuscleType(id: 'left_forearm', name: 'Left Forearm', icon: 0xe566),
    MuscleType(id: 'right_forearm', name: 'Right Forearm', icon: 0xe566),
    MuscleType(id: 'waist', name: 'Waist', icon: 0xe574),
    MuscleType(id: 'hips', name: 'Hips', icon: 0xe574),
    MuscleType(id: 'left_thigh', name: 'Left Thigh', icon: 0xe566),
    MuscleType(id: 'right_thigh', name: 'Right Thigh', icon: 0xe566),
    MuscleType(id: 'left_calf', name: 'Left Calf', icon: 0xe566),
    MuscleType(id: 'right_calf', name: 'Right Calf', icon: 0xe566),
    MuscleType(id: 'weight', name: 'Body Weight', icon: 0xe3b0),
    MuscleType(id: 'body_fat', name: 'Body Fat %', icon: 0xe3b0),
  ];

  // Create measurements table
  Future<void> createMeasurementsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_measurementsTableName (
        $_idColumnName INTEGER PRIMARY KEY AUTOINCREMENT,
        $_muscleTypeColumnName TEXT NOT NULL,
        $_valueColumnName REAL NOT NULL,
        $_unitColumnName TEXT NOT NULL DEFAULT 'cm',
        $_dateColumnName TEXT NOT NULL,
        $_notesColumnName TEXT,
        $_createdAtColumnName TEXT NOT NULL
      )
    ''');

    // Create index for faster queries
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_measurements_muscle_date 
      ON $_measurementsTableName ($_muscleTypeColumnName, $_dateColumnName)
    ''');
  }

  // Ensure table exists
  Future<void> ensureTableExists() async {
    final db = await DatabaseService.instance.database;
    await createMeasurementsTable(db);
  }

  // Add a new measurement
  Future<int> addMeasurement({
    required String muscleType,
    required double value,
    required String unit,
    required DateTime date,
    String? notes,
  }) async {
    await ensureTableExists();
    final db = await DatabaseService.instance.database;
    final now = DateTime.now().toIso8601String();

    final id = await db.insert(_measurementsTableName, {
      _muscleTypeColumnName: muscleType,
      _valueColumnName: value,
      _unitColumnName: unit,
      _dateColumnName: date.toIso8601String().split('T')[0],
      _notesColumnName: notes,
      _createdAtColumnName: now,
    });

    measurementsUpdatedNotifier.value = !measurementsUpdatedNotifier.value;
    return id;
  }

  // Update a measurement
  Future<void> updateMeasurement({
    required int id,
    double? value,
    String? unit,
    DateTime? date,
    String? notes,
  }) async {
    await ensureTableExists();
    final db = await DatabaseService.instance.database;

    final updates = <String, dynamic>{};
    if (value != null) updates[_valueColumnName] = value;
    if (unit != null) updates[_unitColumnName] = unit;
    if (date != null)
      updates[_dateColumnName] = date.toIso8601String().split('T')[0];
    if (notes != null) updates[_notesColumnName] = notes;

    if (updates.isNotEmpty) {
      await db.update(
        _measurementsTableName,
        updates,
        where: '$_idColumnName = ?',
        whereArgs: [id],
      );
      measurementsUpdatedNotifier.value = !measurementsUpdatedNotifier.value;
    }
  }

  // Delete a measurement
  Future<void> deleteMeasurement(int id) async {
    await ensureTableExists();
    final db = await DatabaseService.instance.database;

    await db.delete(
      _measurementsTableName,
      where: '$_idColumnName = ?',
      whereArgs: [id],
    );

    measurementsUpdatedNotifier.value = !measurementsUpdatedNotifier.value;
  }

  // Get all measurements for a specific muscle type
  Future<List<BodyMeasurement>> getMeasurementsForMuscle(
      String muscleType) async {
    await ensureTableExists();
    final db = await DatabaseService.instance.database;

    final data = await db.query(
      _measurementsTableName,
      where: '$_muscleTypeColumnName = ?',
      whereArgs: [muscleType],
      orderBy: '$_dateColumnName DESC',
    );

    return data.map((map) => BodyMeasurement.fromMap(map)).toList();
  }

  // Get the latest measurement for each muscle type
  Future<Map<String, BodyMeasurement>> getLatestMeasurements() async {
    await ensureTableExists();
    final db = await DatabaseService.instance.database;

    final Map<String, BodyMeasurement> latest = {};

    for (final muscleType in muscleTypes) {
      final data = await db.query(
        _measurementsTableName,
        where: '$_muscleTypeColumnName = ?',
        whereArgs: [muscleType.id],
        orderBy: '$_dateColumnName DESC',
        limit: 1,
      );

      if (data.isNotEmpty) {
        latest[muscleType.id] = BodyMeasurement.fromMap(data.first);
      }
    }

    return latest;
  }

  // Get all measurements within a date range
  Future<List<BodyMeasurement>> getMeasurementsInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    await ensureTableExists();
    final db = await DatabaseService.instance.database;

    final data = await db.query(
      _measurementsTableName,
      where: '$_dateColumnName >= ? AND $_dateColumnName <= ?',
      whereArgs: [
        startDate.toIso8601String().split('T')[0],
        endDate.toIso8601String().split('T')[0],
      ],
      orderBy: '$_dateColumnName DESC',
    );

    return data.map((map) => BodyMeasurement.fromMap(map)).toList();
  }

  // Get progress (difference) between first and latest measurement
  Future<Map<String, MeasurementProgress>> getProgress() async {
    await ensureTableExists();
    final db = await DatabaseService.instance.database;

    final Map<String, MeasurementProgress> progress = {};

    for (final muscleType in muscleTypes) {
      final data = await db.query(
        _measurementsTableName,
        where: '$_muscleTypeColumnName = ?',
        whereArgs: [muscleType.id],
        orderBy: '$_dateColumnName ASC',
      );

      if (data.length >= 2) {
        final first = BodyMeasurement.fromMap(data.first);
        final latest = BodyMeasurement.fromMap(data.last);
        final difference = latest.value - first.value;
        final percentChange = (difference / first.value) * 100;

        progress[muscleType.id] = MeasurementProgress(
          muscleType: muscleType.id,
          firstValue: first.value,
          latestValue: latest.value,
          difference: difference,
          percentChange: percentChange,
          firstDate: first.date,
          latestDate: latest.date,
          unit: latest.unit,
        );
      } else if (data.length == 1) {
        final measurement = BodyMeasurement.fromMap(data.first);
        progress[muscleType.id] = MeasurementProgress(
          muscleType: muscleType.id,
          firstValue: measurement.value,
          latestValue: measurement.value,
          difference: 0,
          percentChange: 0,
          firstDate: measurement.date,
          latestDate: measurement.date,
          unit: measurement.unit,
        );
      }
    }

    return progress;
  }

  // Get measurement history for charts
  Future<List<BodyMeasurement>> getMeasurementHistory(String muscleType,
      {int? limit}) async {
    await ensureTableExists();
    final db = await DatabaseService.instance.database;

    final data = await db.query(
      _measurementsTableName,
      where: '$_muscleTypeColumnName = ?',
      whereArgs: [muscleType],
      orderBy: '$_dateColumnName ASC',
      limit: limit,
    );

    return data.map((map) => BodyMeasurement.fromMap(map)).toList();
  }

  /// Convert all measurements from one unit to another
  /// [fromUnit] - the source unit (e.g., 'kg', 'lbs', 'cm', 'in')
  /// [toUnit] - the target unit
  /// [factor] - the conversion factor to multiply values by
  Future<void> convertMeasurements(
      String fromUnit, String toUnit, double factor) async {
    await ensureTableExists();
    final db = await DatabaseService.instance.database;

    // Get all measurements with the source unit
    final data = await db.query(
      _measurementsTableName,
      where: '$_unitColumnName = ?',
      whereArgs: [fromUnit],
    );

    // Update each measurement with converted value and new unit
    for (final row in data) {
      final id = row[_idColumnName] as int;
      final oldValue = row[_valueColumnName] as double;
      final newValue = double.parse((oldValue * factor).toStringAsFixed(2));

      await db.update(
        _measurementsTableName,
        {
          _valueColumnName: newValue,
          _unitColumnName: toUnit,
        },
        where: '$_idColumnName = ?',
        whereArgs: [id],
      );
    }

    // Notify listeners that measurements have been updated
    measurementsUpdatedNotifier.value = !measurementsUpdatedNotifier.value;
  }
}

// Muscle type definition
class MuscleType {
  final String id;
  final String name;
  final int icon;

  const MuscleType({
    required this.id,
    required this.name,
    required this.icon,
  });
}

// Body measurement model
class BodyMeasurement {
  final int id;
  final String muscleType;
  final double value;
  final String unit;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;

  BodyMeasurement({
    required this.id,
    required this.muscleType,
    required this.value,
    required this.unit,
    required this.date,
    this.notes,
    required this.createdAt,
  });

  factory BodyMeasurement.fromMap(Map<String, dynamic> map) {
    return BodyMeasurement(
      id: map['id'] as int,
      muscleType: map['muscle_type'] as String,
      value: (map['value'] as num).toDouble(),
      unit: map['unit'] as String,
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'muscle_type': muscleType,
      'value': value,
      'unit': unit,
      'date': date.toIso8601String().split('T')[0],
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Measurement progress model
class MeasurementProgress {
  final String muscleType;
  final double firstValue;
  final double latestValue;
  final double difference;
  final double percentChange;
  final DateTime firstDate;
  final DateTime latestDate;
  final String unit;

  MeasurementProgress({
    required this.muscleType,
    required this.firstValue,
    required this.latestValue,
    required this.difference,
    required this.percentChange,
    required this.firstDate,
    required this.latestDate,
    required this.unit,
  });
}
