import 'dart:async';
import 'package:mental_warior/models/goals.dart';
import 'package:mental_warior/models/tasks.dart';
import 'package:mental_warior/models/habits.dart';
import 'package:mental_warior/models/books.dart';
import 'package:mental_warior/models/categories.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';

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
      version: 3,
      onCreate: (db, version) {
        TaskService().createTaskTable(db);
        CompletedTaskService().createCompletedTaskTable(db);
        HabitService().createHabitTable(db);
        GoalService().createGoalTable(db);
        BookService().createbookTable(db);
        CategoryService().createCategoryTable(db);
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

  Future<void> updateTask(int id, String fieldToUpdate, String key) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      _taskTableName,
      {fieldToUpdate: key},
      where: "id = ?",
      whereArgs: [id],
    );
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

  void createCompletedTaskTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_completedTaskTableName (
        $_taskIdColumnName INTEGER PRIMARY KEY,
        $_taskLabelColumnName TEXT NOT NULL,
        $_taskStatusColumnName INTEGER NOT NULL,
        $_taskDeadlineColumnName TEXT,
        $_taskDescriptionColumnName TEXT,
        $_taskCategoryColumnName TEXT
      )
    ''');
  }

  Future addCompletedTask(String label, String deadline, String description,
      String category) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      _completedTaskTableName,
      {
        _taskLabelColumnName: label,
        _taskStatusColumnName: 0,
        _taskDeadlineColumnName: deadline,
        _taskDescriptionColumnName: description,
        _taskCategoryColumnName: category,
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
