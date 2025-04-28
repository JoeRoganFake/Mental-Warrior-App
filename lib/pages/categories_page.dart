import 'package:flutter/material.dart';
import 'package:mental_warior/models/tasks.dart';
import 'package:mental_warior/models/categories.dart';
import 'package:mental_warior/pages/home.dart';
import 'package:mental_warior/services/database_services.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage>
    with TickerProviderStateMixin {
  final TaskService _taskService = TaskService();
  final CategoryService _categoryService = CategoryService();
  TabController? _tabController;
  List<Category> _categories = [];
  bool _isLoading = true;

  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  bool _showDescription = false;
  bool _showDateTime = false;

  // Add new fields for repeat functionality
  bool _showRepeat = false;
  String _repeatFrequency = 'day';
  int _repeatInterval = 1;
  String _repeatEndType = 'never';
  final TextEditingController _repeatEndDateController =
      TextEditingController();
  final TextEditingController _repeatOccurrencesController =
      TextEditingController();

  // Add this field to track the currently selected category
  Category? _currentCategory;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;

    try {
      // Don't set loading state immediately - avoids flickering UI
      final categories = await _categoryService.getCategories();

      if (!mounted) return;

      // Only update the UI if categories actually changed
      if (_categories.length != categories.length ||
          !_categories.every((cat) => categories.any((c) => c.id == cat.id))) {
        // Save current index if possible
        int currentIndex = _tabController?.index ?? 0;
        if (currentIndex >= categories.length) {
          currentIndex = categories.isEmpty ? 0 : categories.length - 1;
        }

        // Dispose old controller properly
        _tabController?.dispose();

        final newController = TabController(
          length: categories.length,
          vsync: this,
          initialIndex: currentIndex,
        );

        // Add this listener to keep track of the current category
        newController.addListener(() {
          if (!newController.indexIsChanging &&
              mounted &&
              _categories.isNotEmpty) {
            setState(() {
              _currentCategory = _categories[newController.index];
            });
          }
        });

        setState(() {
          _categories = categories;
          _tabController = newController;
          // Set initial category based on current index
          _currentCategory =
              categories.isNotEmpty ? categories[currentIndex] : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _categories = [];
        });
      }
      print('Error loading categories: $e');
    }
  }

  Future<void> _deleteCategory(Category category) async {
    if (category.isDefault == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete default category'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "${category.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _categoryService.deleteCategory(category.id);
      // Reload categories and update TabController
      await _loadCategories();
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_categories.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Padding(
            padding: EdgeInsets.only(top: 16.0),
            child: Text(
              "Categories",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          toolbarHeight: 80,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.category_outlined,
                size: 80,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              const Text(
                "No categories found",
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Refresh"),
                onPressed: _loadCategories,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevent keyboard from pushing widgets
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Check if _currentCategory is null, use the first category if it is
          Category categoryToUse = _currentCategory ?? _categories.first;
          _showAddTaskDialog(context, categoryToUse);
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 50.0),
          child: Row(
            children: [
              const Text(
                "Tasks",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Add Category button moved to title row for better visibility
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _showAddCategoryDialog(context),
                tooltip: 'Add Category',
              ),
            ],
          ),
        ),
        toolbarHeight: 80,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
          indicatorColor: Colors.blue,
          indicatorWeight: 3,
          tabs: _categories.map((category) {
            return GestureDetector(
              onLongPress: () async {
                await _deleteCategory(category);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                constraints: const BoxConstraints(minWidth: 100),
                child: Text(
                  category.label,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }).toList(),
        ),
      ),
      body: NotificationListener<OverscrollIndicatorNotification>(
        // Prevent the glow effect on overscroll to make refresh more obvious
        onNotification: (OverscrollIndicatorNotification notification) {
          notification.disallowIndicator();
          return true;
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: TabBarView(
            controller: _tabController,
            // Make tab swiping require very deliberate gesture with high resistance
            physics: const PageScrollPhysics().applyTo(
              const ClampingScrollPhysics().applyTo(
                ScrollPhysics(parent: const ClampingScrollPhysics()),
              ),
            ),
            children: [
              ..._categories
                  .map((category) => CategoryTasksView(category: category)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddTaskDialog(
      BuildContext context, Category category) async {
    _labelController.clear();
    _descriptionController.clear();
    _dateController.clear();
    _showDescription = false;
    _showDateTime = false;

    // Reset repeat functionality variables
    _showRepeat = false;
    _repeatFrequency = 'day';
    _repeatInterval = 1;
    _repeatEndType = 'never';
    _repeatEndDateController.clear();
    _repeatOccurrencesController.text = '30';

    final GlobalKey<FormState> taskFormKey = GlobalKey<FormState>();

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      useSafeArea: true,
      isDismissible: true,
      enableDrag: false, // Disable dragging
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Form(
                key: taskFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "New Task",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: TextFormField(
                        controller: _labelController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        validator: (value) =>
                            value?.isEmpty ?? true ? "Required" : null,
                        decoration: InputDecoration(
                          hintText: "Task name",
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon:
                              const Icon(Icons.task, color: Colors.white),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                        ),
                      ),
                    ),
                    if (!_showDescription)
                      TextButton.icon(
                        icon: Icon(Icons.add, color: Colors.grey[400]),
                        label: Text("Add Description",
                            style: TextStyle(color: Colors.grey[400])),
                        onPressed: () {
                          modalSetState(() {
                            _showDescription = true;
                          });
                        },
                      ),
                    if (_showDescription)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _descriptionController,
                                style: const TextStyle(color: Colors.white),
                                maxLines: 3,
                                minLines: 1,
                                decoration: InputDecoration(
                                  hintText: "Description",
                                  hintStyle: TextStyle(color: Colors.grey[400]),
                                  prefixIcon: const Icon(Icons.description,
                                      color: Colors.white),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                    borderSide:
                                        BorderSide(color: Colors.grey[700]!),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.remove_circle,
                                  color: Colors.grey[400]),
                              onPressed: () {
                                modalSetState(() {
                                  _showDescription = false;
                                  _descriptionController.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    if (!_showDateTime)
                      TextButton.icon(
                        icon: Icon(Icons.add, color: Colors.grey[400]),
                        label: Text("Add Due Date",
                            style: TextStyle(color: Colors.grey[400])),
                        onPressed: () {
                          modalSetState(() {
                            _showDateTime = true;
                          });
                        },
                      ),
                    if (_showDateTime)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _dateController,
                                style: const TextStyle(color: Colors.white),
                                readOnly: true,
                                onTap: () async {
                                  DateTime? date = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime(2100),
                                  );

                                  if (date != null) {
                                    TimeOfDay? time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );

                                    if (time != null) {
                                      modalSetState(() {
                                        _dateController.text =
                                            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} "
                                            "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                                      });
                                    }
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: "Due Date",
                                  hintStyle: TextStyle(color: Colors.grey[400]),
                                  prefixIcon: const Icon(Icons.calendar_today,
                                      color: Colors.white),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                    borderSide:
                                        BorderSide(color: Colors.grey[700]!),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.remove_circle,
                                  color: Colors.grey[400]),
                              onPressed: () {
                                modalSetState(() {
                                  _showDateTime = false;
                                  _dateController.clear();
                                  // Reset repeat options if date is removed
                                  _showRepeat = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                    // Add Repeat button (only shows if a date is selected and has a valid time)
                    if (_showDateTime &&
                        _dateController.text.isNotEmpty &&
                        _dateController.text.contains(":"))
                      TextButton.icon(
                        icon: Icon(Icons.repeat, color: Colors.grey[400]),
                        label: Text(
                          _showRepeat
                              ? "Repeats every $_repeatInterval ${_repeatFrequency}${_repeatInterval > 1 ? 's' : ''}"
                              : "Add Repeat",
                          style: TextStyle(
                              color:
                                  _showRepeat ? Colors.blue : Colors.grey[400]),
                        ),
                        onPressed: () {
                          _showRepeatOptionsDialog(context, modalSetState);
                        },
                        // Add trailing remove button to discard repeat options
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.only(left: 12, right: 0),
                        ),
                      ),

                    // Show remove button for repeat options when active
                    if (_showRepeat)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red[300],
                                size: 18,
                              ),
                              label: Text(
                                "Remove Repeat",
                                style: TextStyle(color: Colors.red[300]),
                              ),
                              onPressed: () {
                                modalSetState(() {
                                  // Clear all repeat-related fields
                                  _showRepeat = false;
                                  _repeatFrequency = 'day';
                                  _repeatInterval = 1;
                                  _repeatEndType = 'never';
                                  _repeatEndDateController.clear();
                                  _repeatOccurrencesController.text = '30';
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: () async {
                          if (taskFormKey.currentState!.validate()) {
                            // Get the CURRENT category at the moment the user presses "Add Task"
                            final currentIndex = _tabController!.index;
                            final currentCategory = _categories[currentIndex];

                            await _taskService.addTask(
                              _labelController.text,
                              _dateController.text,
                              _descriptionController.text,
                              currentCategory.label,
                              // Add repeat functionality parameters
                              repeatFrequency:
                                  _showRepeat ? _repeatFrequency : null,
                              repeatInterval:
                                  _showRepeat ? _repeatInterval : null,
                              repeatEndType:
                                  _showRepeat ? _repeatEndType : null,
                              repeatEndDate:
                                  _showRepeat && _repeatEndType == 'on'
                                      ? _repeatEndDateController.text
                                      : null,
                              repeatOccurrences:
                                  _showRepeat && _repeatEndType == 'after'
                                      ? int.tryParse(
                                          _repeatOccurrencesController.text)
                                      : null,
                            );

                            Navigator.pop(context);
                            // The CategoryTasksView will update automatically via the listener
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text("Add Task"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Method to show the repeat options dialog
  Future<void> _showRepeatOptionsDialog(
      BuildContext context, StateSetter parentSetState) async {
    // Make a copy of the current values to restore if user cancels
    final String oldFrequency = _repeatFrequency;
    final int oldInterval = _repeatInterval;
    final String oldEndType = _repeatEndType;
    final String oldEndDate = _repeatEndDateController.text;
    final String oldOccurrences = _repeatOccurrencesController.text;

    // Always ensure the end date is set to a reasonable value if not already set
    if (_repeatEndType == 'on' &&
        _repeatEndDateController.text.isEmpty &&
        _dateController.text.isNotEmpty) {
      try {
        final datePart = _dateController.text.split(" ")[0];
        final parts = datePart.split("-");
        final startDate = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final endDate = startDate.add(Duration(days: 30));
        _repeatEndDateController.text =
            "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
      } catch (e) {
        print("Error setting default end date: $e");
      }
    }

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        // This refreshes the dialog with the latest date/time values from the modal bottom sheet
        String timeValue = _dateController.text.isNotEmpty &&
                _dateController.text.contains(":")
            ? _dateController.text.split(" ")[1]
            : "12:00";

        String dateValue = _dateController.text.isNotEmpty &&
                _dateController.text.contains(" ")
            ? _dateController.text.split(" ")[0].replaceAll('-', '/')
            : DateTime.now().toString().split(" ")[0].replaceAll('-', '/');

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Repeats every',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          // Interval input
                          SizedBox(
                            width: 50,
                            child: TextFormField(
                              initialValue: _repeatInterval.toString(),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8.0, horizontal: 8.0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey[700]!),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _repeatInterval = int.tryParse(value) ?? 1;
                                  if (_repeatInterval < 1) _repeatInterval = 1;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Frequency dropdown
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.0),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[700]!),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: DropdownButton<String>(
                                value: _repeatFrequency,
                                isExpanded: true,
                                dropdownColor: Colors.grey[800],
                                style: const TextStyle(color: Colors.white),
                                icon: Icon(Icons.arrow_drop_down,
                                    color: Colors.white),
                                underline: Container(),
                                items: [
                                  DropdownMenuItem(
                                      value: 'day', child: Text('day')),
                                  DropdownMenuItem(
                                      value: 'week', child: Text('week')),
                                  DropdownMenuItem(
                                      value: 'month', child: Text('month')),
                                  DropdownMenuItem(
                                      value: 'year', child: Text('year')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _repeatFrequency = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Set time field - Show time from date selection and allow editing
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: TextFormField(
                        initialValue: timeValue, // Use the refreshed time value
                        readOnly: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Set time",
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          prefixIcon:
                              Icon(Icons.access_time, color: Colors.white),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                        ),
                        onTap: () async {
                          // Get current time from date string or use current time as fallback
                          TimeOfDay initialTime;
                          if (_dateController.text.isNotEmpty &&
                              _dateController.text.contains(":")) {
                            final timePart = _dateController.text.split(" ")[1];
                            final parts = timePart.split(":");
                            initialTime = TimeOfDay(
                              hour: int.parse(parts[0]),
                              minute: int.parse(parts[1]),
                            );
                          } else {
                            initialTime = TimeOfDay.now();
                          }

                          // Show time picker
                          final TimeOfDay? selectedTime = await showTimePicker(
                            context: context,
                            initialTime: initialTime,
                          );

                          if (selectedTime != null) {
                            // Parse existing date from the date controller
                            String currentDateStr = "";
                            if (_dateController.text.isNotEmpty &&
                                _dateController.text.contains(" ")) {
                              currentDateStr =
                                  _dateController.text.split(" ")[0];
                            } else {
                              // If no date, use today's date
                              final now = DateTime.now();
                              currentDateStr =
                                  "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                            }

                            // Update the date controller with new time
                            String newTimeStr =
                                "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}";

                            // Update both the original date controller and the current display
                            parentSetState(() {
                              _dateController.text =
                                  "$currentDateStr $newTimeStr";
                            });

                            // Force dialog to rebuild with new values
                            Navigator.of(context).pop();
                            _showRepeatOptionsDialog(context, parentSetState);
                          }
                        },
                      ),
                    ),
                    // Starts field - Make it editable
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
                      child: Text(
                        'Starts',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextFormField(
                        initialValue: dateValue, // Use the refreshed date value
                        readOnly: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon:
                              Icon(Icons.calendar_today, color: Colors.white),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                        ),
                        onTap: () async {
                          // Get current date from date string or use current date + 30 days as fallback
                          DateTime initialDate;
                          if (_dateController.text.isNotEmpty) {
                            final datePart = _dateController.text.split(" ")[0];
                            final parts = datePart.split("-");
                            initialDate = DateTime(
                              int.parse(parts[0]),
                              int.parse(parts[1]),
                              int.parse(parts[2]),
                            );
                          } else {
                            initialDate = DateTime.now();
                          }

                          // Show date picker
                          final DateTime? selectedDate = await showDatePicker(
                            context: context,
                            initialDate: initialDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );

                          if (selectedDate != null) {
                            // Get current time from date string or use current time as fallback
                            TimeOfDay initialTime;
                            if (_dateController.text.isNotEmpty &&
                                _dateController.text.contains(":")) {
                              final timePart =
                                  _dateController.text.split(" ")[1];
                              final parts = timePart.split(":");
                              initialTime = TimeOfDay(
                                hour: int.parse(parts[0]),
                                minute: int.parse(parts[1]),
                              );
                            } else {
                              initialTime = TimeOfDay.now();
                            }

                            // Format the new date string
                            String newDateStr =
                                "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
                            String newTimeStr =
                                "${initialTime.hour.toString().padLeft(2, '0')}:${initialTime.minute.toString().padLeft(2, '0')}";

                            // Update both the original date controller and the current display
                            parentSetState(() {
                              _dateController.text = "$newDateStr $newTimeStr";
                            });

                            // Force dialog to rebuild with new values
                            Navigator.of(context).pop();
                            _showRepeatOptionsDialog(context, parentSetState);
                          }
                        },
                      ),
                    ),
                    // Ends section
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
                      child: Text(
                        'Ends',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),

                    // Never radio option
                    RadioListTile<String>(
                        title: Text('Never',
                            style: TextStyle(color: Colors.white)),
                        value: 'never',
                        groupValue: _repeatEndType,
                        activeColor: Colors.blue,
                        onChanged: (value) {
                          setState(() {
                            _repeatEndType = value!;
                          });
                        }),

                    // On specific date radio option
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'on',
                            groupValue: _repeatEndType,
                            activeColor: Colors.blue,
                            onChanged: (value) {
                              setState(() {
                                _repeatEndType = value!;

                                // Auto-set reasonable end date if not set
                                if (_repeatEndDateController.text.isEmpty &&
                                    _dateController.text.isNotEmpty) {
                                  try {
                                    final datePart =
                                        _dateController.text.split(" ")[0];
                                    final parts = datePart.split("-");
                                    final startDate = DateTime(
                                      int.parse(parts[0]),
                                      int.parse(parts[1]),
                                      int.parse(parts[2]),
                                    );
                                    final endDate =
                                        startDate.add(Duration(days: 30));
                                    _repeatEndDateController.text =
                                        "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
                                  } catch (e) {
                                    print("Error setting default end date: $e");
                                  }
                                }
                              });
                            },
                          ),
                          Text('On', style: TextStyle(color: Colors.white)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _repeatEndDateController,
                              readOnly: true,
                              enabled: _repeatEndType == 'on',
                              style: TextStyle(
                                color: _repeatEndType == 'on'
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                              decoration: InputDecoration(
                                hintText: "End date",
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey[700]!),
                                ),
                              ),
                              onTap: () async {
                                if (_repeatEndType == 'on') {
                                  // Get current date from date string or use current date + 30 days as fallback
                                  DateTime initialDate;
                                  if (_dateController.text.isNotEmpty) {
                                    final datePart =
                                        _dateController.text.split(" ")[0];
                                    final parts = datePart.split("-");
                                    initialDate = DateTime(
                                      int.parse(parts[0]),
                                      int.parse(parts[1]),
                                      int.parse(parts[2]),
                                    ).add(Duration(
                                        days: 30)); // Default to 30 days ahead
                                  } else {
                                    initialDate =
                                        DateTime.now().add(Duration(days: 30));
                                  }

                                  DateTime? date = await showDatePicker(
                                    context: context,
                                    initialDate: initialDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime(2100),
                                  );

                                  if (date != null) {
                                    setState(() {
                                      // Format the end date properly
                                      _repeatEndDateController.text =
                                          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                                    });
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // After X occurrences radio option
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'after',
                            groupValue: _repeatEndType,
                            activeColor: Colors.blue,
                            onChanged: (value) {
                              setState(() {
                                _repeatEndType = value!;
                                if (_repeatOccurrencesController.text.isEmpty) {
                                  _repeatOccurrencesController.text = '30';
                                }
                              });
                            },
                          ),
                          Text('After', style: TextStyle(color: Colors.white)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              controller: _repeatOccurrencesController,
                              enabled: _repeatEndType == 'after',
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _repeatEndType == 'after'
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8.0, horizontal: 8.0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey[700]!),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('occurrences',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),

                    // Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              // Restore previous values
                              _repeatFrequency = oldFrequency;
                              _repeatInterval = oldInterval;
                              _repeatEndType = oldEndType;
                              _repeatEndDateController.text = oldEndDate;
                              _repeatOccurrencesController.text =
                                  oldOccurrences;
                              Navigator.of(context).pop();
                            },
                            child: Text('Cancel',
                                style: TextStyle(color: Colors.grey[300])),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              // Enable repeat in the parent dialog
                              parentSetState(() {
                                _showRepeat = true;
                              });
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[300],
                            ),
                            child: Text('Done'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Method to add a new category
  Future<void> _showAddCategoryDialog(BuildContext context) async {
    _labelController.clear();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: _labelController,
            autofocus: true,
            validator: (value) => value?.isEmpty ?? true ? "Required" : null,
            decoration: InputDecoration(
              hintText: "Category name",
              prefixIcon: const Icon(Icons.category),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _categoryService.addCategory(_labelController.text);
                Navigator.pop(context);
                // Reload categories to reflect new category
                _loadCategories();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class CategoryTasksView extends StatefulWidget {
  final Category category;

  const CategoryTasksView({
    super.key,
    required this.category,
  });

  @override
  State<CategoryTasksView> createState() => _CategoryTasksViewState();
}

class _CategoryTasksViewState extends State<CategoryTasksView> {
  final TaskService _taskService = TaskService();
  final CompletedTaskService _completedTaskService = CompletedTaskService();
  List<Task> _tasks = [];
  List<Task> _completedTasks = [];
  bool _isLoading = true;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadCompletedTasks();

    // Listen for changes to tasks
    TaskService.tasksUpdatedNotifier.addListener(_refreshTasks);
  }

  void _refreshTasks() {
    if (mounted) {
      _loadTasks();
      _loadCompletedTasks();
    }
  }

  @override
  void dispose() {
    // Remove listener to prevent memory leaks
    TaskService.tasksUpdatedNotifier.removeListener(_refreshTasks);
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allTasks = await _taskService.getTasks();
      setState(() {
        _tasks = allTasks
            .where((task) => task.category == widget.category.label)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading tasks: $e');
    }
  }

  Future<void> _loadCompletedTasks() async {
    try {
      final allCompletedTasks = await _completedTaskService.getCompletedTasks();
      setState(() {
        _completedTasks = allCompletedTasks
            .where((task) => task.category == widget.category.label)
            .toList();
      });
    } catch (e) {
      print('Error loading completed tasks: $e');
    }
  }

  Future<void> _markTaskCompleted(Task task) async {
    // Before deleting the original task, check if it has repeat functionality
    String? nextDeadlineStr;
    if (task.repeatFrequency != null && task.repeatInterval != null) {
      // Calculate the next occurrence date based on repeat settings
      DateTime nextDeadline = _calculateNextDeadline(task);
      nextDeadlineStr = _formatDateTime(nextDeadline);
    }

    // First, add the task to completed_tasks with next deadline info
    await _completedTaskService.addCompletedTask(
      task.label,
      task.deadline,
      task.description,
      task.category,
      nextDeadline: nextDeadlineStr,
    );

    // Before deleting the original task, check if it has repeat functionality
    if (task.repeatFrequency != null && task.repeatInterval != null) {
      // Calculate the next occurrence date based on repeat settings
      DateTime nextDeadline = _calculateNextDeadline(task);

      // Check if we should create another occurrence based on end conditions
      bool shouldCreateNextOccurrence = true;

      // If "on" end type, check if next deadline is after the end date
      if (task.repeatEndType == 'on' && task.repeatEndDate != null) {
        DateTime endDate = _parseDateTime(task.repeatEndDate!);
        shouldCreateNextOccurrence = nextDeadline.isBefore(endDate) ||
            nextDeadline.isAtSameMomentAs(endDate);
      }
      // If "after" end type, we need to update the occurrence count
      else if (task.repeatEndType == 'after' &&
          task.repeatOccurrences != null) {
        // Get count of occurrences needed to re-create this task
        int remainingOccurrences = task.repeatOccurrences! - 1;
        if (remainingOccurrences <= 0) {
          shouldCreateNextOccurrence = false;
        } else {
          // Create a pending task with updated occurrence count instead of an active task
          if (shouldCreateNextOccurrence) {
            // Create a PendingTaskService instance
            final pendingTaskService = PendingTaskService();

            await pendingTaskService.addPendingTask(
              task.label,
              _formatDateTime(nextDeadline),
              task.description,
              task.category,
              repeatFrequency: task.repeatFrequency,
              repeatInterval: task.repeatInterval,
              repeatEndType: task.repeatEndType,
              repeatEndDate: task.repeatEndDate,
              repeatOccurrences: remainingOccurrences, // Decrement occurrences
            );
          }
          // Skip the standard task creation below since we've already created it as a pending task
          shouldCreateNextOccurrence = false;
        }
      }

      // Create the next occurrence if needed (for 'never' end type or 'on' date that hasn't been reached)
      if (shouldCreateNextOccurrence && task.repeatEndType != 'after') {
        // Format the next deadline
        String nextDeadlineStr = _formatDateTime(nextDeadline);

        // Get all pending tasks to check for duplicates
        final pendingTaskService = PendingTaskService();
        List<Task> pendingTasks = await pendingTaskService.getPendingTasks();

        // Also check active tasks for duplicates
        List<Task> currentTasks = await _taskService.getTasks();

        // Check if a task with the same label and deadline already exists in either list
        bool duplicateExists = currentTasks.any((existingTask) =>
                existingTask.label == task.label &&
                existingTask.deadline == nextDeadlineStr) ||
            pendingTasks.any((existingTask) =>
                existingTask.label == task.label &&
                existingTask.deadline == nextDeadlineStr);

        // Only create the new pending task if it doesn't already exist
        if (!duplicateExists) {
          // ALWAYS add to pending tasks instead of active tasks
          await pendingTaskService.addPendingTask(
            task.label,
            nextDeadlineStr,
            task.description,
            task.category,
            repeatFrequency: task.repeatFrequency,
            repeatInterval: task.repeatInterval,
            repeatEndType: task.repeatEndType,
            repeatEndDate: task.repeatEndDate,
            repeatOccurrences: task.repeatOccurrences,
          );
        }
      }
    }

    // Delete the original task
    await _taskService.deleteTask(task.id);

    // Check for any pending tasks that might now be due
    final pendingTaskService = PendingTaskService();
    await pendingTaskService.checkForDueTasks();

    // Refresh both task lists
    _loadTasks();
    _loadCompletedTasks();
  }

  // Helper method to calculate the next deadline based on repeat settings
  DateTime _calculateNextDeadline(Task task) {
    // Parse the current deadline
    DateTime currentDeadline = _parseDateTime(task.deadline);
    int interval = task.repeatInterval ?? 1;

    // Calculate next deadline based on frequency
    DateTime nextDeadline;
    switch (task.repeatFrequency) {
      case 'day':
        nextDeadline = currentDeadline.add(Duration(days: interval));
        break;
      case 'week':
        nextDeadline = currentDeadline.add(Duration(days: 7 * interval));
        break;
      case 'month':
        // Add months by calculating days (approximate)
        int year = currentDeadline.year;
        int month = currentDeadline.month + interval;
        int day = currentDeadline.day;

        // Handle month overflow
        while (month > 12) {
          month -= 12;
          year++;
        }

        // Handle day validity for the month (e.g., Feb 30 -> Feb 28/29)
        int daysInMonth = DateTime(year, month + 1, 0).day;
        if (day > daysInMonth) {
          day = daysInMonth;
        }

        nextDeadline = DateTime(
            year, month, day, currentDeadline.hour, currentDeadline.minute);
        break;
      case 'year':
        // Add years
        nextDeadline = DateTime(
            currentDeadline.year + interval,
            currentDeadline.month,
            currentDeadline.day,
            currentDeadline.hour,
            currentDeadline.minute);
        break;
      default:
        // Default to daily if something goes wrong
        nextDeadline = currentDeadline.add(Duration(days: interval));
    }

    return nextDeadline;
  }

  // Helper method to parse date string into DateTime
  DateTime _parseDateTime(String dateString) {
    try {
      if (dateString.isEmpty) {
        return DateTime.now(); // Default to now if empty
      }

      List<String> parts = dateString.split(' ');
      String datePart = parts[0];
      String timePart = parts.length > 1 ? parts[1] : "00:00";

      List<String> dateParts = datePart.split('-');
      List<String> timeParts = timePart.split(':');

      return DateTime(
        int.parse(dateParts[0]), // year
        int.parse(dateParts[1]), // month
        int.parse(dateParts[2]), // day
        int.parse(timeParts[0]), // hour
        int.parse(timeParts[1]), // minute
      );
    } catch (e) {
      print("Error parsing date: $e for string: $dateString");
      return DateTime.now(); // Default to now if parsing fails
    }
  }

  // Helper method to format DateTime back to string format used by the app
  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} "
        "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_tasks.isEmpty && _completedTasks.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height -
              180, // Adjust height to account for app bar
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min, // Use min instead of center
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.task_alt,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  "No tasks in ${widget.category.label}",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Add a new task to this category",
                  style: TextStyle(color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadTasks();
        await _loadCompletedTasks();
      },
      edgeOffset: 0.0,
      displacement: 40.0,
      color: Colors.blue,
      backgroundColor: Colors.white,
      strokeWidth: 3.0,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Active tasks list
          if (_tasks.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Text(
                "Active Tasks",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            ..._tasks.map((task) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TaskCard(
                    task: task,
                    onTaskCompleted: () {
                      _markTaskCompleted(task);
                    },
                    onRefresh: _loadTasks,
                  ),
                )),
          ],

          // Completed tasks section - only show if there are completed tasks
          if (_completedTasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: _buildCompletedTasksList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCompletedTasksList() {
    return ExpansionPanelList(
      expansionCallback: (int index, bool isExpanded) {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      children: [
        ExpansionPanel(
          isExpanded: _isExpanded,
          headerBuilder: (context, isExpanded) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "Completed Tasks (${_completedTasks.length})",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          body: Column(
            children: _completedTasks
                .map((task) => _buildCompletedTaskItem(task))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedTaskItem(Task task) {
    return Dismissible(
      key: Key('completed-${task.id}'),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        await _completedTaskService.deleteCompTask(task.id);
        _loadCompletedTasks();
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          task.label,
          style: const TextStyle(
            decoration: TextDecoration.lineThrough,
            color: Colors.grey,
          ),
        ),
        subtitle: task.deadline.isNotEmpty
            ? Text(
                task.nextDeadline != null && task.nextDeadline!.isNotEmpty
                    ? "Next due: ${task.nextDeadline}"
                    : "Completed on: ${task.deadline}",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.nextDeadline != null && task.nextDeadline!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.event_repeat,
                  color: Colors.blue[300],
                  size: 20,
                ),
              ),
            IconButton(
              icon: Icon(Icons.restore, color: Colors.blue[700]),
              onPressed: () => _restoreCompletedTask(task),
              tooltip: 'Restore task',
            ),
          ],
        ),
        onTap: () => _showCompletedTaskDetails(context, task),
      ),
    );
  }

  void _showCompletedTaskDetails(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty) ...[
              const Text(
                "Description:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(task.description),
              const SizedBox(height: 16),
            ],
            if (task.deadline.isNotEmpty) ...[
              const Text(
                "Completed on:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(task.deadline),
              const SizedBox(height: 16),
            ],
            if (task.nextDeadline != null && task.nextDeadline!.isNotEmpty) ...[
              const Text(
                "Next due:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(task.nextDeadline!),
              const SizedBox(height: 16),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _restoreCompletedTask(task);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreCompletedTask(Task task) async {
    // Add the task back to the active tasks
    await _taskService.addTask(
      task.label,
      task.deadline,
      task.description,
      task.category,
    );

    // Remove from completed tasks
    await _completedTaskService.deleteCompTask(task.id);

    // Refresh both lists
    _loadTasks();
    _loadCompletedTasks();

    // Show a confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "${task.label}" restored'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTaskCompleted;
  final VoidCallback onRefresh;

  const TaskCard({
    Key? key,
    required this.task,
    required this.onTaskCompleted,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _showTaskDetailsDialog(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Checkbox(
                    value: task.status == 1,
                    onChanged: (value) {
                      if (value == true) {
                        onTaskCompleted();
                      }
                    },
                  ),
                ],
              ),
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
              if (task.deadline.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.blue[800],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      task.deadline,
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskDetailsDialog(BuildContext context) {
    // Import the HomePage class to access its taskFormDialog method
    final homePageState = HomePage.of(context);
    if (homePageState != null) {
      // Use the taskFormDialog from HomePage
      homePageState.taskFormDialog(context, task: task, add: false);
    } else {
      // Fallback to the original dialog if HomePage is not found
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(task.label),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (task.description.isNotEmpty) ...[
                const Text(
                  "Description:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(task.description),
                const SizedBox(height: 16),
              ],
              if (task.deadline.isNotEmpty) ...[
                const Text(
                  "Deadline:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(task.deadline),
                const SizedBox(height: 16),
              ],
              const Text(
                "Status:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(task.status == 1 ? "Completed" : "Pending"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onTaskCompleted();
              },
              child: const Text('Mark Complete'),
            ),
          ],
        ),
      );
    }
  }
}
