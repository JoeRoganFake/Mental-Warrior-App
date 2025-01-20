import 'package:flutter/material.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/utils/functions.dart';
import 'package:mental_warior/models/tasks.dart';

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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final DatabaseService _databaseService = DatabaseService.instace;
  bool _compTaskVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        splashColor: Colors.blue,
        onPressed: () {
          showMenu(
            context: context,
            position: RelativeRect.fromLTRB(
              MediaQuery.of(context).size.width - 5,
              MediaQuery.of(context).size.height - 200,
              20,
              0,
            ),
            items: [
              PopupMenuItem<String>(
                value: 'task',
                child: Text('Task'),
                onTap: () => addTaskDialog(context),
              ),
              PopupMenuItem<String>(
                value: 'habit',
                child: Text('Habit'),
              ),
            ],
          );
        },
        backgroundColor: const Color.fromARGB(255, 103, 113, 121),
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.white,
      body: ListView(
        children: [
          Text(
            "Good Productive ${function.getTimeOfDayDescription()}.",
          ),
          const SizedBox(
            width: 25,
            height: 25,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Tasks Today",
                textAlign: TextAlign.start,
              ),
              const SizedBox(
                height: 10,
              ),
              _taskList(),
              Container(
                decoration: BoxDecoration(border: Border.all()),
                height: 300,
                width: 200,
                child: FutureBuilder(
                    future: _databaseService.getCompletedTasks(),
                    builder: (context, snapshot) {
                      return ListView.builder(
                        scrollDirection: Axis.vertical,
                        itemCount: snapshot.data?.length ?? 0,
                        itemBuilder: (context, index) {
                          Task task = snapshot.data![index];
                          return Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: GestureDetector(
                              onTap: () {
                                _labelController.text = task.label;
                                _descriptionController.text = task.description;
                                _dateController.text = task.deadline;
                                showDialog(
                                  context: context,
                                  builder: (context) => SimpleDialog(
                                    children: [
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Form(
                                            key: _formKey,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  child: Text(
                                                    "Edit Task",
                                                  ),
                                                ),
                                                TextFormField(
                                                  controller: _labelController,
                                                  validator: (value) {
                                                    if (value!.isEmpty ||
                                                        value == "") {
                                                      return "     *Field Is Required";
                                                    }
                                                    return null;
                                                  },
                                                  decoration: InputDecoration(
                                                      hintText: "Label",
                                                      prefixIcon: const Icon(
                                                          Icons.label),
                                                      border: InputBorder.none),
                                                ),
                                                TextFormField(
                                                  controller:
                                                      _descriptionController,
                                                  maxLines: null,
                                                  keyboardType:
                                                      TextInputType.multiline,
                                                  decoration: InputDecoration(
                                                      hintText: "Description",
                                                      prefixIcon: const Icon(
                                                          Icons.description),
                                                      border: InputBorder.none),
                                                ),
                                                TextFormField(
                                                  controller: _dateController,
                                                  onTap: () {
                                                    Functions.dateAndTimePicker(
                                                        context,
                                                        _dateController);
                                                  },
                                                  readOnly: true,
                                                  decoration: InputDecoration(
                                                      hintText: "Due To",
                                                      prefixIcon: const Icon(
                                                          Icons.calendar_month),
                                                      border: InputBorder.none),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    if (_formKey.currentState!
                                                        .validate()) {
                                                      _databaseService
                                                          .updateTask(
                                                              task.id,
                                                              "label",
                                                              _labelController
                                                                  .text);
                                                      _databaseService.updateTask(
                                                          task.id,
                                                          "description",
                                                          _descriptionController
                                                              .text);
                                                      _databaseService
                                                          .updateTask(
                                                              task.id,
                                                              "deadline",
                                                              _dateController
                                                                  .text);

                                                      Navigator.pop(context);
                                                      setState(() {});
                                                    }
                                                  },
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child: const Icon(Icons
                                                            .add_task_outlined),
                                                      ),
                                                      Text(
                                                        textAlign:
                                                            TextAlign.center,
                                                        "Edit Task",
                                                        style: TextStyle(),
                                                      )
                                                    ],
                                                  ),
                                                )
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ).then((_) {
                                  Future.delayed(
                                      const Duration(milliseconds: 100), () {
                                    _labelController.clear();
                                    _descriptionController.clear();
                                    _dateController.clear();
                                  });
                                });
                              },
                              onLongPress: () {
                                _databaseService.deleteTask(task.id);
                                setState(() {});
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color:
                                      const Color.fromARGB(255, 119, 119, 119),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(left: 30),
                                        child: Text(
                                          task.label,
                                          style: TextStyle(
                                            color: Colors.white,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(right: 30),
                                      child: Checkbox(
                                        value: task.status == 1,
                                        onChanged: (value) {
                                          _databaseService.updateTaskStatus(
                                              task.id, value == true ? 1 : 0);

                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
              )
            ],
          ),
        ],
      ),
    );
  }

  Future<dynamic> addTaskDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        children: [
          Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "New Task",
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
                TextFormField(
                  controller: _dateController,
                  onTap: () {
                    Functions.dateAndTimePicker(context, _dateController);
                  },
                  readOnly: true,
                  decoration: InputDecoration(
                      hintText: "Due To",
                      prefixIcon: const Icon(Icons.calendar_month),
                      border: InputBorder.none),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _databaseService.addTask(
                        _labelController.text,
                        _dateController.text,
                        _descriptionController.text,
                      );
                      Navigator.pop(context);
                      setState(() {});
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
                        textAlign: TextAlign.center,
                        "Add Task",
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
        _dateController.clear();
      });
    });
  }

  Widget _taskList() {
    return Container(
      decoration: BoxDecoration(border: Border.all()),
      height: 300,
      width: 200,
      child: FutureBuilder(
          future: _databaseService.getTasks(),
          builder: (context, snapshot) {
            return ListView.builder(
              scrollDirection: Axis.vertical,
              itemCount: snapshot.data?.length ?? 0,
              itemBuilder: (context, index) {
                Task task = snapshot.data![index];
                return Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: GestureDetector(
                    onTap: () {
                      _labelController.text = task.label;
                      _descriptionController.text = task.description;
                      _dateController.text = task.deadline;
                      showDialog(
                        context: context,
                        builder: (context) => SimpleDialog(
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Edit Task",
                                        ),
                                      ),
                                      TextFormField(
                                        controller: _labelController,
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
                                            prefixIcon:
                                                const Icon(Icons.description),
                                            border: InputBorder.none),
                                      ),
                                      TextFormField(
                                        controller: _dateController,
                                        onTap: () {
                                          Functions.dateAndTimePicker(
                                              context, _dateController);
                                        },
                                        readOnly: true,
                                        decoration: InputDecoration(
                                            hintText: "Due To",
                                            prefixIcon: const Icon(
                                                Icons.calendar_month),
                                            border: InputBorder.none),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          if (_formKey.currentState!
                                              .validate()) {
                                            _databaseService.updateTask(task.id,
                                                "label", _labelController.text);
                                            _databaseService.updateTask(
                                                task.id,
                                                "description",
                                                _descriptionController.text);
                                            _databaseService.updateTask(
                                                task.id,
                                                "deadline",
                                                _dateController.text);

                                            Navigator.pop(context);
                                            setState(() {});
                                          }
                                        },
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: const Icon(
                                                  Icons.add_task_outlined),
                                            ),
                                            Text(
                                              textAlign: TextAlign.center,
                                              "Edit Task",
                                              style: TextStyle(),
                                            )
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ).then((_) {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          _labelController.clear();
                          _descriptionController.clear();
                          _dateController.clear();
                        });
                      });
                    },
                    onLongPress: () {
                      _databaseService.deleteTask(task.id);
                      setState(() {});
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: const Color.fromARGB(255, 119, 119, 119),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 30),
                              child: Text(
                                task.label,
                                style: TextStyle(
                                  color: Colors.white,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 30),
                            child: Checkbox(
                              value: task.status == 1,
                              onChanged: (value) async {
                                setState(() {
                                  _databaseService.updateTaskStatus(
                                      task.id, value == true ? 1 : 0);
                                });

                                await Future.delayed(
                                    const Duration(milliseconds: 250));

                                if (value == true) {
                                  await _databaseService.addCompletedTask(task);
                                  await _databaseService.deleteTask(task.id);
                                }
                                setState(() {});
                              },
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),
    );
  }
}
