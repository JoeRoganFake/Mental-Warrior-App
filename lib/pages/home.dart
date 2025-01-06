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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        children: [
          Text(
            "Good ${function.getTimeOfDayDescription()}.",
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
              Column(
                children: [
                  _taskList(),
                  FloatingActionButton(
                    splashColor: Colors.blue,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => SimpleDialog(
                          children: [
                            Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Text(
                                      "New Task",
                                    ),
                                    TextFormField(
                                      controller: _labelController,
                                      autofocus: true,
                                      validator: (value) {
                                        if (value!.isEmpty) {
                                          return "* Field Is Required";
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
                                          prefixIcon:
                                              const Icon(Icons.calendar_month),
                                          border: InputBorder.none),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        _formKey.currentState!.validate();
                                        _databaseService.addTask(
                                            _labelController.text,
                                            _dateController.text,
                                            _descriptionController.text);
                                        _dateController.clear();
                                        _labelController.clear();
                                        _descriptionController.clear();
                                        Navigator.pop(context);
                                        setState(() {});
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.create_outlined),
                                          Text(
                                            textAlign: TextAlign.center,
                                            "Add Task",
                                            style: TextStyle(),
                                          )
                                        ],
                                      ),
                                    )
                                  ],
                                ))
                          ],
                        ),
                      );
                    },
                    backgroundColor: const Color.fromARGB(255, 103, 113, 121),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Container _taskListOr() {
    return Container(
      color: Colors.lightBlueAccent,
      height: 105,
      width: 300,
      child: ListView.separated(
          scrollDirection: Axis.vertical,
          itemBuilder: (context, index) => Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color.fromARGB(255, 119, 119, 119),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text("DUMMY"),
                    Checkbox(value: true, onChanged: null),
                  ],
                ),
              ),
          separatorBuilder: (context, index) => const SizedBox(
                width: 25,
                height: 5,
              ),
          itemCount: 5),
    );
  }

  Widget _taskList() {
    return Container(
      color: const Color.fromARGB(255, 250, 250, 250),
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
                  padding: const EdgeInsets.all(8.0),
                  child: GestureDetector(
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
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text(
                            task.label,
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                          Checkbox(
                            value: task.status == 1,
                            onChanged: (value) {
                              _databaseService.updateTaskStatus(
                                  task.id, value == true ? 1 : 0);
                              setState(() {});
                            },
                          ),
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
