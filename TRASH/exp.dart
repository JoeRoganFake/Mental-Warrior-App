// import 'dart:async';
// import 'dart:math';
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:mental_warior/models/books.dart';
// import 'package:mental_warior/models/goals.dart';
// import 'package:mental_warior/models/habits.dart';
// import 'package:mental_warior/models/tasks.dart';
// import 'package:mental_warior/pages/tasks_p.dart';
// import 'package:mental_warior/services/database_services.dart';
// import 'package:mental_warior/services/quote_service.dart';
// import 'package:mental_warior/utils/functions.dart';
// import 'dart:isolate';
// import 'package:mental_warior/pages/meditation.dart';
// import 'package:permission_handler/permission_handler.dart';

// class HomePage extends StatefulWidget {
//   const HomePage({super.key});

//   @override
//   State<HomePage> createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   var function = Functions();
//   final _dateController = TextEditingController();
//   final _labelController = TextEditingController();
//   final _descriptionController = TextEditingController();
//   final _taskController = TextEditingController();
//   final _timeController = TextEditingController();
//   final TaskService _taskService = TaskService();
//   final CompletedTaskService _completedTaskService = CompletedTaskService();
//   final HabitService _habitService = HabitService();
//   final GoalService _goalService = GoalService();
//   final BookService _bookServiceLib = BookService();
//   bool _isExpanded = false;
//   Map<int, bool> taskDeletedState = {};
//   static const String isolateName = 'background_task_port';
//   final ReceivePort _receivePort = ReceivePort();
//   final QuoteService _quoteService = QuoteService();
//   int _currentIndex = 0;
//   String? selectedCategory = "Default";
//   String selectedRepeatOption = "None";

//   @override
//   void initState() {
//     super.initState();
//     requestNotificationPermission();
//     IsolateNameServer.registerPortWithName(_receivePort.sendPort, isolateName);

//     _receivePort.listen((message) {
//       setState(() {});
//     });
//   }

