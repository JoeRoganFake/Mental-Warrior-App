import 'package:flutter/material.dart';
import 'package:mental_warior/models/tasks.dart';
import 'package:mental_warior/models/categories.dart';
import 'package:mental_warior/services/database_services.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({Key? key}) : super(key: key);

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage>
    with TickerProviderStateMixin {
  final CategoryService _categoryService = CategoryService();
  TabController? _tabController;
  List<Category> _categories = [];
  bool _isLoading = true;

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

        // Create new controller with proper index
        final newController = TabController(
          length: categories.length,
          vsync: this,
          initialIndex: currentIndex,
        );

        setState(() {
          _categories = categories;
          _tabController = newController;
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
    _tabController?.dispose(); // Safe dispose with null check
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
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddCategoryDialog(context),
          backgroundColor: Colors.blue,
          child: const Icon(Icons.add),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 55.0),
          child: const Text(
            "Categories & Tasks",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        toolbarHeight: 80, // Increase the overall height of the AppBar
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center, // Centers tabs properly
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
                constraints: const BoxConstraints(
                    minWidth: 100), // Fixed width for consistency
                child: Text(
                  category.label,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }).toList(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Add padding all around
        child: TabBarView(
          controller: _tabController,
          children: _categories
              .map((category) => CategoryTasksView(category: category))
              .toList(),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0, right: 16.0),
        child: FloatingActionButton(
          onPressed: () {
            _showAddCategoryDialog(context);
          },
          backgroundColor: Colors.blue,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Category name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await _categoryService.addCategory(controller.text.trim());
                Navigator.pop(context);
                // Reload categories and update TabController
                await _loadCategories();
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
    Key? key,
    required this.category,
  }) : super(key: key);

  @override
  State<CategoryTasksView> createState() => _CategoryTasksViewState();
}

class _CategoryTasksViewState extends State<CategoryTasksView> {
  final TaskService _taskService = TaskService();
  final CompletedTaskService _completedTaskService = CompletedTaskService();
  List<Task> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
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

  Future<void> _markTaskCompleted(Task task) async {
    await _completedTaskService.addCompletedTask(
      task.label,
      task.deadline,
      task.description,
      task.category,
    );
    await _taskService.deleteTask(task.id);

    _loadTasks(); // Refresh the current page
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_tasks.isEmpty) {
      return Center(
        child: Column(
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
            ),
            const SizedBox(height: 8),
            Text(
              "Add a new task to this category",
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return TaskCard(
            task: task,
            onTaskCompleted: () {
              _markTaskCompleted(task);
            },
            onRefresh: _loadTasks,
          );
        },
      ),
    );
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
