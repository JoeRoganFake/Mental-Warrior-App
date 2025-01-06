import 'dart:async';
import 'package:mental_warior/models/tasks.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static Database? _db;
  static final DatabaseService instace = DatabaseService._constructor();

  final String _taskTableName = "tasks";

  final String _taskIdColumnName = "id";
  final String _tasklabelColumnName = "label";
  final String _taskStatusColumnName = "status";
  final String _taskDescriptionColumnName = "description";
  final String _taskDeadlineColumnName = "deadline";

  DatabaseService._constructor();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await getDatabase();
    return _db!;
  }

  Future<Database> getDatabase() async {
    final databaseDirPath = await getDatabasesPath();
    final databasePath = join(databaseDirPath, "maste_db.db");

    final database = await openDatabase(
      databasePath,
      version: 2,
      onCreate: (db, version) {
        db.execute('''
        CREATE TABLE $_taskTableName (
          $_taskIdColumnName INTEGER PRIMARY KEY,
          $_tasklabelColumnName TEXT NOT NULL,
          $_taskStatusColumnName INTEGER NOT NULL,
          $_taskDeadlineColumnName TEXT,
          $_taskDescriptionColumnName TEXT
        ) 
          ''');
      },
    );
    return database;
  }

  void addTask(String label, String deadline, String description) async {
    final db = await database;
    await db.insert(
      _taskTableName,
      {
        _tasklabelColumnName: label,
        _taskStatusColumnName: 0,
        _taskDeadlineColumnName: deadline,
        _taskDescriptionColumnName: description,
      },
    );
  }

  Future<List<Task>?> getTasks() async {
    final db = await database;
    final data = await db.query(_taskTableName);

    List<Task> tasks = data
        .map(
          (e) => Task(
            id: e[_taskIdColumnName] as int,
            status: e[_taskStatusColumnName] as int,
            label: e[_tasklabelColumnName] as String,
            description: e[_taskDescriptionColumnName] as String,
            deadline: e[_taskDeadlineColumnName] as String,
          ),
        )
        .toList();
    return tasks;
  }

  void updateTaskStatus(int id, int status) async {
    final db = await database;
    await db.update(
      _taskTableName,
      {_taskStatusColumnName: status},
      where: "id = ?",
      whereArgs: [id],
    );
  }

  void deleteTask(int id) async {
    final db = await database;
    await db.delete(_taskTableName, where: "id = ?", whereArgs: [id]);
  }
}
