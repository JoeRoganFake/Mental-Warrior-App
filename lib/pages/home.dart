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
  TextEditingController _dataController = TextEditingController();

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
                                Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Text(
                                      "New Task",
                                    ),
                                    TextField(
                                      autofocus: true,
                                      decoration: InputDecoration(
                                        labelText: "Label",
                                      ),
                                    ),
                                    TextField(
                                      maxLines: null,
                                      keyboardType: TextInputType.multiline,
                                      decoration: InputDecoration(
                                        labelText: "Description",
                                      ),
                                    ),
                                    TextField(
                                      controller: _dataController,
                                      onTap: () {
                                        // Call the static method from Functions class
                                        Functions.datePicker(
                                            context, _dataController);
                                      },
                                      readOnly: true,
                                      decoration: InputDecoration(
                                        labelText: "Due To",
                                        prefixIcon:
                                            const Icon(Icons.calendar_month),
                                      ),
                                    )
                                  ],
                                )
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
