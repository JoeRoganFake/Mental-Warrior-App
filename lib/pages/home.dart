import 'package:flutter/material.dart';
import 'package:mental_warior/utils/functions.dart'; // Import your Functions class
import 'package:mental_warior/models/tasks.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var function = Functions(); // Create an instance of Functions
  List<TasksModel> tasks = [];
  final _dateController = TextEditingController();
  final _labelController = TextEditingController();
  final _descriptionController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _getInitInfo();
  }

  void _getInitInfo() {
    tasks = TasksModel.getTasks();
  }

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
              Stack(
                children: [
                  Container(
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
                            Text(tasks[index].name),
                            Checkbox(
                              value: tasks[index].isCompleted,
                              onChanged: (bool? value) {
                                setState(() {
                                  tasks[index].isCompleted = value ?? false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      separatorBuilder: (context, index) => const SizedBox(
                        width: 25,
                        height: 5,
                      ),
                      itemCount: tasks.length,
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: FloatingActionButton(
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
                                              prefixIcon:
                                                  const Icon(Icons.label),
                                              border: InputBorder.none),
                                        ),
                                        TextFormField(
                                          controller: _descriptionController,
                                          maxLines: null,
                                          validator: (value) {
                                            if (value!.isEmpty) {
                                              return "* Field Is Required";
                                            }
                                            return null;
                                          },
                                          keyboardType: TextInputType.multiline,
                                          decoration: InputDecoration(
                                              hintText: "Description",
                                              prefixIcon:
                                                  const Icon(Icons.description),
                                              border: InputBorder.none),
                                        ),
                                        TextFormField(
                                          validator: (value) {
                                            if (value!.isEmpty) {
                                              return "* Field Is Required";
                                            }
                                            return null;
                                          },
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
                                            _formKey.currentState!.validate();
                                            print(_labelController.text);
                                            print(_descriptionController.text);
                                            print(_dateController.text);
                                            _dateController.clear();
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
                        backgroundColor:
                            const Color.fromARGB(255, 103, 113, 121),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                        ),
                      ),
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
}
