// import 'package:flutter/material.dart';
// import 'package:mental_warior/services/database_services.dart';
// import 'package:mental_warior/models/tasks.dart';

// class TasksPage extends StatefulWidget {
//   const TasksPage({super.key});

//   @override
//   _TasksPageState createState() => _TasksPageState();
// }

// class _TasksPageState extends State<TasksPage> {
//   final TaskService _taskService = TaskService();
//   final TextEditingController _taskController = TextEditingController();
//   final TextEditingController _categoryController = TextEditingController();
//   String selectedCategory = "Uncategorized";

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Tasks"),
//         centerTitle: true,
//         backgroundColor: Colors.blueAccent,
//       ),
//       body: FutureBuilder<List<Task>>(
//         future: _taskService.getTasks(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           } else if (snapshot.hasError) {
//             return const Center(child: Text("Error loading tasks"));
//           } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return const Center(
//               child: Text(
//                 "No tasks available",
//                 style: TextStyle(fontSize: 18, color: Colors.grey),
//               ),
//             );
//           } else {
//             final tasks = snapshot.data!;
//             final categories = _groupTasksByCategory(tasks);

//             return ListView.builder(
//               itemCount: categories.length,
//               itemBuilder: (context, index) {
//                 final category = categories.keys.elementAt(index);
//                 final categoryTasks = categories[category]!;

//                 return Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 8.0),
//                   child: Card(
//                     elevation: 3,
//                     margin: const EdgeInsets.symmetric(horizontal: 16),
//                     child: ExpansionTile(
//                       title: Text(
//                         category,
//                         style: const TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       children: categoryTasks.map((task) {
//                         return ListTile(
//                           title: Text(
//                             task.label,
//                             style: const TextStyle(fontWeight: FontWeight.w600),
//                           ),
//                           subtitle: Text(task.description ?? "No description"),
//                           trailing: IconButton(
//                             icon: const Icon(Icons.delete, color: Colors.red),
//                             onPressed: () async {
//                               await _taskService.deleteTask(task.id);
//                               setState(() {});
//                             },
//                           ),
//                         );
//                       }).toList(),
//                     ),
//                   ),
//                 );
//               },
//             );
//           }
//         },
//       ),
//       bottomNavigationBar: BottomAppBar(
//         color: Colors.grey[900],
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//           child: Row(
//             children: [
//               Expanded(
//                 child: TextField(
//                   controller: _taskController,
//                   decoration: const InputDecoration(
//                     hintText: "New task",
//                     hintStyle: TextStyle(color: Colors.grey),
//                     border: InputBorder.none,
//                   ),
//                   style: const TextStyle(color: Colors.white),
//                 ),
//               ),
//               IconButton(
//                 icon: const Icon(Icons.category, color: Colors.white),
//                 onPressed: () {
//                   _showCategoryDialog(context);
//                 },
//               ),
//               IconButton(
//                 icon: const Icon(Icons.save, color: Colors.white),
//                 onPressed: () async {
//                   if (_taskController.text.isNotEmpty) {
//                     await _taskService.addTask(
//                       _taskController.text,
//                       "${DateTime.now()}",
//                       "${DateTime.now()}",
//                       "${DateTime.now()}",
//                       "${DateTime.now()}",
//                     );
//                     _taskController.clear();
//                     setState(() {});
//                   }
//                 },
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // Group tasks by category
//   Map<String, List<Task>> _groupTasksByCategory(List<Task> tasks) {
//     final Map<String, List<Task>> categories = {};
//     for (var task in tasks) {
//       final category = task.category ?? "Uncategorized";
//       if (!categories.containsKey(category)) {
//         categories[category] = [];
//       }
//       categories[category]!.add(task);
//     }
//     return categories;
//   }

//   // Show category selection dialog
//   void _showCategoryDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text("Select Category"),
//           content: TextField(
//             controller: _categoryController,
//             decoration: const InputDecoration(
//               hintText: "Enter category",
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(context);
//               },
//               child: const Text("Cancel"),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 setState(() {
//                   selectedCategory = _categoryController.text.isNotEmpty
//                       ? _categoryController.text
//                       : "Uncategorized";
//                 });
//                 Navigator.pop(context);
//               },
//               child: const Text("Save"),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