//   @override
//   void dispose() {
//     IsolateNameServer.removePortNameMapping(isolateName);
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       floatingActionButton: _currentIndex == 0
//           ? FloatingActionButton(
//               splashColor: Colors.blue,
//               onPressed: () {
//                 showMenu(
//                   context: context,
//                   position: RelativeRect.fromLTRB(
//                     MediaQuery.of(context).size.width - 5,
//                     MediaQuery.of(context).size.height - 250,
//                     20,
//                     0,
//                   ),
//                   items: [
//                     PopupMenuItem<String>(
//                       value: 'task',
//                       child: const Text('Task'),
//                       onTap: () => taskFormDialog(context),
//                     ),
//                     PopupMenuItem<String>(
//                       value: 'habit',
//                       child: Text('Habit',
//                           style: TextStyle(
//                               color: const Color.fromARGB(255, 107, 107, 107))),
//                       onTap: () => habitFormDialog(),
//                     ),
//                     PopupMenuItem<String>(
//                       value: 'goal',
//                       child: Text(
//                         'Long Term Goal',
//                         style: TextStyle(
//                             color: const Color.fromARGB(255, 107, 107, 107)),
//                       ),
//                       onTap: () => goalFormDialog(),
//                     ),
//                     PopupMenuItem<String>(
//                       value: 'book',
//                       child: Text('Book'),
//                       onTap: () => bookFormDialog(context),
//                     ),
//                   ],
//                 );
//               },
//               backgroundColor: const Color.fromARGB(255, 103, 113, 121),
//               child: const Icon(
//                 Icons.add,
//                 color: Colors.white,
//               ),
//             )
//           : null,
//       backgroundColor: Colors.white,
//       body: MediaQuery.removePadding(
//         context: context,
//         removeTop: true,
//         child: _currentIndex == 0
//             ? _buildHomePage()
//             : _currentIndex == 1
//                 ? MeditationPage()
//                 : TasksPage(),
//       ),
//       bottomNavigationBar: BottomNavigationBar(
//         currentIndex: _currentIndex,
//         onTap: (index) {
//           setState(() {
//             _currentIndex = index;
//           });
//         },
//         items: [
//           BottomNavigationBarItem(
//             icon: Icon(Icons.home,
//                 color: _currentIndex == 0 ? Colors.blue : Colors.grey),
//             label: 'Home',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.self_improvement,
//                 color: _currentIndex == 1 ? Colors.blue : Colors.grey),
//             label: 'Meditation',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.list,
//                 color: _currentIndex == 2 ? Colors.blue : Colors.grey),
//             label: 'Tasks',
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildHomePage() {
//     return ListView(
//       padding: const EdgeInsets.all(20),
//       children: [
//         Padding(
//           padding: const EdgeInsets.only(top: 30),
//           child: Text(
//             "Good Productive ${function.getTimeOfDayDescription()}.",
//             style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//           ),
//         ),
//         Text(
//           " Daily Quote",
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//         SizedBox(height: 20),
//         Text(
//           '"${_quoteService.getDailyQuote().text}"',
//           textAlign: TextAlign.center,
//           style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
//         ),
//         SizedBox(height: 20),
//         Text(
//           "- ${_quoteService.getDailyQuote().author}",
//           style: TextStyle(fontSize: 14, fontStyle: FontStyle.normal),
//         ),
//         const SizedBox(height: 25),
//         Text(
//           "Goals",
//           textAlign: TextAlign.left,
//           style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//         ),
//         const SizedBox(height: 20),
//         _goalList(),
//         const SizedBox(height: 25),
//         Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Flexible(
//               flex: 2,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     "Tasks Today",
//                     textAlign: TextAlign.start,
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//                   ),
//                   const SizedBox(height: 20),
//                   _taskList(),
//                   _completedTaskList(),
//                 ],
//               ),
//             ),
//             const SizedBox(width: 20),
//             Flexible(
//               flex: 2,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     "Habits Today",
//                     textAlign: TextAlign.start,
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//                   ),
//                   const SizedBox(height: 20),
//                   _habitList()
//                 ],
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(
//           height: 20,
//         ),
//         _bookList(),
//       ],
//     );
//   }

//   void taskFormDialog(BuildContext context, {Task? taskToEdit}) {
//     Timer? debounce;

//     If editing, set the initial values
//     if (taskToEdit != null) {
//       _taskController.text = taskToEdit.label; // For the task name
//       _descriptionController.text = taskToEdit.description;
//       if (taskToEdit.deadline.isNotEmpty) {
//         final parts = taskToEdit.deadline.split(' ');
//         if (parts.isNotEmpty) _dateController.text = parts[0];
//         if (parts.length > 1) _timeController.text = parts[1];
//       }
//       selectedCategory = taskToEdit.category; // For the category
//       selectedRepeatOption = taskToEdit.repeatOption;
//     }

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.grey[900],
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return Padding(
//               padding: EdgeInsets.only(
//                 left: 16.0,
//                 right: 16.0,
//                 top: 16.0,
//                 bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextField for task input
//                   TextField(
//                     controller:
//                         _taskController, // Use _taskController for the task name
//                     decoration: const InputDecoration(
//                       hintText: "New task",
//                       hintStyle: TextStyle(color: Colors.grey),
//                       border: InputBorder.none,
//                     ),
//                     style: const TextStyle(color: Colors.white),
//                     onChanged: (value) {
//                       if (debounce?.isActive ?? false) debounce!.cancel();
//                       debounce = Timer(const Duration(milliseconds: 300), () {
//                         debugPrint("User typed: $value");
//                       });
//                     },
//                   ),
//                   const SizedBox(height: 10),

//                   Display selected category and edit button
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         selectedCategory ??
//                             "Default", // Use selectedCategory for the category
//                         style: const TextStyle(color: Colors.white),
//                       ),
//                       Row(
//                         children: [
//                           IconButton(
//                             icon:
//                                 const Icon(Icons.category, color: Colors.white),
//                             onPressed: () {
//                               _showCategoryDialog(context, setState);
//                             },
//                           ),
//                           IconButton(
//                             icon: const Icon(Icons.edit, color: Colors.white),
//                             onPressed: () async {
//                               await _selectDateAndTime(context, (fn) => fn());
//                             },
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),

//                   Conditional content for date/time/repeat
//                   if (_dateController.text.isNotEmpty ||
//                       _timeController.text.isNotEmpty ||
//                       selectedRepeatOption != "None") ...[
//                     const SizedBox(height: 10),
//                     Display selected date with delete option
//                     if (_dateController.text.isNotEmpty)
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Row(
//                             children: [
//                               const Icon(Icons.calendar_today,
//                                   color: Colors.white),
//                               const SizedBox(width: 8),
//                               Text(
//                                 _dateController.text,
//                                 style: const TextStyle(color: Colors.white),
//                               ),
//                             ],
//                           ),
//                           IconButton(
//                             icon: const Icon(Icons.delete, color: Colors.red),
//                             onPressed: () {
//                               setState(() {
//                                 _dateController.clear();
//                               });
//                             },
//                           ),
//                         ],
//                       ),

//                     Display selected time with delete option
//                     if (_timeController.text.isNotEmpty)
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Row(
//                             children: [
//                               const Icon(Icons.access_time,
//                                   color: Colors.white),
//                               const SizedBox(width: 8),
//                               Text(
//                                 _timeController.text,
//                                 style: const TextStyle(color: Colors.white),
//                               ),
//                             ],
//                           ),
//                           IconButton(
//                             icon: const Icon(Icons.delete, color: Colors.red),
//                             onPressed: () {
//                               setState(() {
//                                 _timeController.clear();
//                               });
//                             },
//                           ),
//                         ],
//                       ),

//                     Display selected repeat option with delete option
//                     if (selectedRepeatOption != "None")
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Row(
//                             children: [
//                               const Icon(Icons.repeat, color: Colors.white),
//                               const SizedBox(width: 8),
//                               Text(
//                                 selectedRepeatOption,
//                                 style: const TextStyle(color: Colors.white),
//                               ),
//                             ],
//                           ),
//                           IconButton(
//                             icon: const Icon(Icons.delete, color: Colors.red),
//                             onPressed: () {
//                               setState(() {
//                                 selectedRepeatOption = "None";
//                               });
//                             },
//                           ),
//                         ],
//                       ),
//                   ],

//                   const SizedBox(height: 10),

//                   Save button row
//                   Row(
//                     children: [
//                       const Spacer(),
//                       ElevatedButton(
//                         onPressed: () async {
//                           if (_taskController.text.isNotEmpty) {
//                             final String deadline =
//                                 "${_dateController.text} ${_timeController.text}"
//                                     .trim();

//                             if (taskToEdit != null) {
//                               try {
//                                 await _taskService.updateTaskFull(
//                                   taskToEdit.id,
//                                   _taskController.text,
//                                   deadline,
//                                   _descriptionController.text,
//                                   selectedCategory ?? "Default",
//                                   selectedRepeatOption,
//                                 );

//                                 Navigator.pop(context);
//                               } catch (e) {
//                                 ScaffoldMessenger.of(context).showSnackBar(
//                                   SnackBar(
//                                       content:
//                                           Text('Failed to update task: $e')),
//                                 );
//                               }
//                             } else {
//                               Add new task
//                               await _taskService.addTask(
//                                 _taskController.text,
//                                 deadline,
//                                 _descriptionController.text,
//                                 selectedCategory ?? "Default",
//                                 selectedRepeatOption,
//                               );
//                             }

//                             Update both the local state and UI
//                             setState(() {});
//                             Navigator.pop(context);
//                           }
//                         },
//                         child: Text(taskToEdit != null ? "Update" : "Save"),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     ).whenComplete(() {
//       Clear the controllers after the popup disappears
//       _taskController.clear();
//       _dateController.clear();
//       _timeController.clear();
//       _descriptionController.clear();
//       selectedRepeatOption = "None";
//       selectedCategory = "Default";
//     });
//   }

//   Future<dynamic> habitFormDialog({bool add = true, Habit? habit}) {
//     final GlobalKey<FormState> habitFormKey = GlobalKey<FormState>();
//     if (!add) {
//       _labelController.text = habit!.label;
//       _descriptionController.text = habit.description;
//     }
//     return showDialog(
//       context: context,
//       builder: (context) => SimpleDialog(
//         children: [
//           Form(
//             key: habitFormKey,
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 Padding(
//                   padding: const EdgeInsets.all(8),
//                   child: Text(
//                     add ? "New Habit" : "Edit Habit",
//                   ),
//                 ),
//                 TextFormField(
//                   controller: _labelController,
//                   autofocus: true,
//                   validator: (value) {
//                     if (value!.isEmpty || value == "") {
//                       return "     *Field Is Required";
//                     }
//                     return null;
//                   },
//                   decoration: InputDecoration(
//                       hintText: "Label",
//                       prefixIcon: const Icon(Icons.label),
//                       border: InputBorder.none),
//                 ),
//                 TextFormField(
//                   controller: _descriptionController,
//                   maxLines: null,
//                   keyboardType: TextInputType.multiline,
//                   decoration: InputDecoration(
//                       hintText: "Description",
//                       prefixIcon: const Icon(Icons.description),
//                       border: InputBorder.none),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     if (add) {
//                       if (habitFormKey.currentState!.validate()) {
//                         _habitService.addHabit(
//                           _labelController.text,
//                           _descriptionController.text,
//                         );
//                         Navigator.pop(context);
//                         setState(() {});
//                       }
//                     } else {
//                       if (habitFormKey.currentState!.validate()) {
//                         _habitService.updateHabit(
//                             habit!.id, "label", _labelController.text);
//                         _habitService.updateHabit(habit.id, "description",
//                             _descriptionController.text);
//                         Navigator.pop(context);
//                         setState(() {});
//                       }
//                     }
//                   },
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: const Icon(Icons.add_task_outlined),
//                       ),
//                       Text(
//                         add ? "Add Habit" : "Edit Habit",
//                         textAlign: TextAlign.center,
//                         style: TextStyle(),
//                       )
//                     ],
//                   ),
//                 )
//               ],
//             ),
//           ),
//         ],
//       ),
//     ).then((_) {
//       Future.delayed(const Duration(milliseconds: 100), () {
//         _labelController.clear();
//         _descriptionController.clear();
//       });
//     });
//   }

//   Future<dynamic> goalFormDialog() {
//     final GlobalKey<FormState> goalFormKey = GlobalKey<FormState>();
//     return showDialog(
//       context: context,
//       builder: (context) => SimpleDialog(
//         children: [
//           Form(
//             key: goalFormKey,
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 Padding(
//                   padding: const EdgeInsets.all(8),
//                   child: Text(
//                     "New Long-Term Goal",
//                   ),
//                 ),
//                 TextFormField(
//                   controller: _labelController,
//                   autofocus: true,
//                   validator: (value) {
//                     if (value!.isEmpty || value == "") {
//                       return "     *Field Is Required";
//                     }
//                     return null;
//                   },
//                   decoration: InputDecoration(
//                       hintText: "Goal",
//                       prefixIcon: const Icon(Icons.label),
//                       border: InputBorder.none),
//                 ),
//                 TextFormField(
//                   controller: _descriptionController,
//                   maxLines: null,
//                   keyboardType: TextInputType.multiline,
//                   decoration: InputDecoration(
//                       hintText: "Description",
//                       prefixIcon: const Icon(Icons.description),
//                       border: InputBorder.none),
//                 ),
//                 TextFormField(
//                   controller: _dateController,
//                   validator: (value) {
//                     if (value!.isEmpty || value == "") {
//                       return "     *Field Is Required";
//                     }
//                     return null;
//                   },
//                   onTap: () {
//                     Functions.dateAndTimePicker(context, _dateController,
//                         onlyDate: true);
//                   },
//                   readOnly: true,
//                   decoration: InputDecoration(
//                       hintText: "Due To",
//                       prefixIcon: const Icon(Icons.calendar_month),
//                       border: InputBorder.none),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     if (goalFormKey.currentState!.validate()) {
//                       showDialog(
//                         context: context,
//                         builder: (context) => AlertDialog(
//                           title: Text("Confirm Goal"),
//                           content: Text(
//                             "Are you sure that "
//                             "goal ${_labelController.text} is a achievable until  ${_dateController.text}\n\n"
//                             "Long-Term goals are not easily updated.\n"
//                             "Think about it first!",
//                           ),
//                           actions: [
//                             TextButton(
//                               onPressed: () => Navigator.pop(context), // Cancel
//                               child: Text("Cancel"),
//                             ),
//                             ElevatedButton(
//                               onPressed: () {
//                                 _goalService.addGoal(
//                                   _labelController.text,
//                                   _dateController.text,
//                                   _descriptionController.text,
//                                 );
//                                 Navigator.pop(
//                                     context); // Close confirmation dialog
//                                 Navigator.pop(
//                                     context); // Close goal form dialog
//                                 setState(() {});
//                               },
//                               child: Text("Confirm"),
//                             ),
//                           ],
//                         ),
//                       );
//                     }
//                   },
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: Icon(Icons.add_task_outlined),
//                       ),
//                       Text(
//                         "Add Goal",
//                         textAlign: TextAlign.center,
//                       )
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     ).then((_) {
//       Future.delayed(const Duration(milliseconds: 100), () {
//         _labelController.clear();
//         _descriptionController.clear();
//         _dateController.clear();
//       });
//     });
//   }

//   Future<dynamic> bookFormDialog(BuildContext context) {
//     final TextEditingController titleController = TextEditingController();
//     final TextEditingController pagesController = TextEditingController();
//     final formKey = GlobalKey<FormState>();

//     return showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text("Manual Book Entry"),
//           content: Form(
//             key: formKey,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 TextFormField(
//                   controller: titleController,
//                   decoration: const InputDecoration(
//                     hintText: "Book Title",
//                     prefixIcon: Icon(Icons.book),
//                     border: OutlineInputBorder(),
//                   ),
//                   validator: (value) =>
//                       value!.isEmpty ? "Field is required" : null,
//                 ),
//                 const SizedBox(height: 10),
//                 TextFormField(
//                   controller: pagesController,
//                   keyboardType: TextInputType.number,
//                   decoration: const InputDecoration(
//                     hintText: "Total Pages",
//                     prefixIcon: Icon(Icons.pages),
//                     border: OutlineInputBorder(),
//                   ),
//                   validator: (value) {
//                     if (value!.isEmpty) return "Field is required";
//                     if (int.tryParse(value) == null || int.parse(value) <= 2) {
//                       return "Must be greater than 2";
//                     }
//                     return null;
//                   },
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text("Cancel"),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 if (formKey.currentState!.validate()) {
//                   _bookServiceLib.addBook(
//                       titleController.text, int.parse(pagesController.text));
//                   Navigator.pop(context);
//                 }
//               },
//               child: const Text("Confirm"),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _completedTaskList() {
//     return Padding(
//       padding: const EdgeInsets.only(top: 20),
//       child: Container(
//         width: 200,
//         child: FutureBuilder(
//             future: _completedTaskService.getCompletedTasks(),
//             builder: (context, snapshot) {
//               if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                 _isExpanded = false;
//                 return SizedBox.shrink();
//               }

//               return SingleChildScrollView(
//                 child: ExpansionPanelList(
//                   expansionCallback: (int index, bool isExpanded) {
//                     setState(() {
//                       _isExpanded = !_isExpanded;
//                     });
//                   },
//                   children: [
//                     ExpansionPanel(
//                       headerBuilder: (context, isExpanded) {
//                         return ListTile(
//                           title: Text(
//                             "Completed Tasks",
//                           ),
//                         );
//                       },
//                       body: Column(
//                         children: snapshot.data?.map<Widget>((ctask) {
//                               bool isTaskDeleted =
//                                   taskDeletedState[ctask.id] ?? false;
//                               return Padding(
//                                 padding: const EdgeInsets.all(6.0),
//                                 child: GestureDetector(
//                                   child: AnimatedOpacity(
//                                     duration: const Duration(milliseconds: 200),
//                                     opacity: isTaskDeleted ? 0.0 : 1.0,
//                                     child: Container(
//                                       decoration: BoxDecoration(
//                                         borderRadius: BorderRadius.circular(16),
//                                         color: const Color.fromARGB(
//                                             255, 119, 119, 119),
//                                       ),
//                                       child: Row(
//                                         mainAxisAlignment:
//                                             MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           Flexible(
//                                             child: Padding(
//                                               padding: const EdgeInsets.only(
//                                                   left: 30),
//                                               child: Text(
//                                                 ctask.label,
//                                                 style: TextStyle(
//                                                   color: Colors.white,
//                                                   decoration: TextDecoration
//                                                       .lineThrough,
//                                                   decorationColor: Colors.white,
//                                                   decorationThickness: 2,
//                                                   overflow:
//                                                       TextOverflow.ellipsis,
//                                                 ),
//                                               ),
//                                             ),
//                                           ),
//                                           Padding(
//                                             padding: const EdgeInsets.only(
//                                                 right: 30),
//                                             child: Checkbox(
//                                               value: true, // Always checked
//                                               onChanged: (value) async {
//                                                 if (value == false) {
//                                                   Move back to active tasks
//                                                   await _taskService.addTask(
//                                                     ctask.label,
//                                                     ctask.deadline,
//                                                     ctask.description,
//                                                     ctask.category,
//                                                     "None",
//                                                   );
//                                                   await _completedTaskService
//                                                       .deleteCompTask(ctask.id);
//                                                   setState(() {});
//                                                 }
//                                               },
//                                             ),
//                                           )
//                                         ],
//                                       ),
//                                     ),
//                                   ),
//                                   onTap: () {
//                                     _labelController.text = ctask.label;
//                                     _dateController.text = ctask.deadline;
//                                     _descriptionController.text =
//                                         ctask.description;
//                                     selectedCategory = ctask.category;
//                                     taskFormDialog(context, taskToEdit: ctask);
//                                   },
//                                 ),
//                               );
//                             }).toList() ??
//                             [],
//                       ),
//                       isExpanded: _isExpanded,
//                     ),
//                   ],
//                 ),
//               );
//             }),
//       ),
//     );
//   }

//   _taskList() {
//     return FutureBuilder(
//       future: _taskService.getTasks(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData || snapshot.data!.isEmpty) {
//           return const Center(child: Text("No tasks yet"));
//         }
//         return Column(
//           children: snapshot.data!.map<Widget>((task) {
//             return Padding(
//               padding: const EdgeInsets.all(6.0),
//               child: GestureDetector(
//                 onTap: () {
//                   taskFormDialog(context, taskToEdit: task);
//                 },
//                 onLongPress: () {
//                   Show confirmation dialog before deleting
//                   showDialog(
//                     context: context,
//                     builder: (context) => AlertDialog(
//                       title: const Text("Delete Task"),
//                       content: const Text(
//                           "Are you sure you want to delete this task?"),
//                       actions: [
//                         TextButton(
//                           onPressed: () => Navigator.pop(context),
//                           child: const Text("Cancel"),
//                         ),
//                         TextButton(
//                           onPressed: () async {
//                             await _taskService.deleteTask(task.id);
//                             setState(() {});
//                             Navigator.pop(context);
//                           },
//                           child: const Text("Delete",
//                               style: TextStyle(color: Colors.red)),
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//                 child: Container(
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(16),
//                     color: const Color.fromARGB(255, 119, 119, 119),
//                   ),
//                   child: Column(
//                     children: [
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Flexible(
//                             child: Padding(
//                               padding: const EdgeInsets.only(left: 30),
//                               child: Text(
//                                 task.label,
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   overflow: TextOverflow.ellipsis,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           Padding(
//                             padding: const EdgeInsets.only(right: 30),
//                             child: Checkbox(
//                               value: task.status == 1,
//                               onChanged: (value) async {
//                                 setState(() {
//                                   _taskService.updateTaskStatus(
//                                       task.id, value == true ? 1 : 0);
//                                 });

//                                 await Future.delayed(
//                                     const Duration(milliseconds: 250));

//                                 if (value == true) {
//                                   await _completedTaskService.addCompletedTask(
//                                     task.label,
//                                     task.deadline,
//                                     task.description,
//                                     task.category,
//                                     task.repeatOption,
//                                   );
//                                   await _taskService.deleteTask(task.id);
//                                   Ensure only one SnackBar is displayed at a time
//                                   ScaffoldMessenger.of(context)
//                                       .hideCurrentSnackBar();
//                                   ScaffoldMessenger.of(context).showSnackBar(
//                                     SnackBar(
//                                       content: const Text("Task Completed"),
//                                       action: SnackBarAction(
//                                         label: "UNDO",
//                                         onPressed: () {
//                                           ScaffoldMessenger.of(context)
//                                               .hideCurrentSnackBar();
//                                           _taskService.addTask(
//                                             task.label,
//                                             task.deadline,
//                                             task.description,
//                                             task.category,
//                                             task.repeatOption,
//                                           );
//                                           _completedTaskService
//                                               .deleteCompTask(task.id);
//                                           setState(() {});
//                                         },
//                                         textColor: Colors.white,
//                                       ),
//                                       duration: const Duration(seconds: 2),
//                                       behavior: SnackBarBehavior.floating,
//                                     ),
//                                   );
//                                 }
//                                 setState(() {});
//                               },
//                             ),
//                           ),
//                         ],
//                       ),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceAround,
//                         children: [
//                           Functions.whenDue(task), // Display remaining time
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             );
//           }).toList(),
//         );
//       },
//     );
//   }

//   Widget _habitList() {
//     return FutureBuilder(
//       future: _habitService.getHabits(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData || snapshot.data!.isEmpty) {
//           return Center(child: Text("No habits yet"));
//         }

//         List<Widget> habitWidgets = snapshot.data!
//             .map<Widget>((habit) => GestureDetector(
//                   onHorizontalDragStart: (details) async {
//                     await _habitService.updateHabitStatus(
//                         habit.id, habit.status == 0 ? 1 : 0);
//                     setState(() {});
//                   },
//                   onVerticalDragEnd: (details) => setState(() {}),
//                   onLongPress: () async {
//                     await _habitService.deleteHabit(habit.id);
//                     setState(() {});
//                   },
//                   onTap: () {
//                     _labelController.text = habit.label;
//                     _descriptionController.text = habit.description;
//                     habitFormDialog(add: false, habit: habit);
//                   },
//                   child: Padding(
//                     padding: const EdgeInsets.all(8),
//                     child: Container(
//                       padding: EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         border: Border.all(color: Colors.grey.shade300),
//                         borderRadius: BorderRadius.circular(10),
//                         color: Colors.grey.shade100,
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                         children: [
//                           Flexible(
//                             child: Text(
//                               habit.label,
//                               style: TextStyle(
//                                 fontWeight: FontWeight.w600,
//                                 color: habit.status == 0
//                                     ? Color.fromARGB(255, 0, 0, 0)
//                                     : Colors.grey,
//                                 decoration: habit.status == 0
//                                     ? TextDecoration.none
//                                     : TextDecoration.lineThrough,
//                                 decorationThickness: 2,
//                                 decorationColor:
//                                     const Color.fromARGB(255, 255, 0, 0),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ))
//             .toList();

//         return Column(
//           children: habitWidgets,
//         );
//       },
//     );
//   }

//   Widget _goalList() {
//     return Container(
//       decoration: BoxDecoration(border: Border.all()),
//       child: FutureBuilder(
//         future: _goalService.getGoals(),
//         builder: (context, snapshot) {
//           if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return Center(child: Text("No goals yet"));
//           }

//           List<Goal> goals = snapshot.data!;

//           return Column(
//             children: goals.map((goal) {
//               DateTime deadline;

//               try {
//                 deadline = DateTime.parse(goal.deadline.trim());
//               } catch (e) {
//                 return Text("Raw deadline string: ${goal.deadline}");
//               }

//               return GestureDetector(
//                 onLongPress: () {
//                   _goalService.deleteGoal(goal.id);
//                   setState(() {});
//                 },
//                 onTap: () {
//                   _showAchievementDialog(context, goal);
//                 },
//                 child: Column(
//                   children: [
//                     Text(
//                       goal.label,
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 24,
//                       ),
//                     ),
//                     StreamBuilder(
//                       stream: Stream.periodic(Duration(seconds: 1), (_) {
//                         return deadline.difference(DateTime.now());
//                       }),
//                       builder: (context, snapshot) {
//                         if (!snapshot.hasData) return Text("Loading...");

//                         Duration remaining = snapshot.data!;
//                         if (remaining.isNegative) {
//                           return Text(
//                             "Deadline Passed!",
//                             style: TextStyle(color: Colors.red),
//                           );
//                         }

//                         int days = remaining.inDays;
//                         int hours = remaining.inHours % 24;
//                         int minutes = remaining.inMinutes % 60;
//                         int seconds = remaining.inSeconds % 60;

//                         return Text(
//                           "$days days, $hours h, $minutes m, $seconds s",
//                           style: TextStyle(color: Colors.grey),
//                         );
//                       },
//                     ),
//                     Divider(),
//                   ],
//                 ),
//               );
//             }).toList(),
//           );
//         },
//       ),
//     );
//   }

//   Widget _bookList() {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 50),
//       child: FutureBuilder<List<Book>>(
//         future: _bookServiceLib.getBooks(),
//         builder: (context, snapshot) {
//           if (snapshot.hasError) {
//             return Center(child: Text('Error: ${snapshot.error}'));
//           }

//           final books = snapshot.data;

//           if (books == null || books.isEmpty) {
//             return const Center(child: Text("No books yet"));
//           }

//           return Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 "Books Progress",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 10),
//               Column(
//                 children: books.map((book) {
//                   return GestureDetector(
//                     onTap: () => _showUpdateBookDialog(context, book),
//                     child: ListTile(
//                       title: Text(book.label),
//                       subtitle: Text(
//                           'Current Page:${book.currentPage} out of ${book.totalPages}'),
//                       trailing: SizedBox(
//                         width: 80,
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Text(
//                                 "${(book.progress * 100).toStringAsFixed(1)}%"),
//                             const SizedBox(height: 8),
//                             LinearProgressIndicator(
//                               value: book.progress,
//                               minHeight: 8,
//                               backgroundColor: Colors.grey.shade300,
//                               valueColor: const AlwaysStoppedAnimation<Color>(
//                                   Colors.blue),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   );
//                 }).toList(),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   Future<dynamic> _showAchievementDialog(BuildContext context, Goal goal) {
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text("Goal Achieved?"),
//         content: Text("Have you completed '${goal.label}' ?"),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context), // Close dialog
//             child: Text("Not Yet"),
//           ),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context); // Close first dialog
//               _showCongratulationsDialog(context, goal); // Show Congrats
//             },
//             child: Text("Yes!"),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<dynamic> _showCongratulationsDialog(BuildContext context, Goal goal) {
//     _goalService.deleteGoal(goal.id);
//     setState(() {});
//     List<String> quotes = [
//       "Success is not final, failure is not fatal: It is the courage to continue that counts. – Winston Churchill",
//       "The only limit to our realization of tomorrow is our doubts of today. – Franklin D. Roosevelt",
//       "Dream big and dare to fail. – Norman Vaughan",
//       "Believe you can, and you're halfway there. – Theodore Roosevelt",
//       "What you get by achieving your goals is not as important as what you become by achieving them. – Zig Ziglar",
//       "Don’t watch the clock; do what it does. Keep going. – Sam Levenson",
//       "Act as if what you do makes a difference. It does. – William James"
//     ];

//     String randomQuote =
//         quotes[Random().nextInt(quotes.length)]; // Pick a random quote

//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text("Congratulations!"),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//                 "You achieved your goal: '${goal.label}'! Keep up the great work!"),
//             SizedBox(height: 20),
//             Text(
//               randomQuote,
//               textAlign: TextAlign.center,
//               style: TextStyle(fontStyle: FontStyle.italic),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text("OK"),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<dynamic> _showUpdateBookDialog(BuildContext context, Book book) {
//     final TextEditingController _currentPageController =
//         TextEditingController(text: book.currentPage.toString());
//     final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

//     return showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//           title: Text(
//             book.label,
//             textAlign: TextAlign.center,
//             style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//           ),
//           content: Form(
//             key: _formKey,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 const SizedBox(height: 10),
//                 Text(
//                   "Update your progress",
//                   style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
//                   textAlign: TextAlign.center,
//                 ),
//                 const SizedBox(height: 20),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     SizedBox(
//                       width: 150,
//                       child: TextFormField(
//                         controller: _currentPageController,
//                         keyboardType: TextInputType.number,
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(fontSize: 18),
//                         inputFormatters: [
//                           FilteringTextInputFormatter.digitsOnly
//                         ],
//                         decoration: InputDecoration(
//                           hintText: "Enter page",
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           contentPadding:
//                               const EdgeInsets.symmetric(vertical: 10),
//                         ),
//                         validator: (value) {
//                           if (value == null || value.isEmpty) {
//                             return "Enter a valid page number";
//                           }
//                           final int? currentPage = int.tryParse(value);
//                           if (currentPage == null || currentPage <= 0) {
//                             return "Page must be greater than 0";
//                           }
//                           if (currentPage > book.totalPages) {
//                             return "Page cannot exceed ${book.totalPages}";
//                           }
//                           return null;
//                         },
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     Text(
//                       "/ ${book.totalPages}",
//                       style: const TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.blueAccent,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 OutlinedButton(
//                   onPressed: () => Navigator.pop(context),
//                   style: OutlinedButton.styleFrom(
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   child: const Text("Cancel"),
//                 ),
//                 ElevatedButton(
//                   onPressed: () async {
//                     if (_formKey.currentState!.validate()) {
//                       Future<bool> isDeleting =
//                           _bookServiceLib.updateBookCurrentPage(
//                               book.id, int.parse(_currentPageController.text));

//                       setState(() {});
//                       Navigator.pop(context);

//                       if (await isDeleting) {
//                         _showBookFinishedDialog(
//                           context,
//                           book,
//                         );
//                       }
//                     }
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blueAccent,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   child: const Text("Update",
//                       style: TextStyle(color: Colors.white)),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 10),
//           ],
//         );
//       },
//     );
//   }

//   Future<dynamic> _showBookFinishedDialog(BuildContext context, Book book) {
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text("Book Completed?"),
//         content: Text("Did you finish reading '${book.label}'?"),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _bookServiceLib.updateBookCurrentPage(book.id, book.currentPage);
//               setState(() {});
//             },
//             child: Text("Not Yet"),
//           ),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _bookServiceLib.deleteBook(book.id);
//               setState(() {});
//             },
//             child: Text("Yes!"),
//           ),
//         ],
//       ),
//     );
//   }

//   void requestNotificationPermission() async {
//     if (await Permission.notification.isDenied) {
//       await Permission.notification.request();
//     }
//   }

//   Future<void> _selectDateAndTime(
//       BuildContext context, StateSetter parentSetState) async {
//     DateTime? selectedDate;
//     TimeOfDay? selectedTime;
//     String repeatOption = selectedRepeatOption;

//     await showDialog(
//       context: context,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setDialogState) {
//             return AlertDialog(
//               title: const Text("Select Date, Time, and Repeat"),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Date Picker
//                   ListTile(
//                     leading: const Icon(Icons.calendar_today),
//                     title: Text(
//                       selectedDate != null
//                           ? "${selectedDate?.year}-${selectedDate?.month.toString().padLeft(2, '0')}-${selectedDate?.day.toString().padLeft(2, '0')}"
//                           : (_dateController.text.isNotEmpty
//                               ? _dateController.text
//                               : "Select Date"),
//                     ),
//                     onTap: () async {
//                       final DateTime? pickedDate = await showDatePicker(
//                         context: context,
//                         initialDate: DateTime.now(),
//                         firstDate: DateTime.now(),
//                         lastDate: DateTime(2100),
//                       );
//                       if (pickedDate != null) {
//                         setDialogState(() {
//                           selectedDate = pickedDate;
//                         });
//                       }
//                     },
//                   ),
//                   const SizedBox(height: 10),
//                   Time Picker
//                   ListTile(
//                     leading: const Icon(Icons.access_time),
//                     title: Text(
//                       selectedTime != null
//                           ? "${selectedTime?.hour.toString().padLeft(2, '0')}:${selectedTime?.minute.toString().padLeft(2, '0')}"
//                           : (_timeController.text.isNotEmpty
//                               ? _timeController.text
//                               : "Select Time"),
//                     ),
//                     onTap: () async {
//                       final TimeOfDay? pickedTime = await showTimePicker(
//                         context: context,
//                         initialTime: TimeOfDay.now(),
//                       );
//                       if (pickedTime != null) {
//                         setDialogState(() {
//                           selectedTime = pickedTime;
//                         });
//                       }
//                     },
//                   ),
//                   const SizedBox(height: 10),
//                   Repeat Options
//                   DropdownButtonFormField<String>(
//                     value: repeatOption != "None" ? repeatOption : null,
//                     decoration: const InputDecoration(
//                       labelText: "Repeat",
//                       border: OutlineInputBorder(),
//                     ),
//                     items: ["None", "Daily", "Weekly", "Monthly"]
//                         .map((option) => DropdownMenuItem(
//                               value: option,
//                               child: Text(option),
//                             ))
//                         .toList(),
//                     onChanged: (value) {
//                       setDialogState(() {
//                         repeatOption = value!;
//                       });
//                     },
//                   ),
//                 ],
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     setState(() {});
//                   },
//                   child: const Text("Cancel"),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     Update both the dialog state and parent state
//                     setDialogState(() {
//                       if (selectedDate != null) {
//                         _dateController.text =
//                             "${selectedDate?.year}-${selectedDate?.month.toString().padLeft(2, '0')}-${selectedDate?.day.toString().padLeft(2, '0')}";
//                       }
//                       if (selectedTime != null) {
//                         _timeController.text =
//                             "${selectedTime?.hour.toString().padLeft(2, '0')}:${selectedTime?.minute.toString().padLeft(2, '0')}";
//                       }
//                       selectedRepeatOption = repeatOption;
//                     });

//                     Update the parent widget's state
//                     parentSetState(() {});

//                     Update the main widget's state
//                     setState(() {});

//                     Navigator.pop(context);
//                   },
//                   child: const Text("Save"),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   void _showCategoryDialog(BuildContext context, StateSetter parentSetState) {
//     final TextEditingController _newCategoryController =
//         TextEditingController();
//     final CategoryService _categoryService = CategoryService();

//     showDialog(
//       context: context,
//       builder: (context) {
//         return FutureBuilder<List<String>>(
//           future: _categoryService.getCategories(),
//           builder: (context, snapshot) {
//             if (!snapshot.hasData) {
//               return const Center(child: CircularProgressIndicator());
//             }

//             final categories = snapshot.data!;

//             return AlertDialog(
//               title: const Text("Select or Create Category"),
//               content: Container(
//                 width: double.maxFinite,
//                 constraints: BoxConstraints(
//                   maxHeight: MediaQuery.of(context).size.height * 0.5,
//                 ),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Flexible(
//                       child: SingleChildScrollView(
//                         child: Column(
//                           children: categories.map((category) {
//                             return ListTile(
//                               title: Text(category),
//                               selected: selectedCategory == category,
//                               onTap: () {
//                                 setState(() {
//                                   selectedCategory = category;
//                                 });
//                                 parentSetState(() {
//                                   selectedCategory = category;
//                                 });
//                                 Navigator.pop(context);
//                               },
//                               onLongPress: () {
//                                 if (category == "Default") {
//                                   ScaffoldMessenger.of(context).showSnackBar(
//                                     const SnackBar(
//                                         content: Text(
//                                             "Cannot delete Default category")),
//                                   );
//                                   return;
//                                 }

//                                 Show delete confirmation dialog
//                                 showDialog(
//                                   context: context,
//                                   builder: (context) => AlertDialog(
//                                     title: const Text("Delete Category"),
//                                     content: Text(
//                                         "Are you sure you want to delete '$category'?\n\nAll tasks in this category will be moved to Default."),
//                                     actions: [
//                                       TextButton(
//                                         onPressed: () => Navigator.pop(context),
//                                         child: const Text("Cancel"),
//                                       ),
//                                       TextButton(
//                                         onPressed: () async {
//                                           try {
//                                             await _categoryService
//                                                 .deleteCategory(category);
//                                             if (selectedCategory == category) {
//                                               setState(() {
//                                                 selectedCategory = "Default";
//                                               });
//                                               parentSetState(() {
//                                                 selectedCategory = "Default";
//                                               });
//                                             }
//                                             Navigator.pop(
//                                                 context); // Close confirmation dialog
//                                             Navigator.pop(
//                                                 context); // Close category dialog
//                                             Show the category dialog again with updated list
//                                             _showCategoryDialog(
//                                                 context, parentSetState);
//                                           } catch (e) {
//                                             ScaffoldMessenger.of(context)
//                                                 .showSnackBar(
//                                               SnackBar(
//                                                   content: Text(
//                                                       'Failed to delete category: $e')),
//                                             );
//                                             Navigator.pop(context);
//                                           }
//                                         },
//                                         child: const Text("Delete",
//                                             style:
//                                                 TextStyle(color: Colors.red)),
//                                       ),
//                                     ],
//                                   ),
//                                 );
//                               },
//                             );
//                           }).toList(),
//                         ),
//                       ),
//                     ),
//                     const Divider(),
//                     TextField(
//                       controller: _newCategoryController,
//                       decoration: const InputDecoration(
//                         hintText: "New category",
//                         prefixIcon: Icon(Icons.add),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: const Text("Cancel"),
//                 ),
//                 ElevatedButton(
//                   onPressed: () async {
//                     if (_newCategoryController.text.isNotEmpty) {
//                       await _categoryService
//                           .addCategory(_newCategoryController.text);
//                       setState(() {
//                         selectedCategory = _newCategoryController.text;
//                       });
//                       parentSetState(() {
//                         selectedCategory = _newCategoryController.text;
//                       });
//                       Navigator.pop(context);
//                     }
//                   },
//                   child: const Text("Create"),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }
// }
