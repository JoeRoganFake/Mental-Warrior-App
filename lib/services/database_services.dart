// import 'dart:async';

// import 'package:mental_warior/models/tasks.dart';
// import 'package:path/path.dart';
// import 'package:sqflite/sqflite.dart';

// class DatabaseServices {
//   static Database? _db;
//   static final DatabaseServices instace = DatabaseServices._constructor();

//   final String _taskTableName = "tasks";
//   final String _taskIdColumnName = "id";
//   final String _taskLabelColumnName = "label";
//   final String _taskDescriptionColumnName = "descripton";
//   final String _taskStatusColumnName = "status";
//   final String _taskDeadlineColumnName = "deadline";

//   DatabaseServices._constructor();

//   Future<Database> get database async {
//     if (_db != null) {
//       print("exist");
//       return _db!;
//     }
//     ;
//     _db = await getDatabase();
//     print("doesnt");
//     return _db!;
//   }

//   Future<Database> getDatabase() async {
//     final databaseDirPath = await getDatabasesPath();
//     final databasePath = join(databaseDirPath, "maste_db.db");

//     final database = await openDatabase(
//       databasePath,
//       version: 1,
//       onCreate: (db, version) {
//         db.execute('''
//         CREATE TABLE $_taskTableName (
//           $_taskIdColumnName INTIGER PRIMARY KEY,
//           $_taskLabelColumnName TEXT NOT NULL,
//           $_taskDescriptionColumnName TEXT,
//           $_taskDeadlineColumnName TEXT,
//           $_taskStatusColumnName INTEGER NOT NULL,
//         )
//           ''');
//       },
//     );
//     return database;
//   }

//   void addTask(
//     String label,
//     String? description,
//     String? deadline,
//   ) async {
//     final db = await database;
//     await db.insert(
//       _taskTableName,
//       {
//         _taskLabelColumnName: label,
//         _taskDescriptionColumnName: description,
//         _taskDeadlineColumnName: deadline,
//         _taskStatusColumnName: 0,
//       },
//     );
//   }

//   Future<List<TaskModel>> getTasks() async {
//     final db = await database;
//     final data = await db.query(_taskTableName);
//     List<TaskModel> tasks = data
//         .map((e) => TaskModel(
//               id: e["id"] as int,
//               label: e["label"] as String,
//               status: e["status"] as int,
//               description: e["description"] as String,
//               deadline: e['deadline'] as String,
//             ))
//         .toList();
//     return tasks;
//   }

// }

import 'dart:async';

import 'package:mental_warior/models/tasks.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static Database? _db;
  static final DatabaseService instace = DatabaseService._constructor();

  final String _taskTableName = "tasks";

  final String _taskIdColumnName = "id";
  final String _taskContentColumnName = "content";
  final String _taskStatusColumnName = "status";

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
          $_taskContentColumnName TEXT NOT NULL,
          $_taskStatusColumnName INTEGER NOT NULL
        ) 
          ''');
      },
    );
    return database;
  }

  void addTask(String content) async {
    final db = await database;
    await db.insert(
      _taskTableName,
      {
        _taskContentColumnName: content,
        _taskStatusColumnName: 0,
      },
    );
  }

  Future<List<Task>?> getTasks() async {
    final db = await database;
    final data = await db.query(_taskTableName);
    List<Task> task = data
        .map((e) => Task(
            id: e["id"] as int,
            status: e["status"] as int,
            content: e["content"] as String))
        .toList();
    return task;
  }
}
