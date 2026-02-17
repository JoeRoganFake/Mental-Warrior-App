import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mental_warior/models/tasks.dart';
import 'package:mental_warior/models/categories.dart';
import 'package:mental_warior/pages/home.dart';
import 'package:mental_warior/services/database_services.dart';

import 'package:mental_warior/widgets/xp_gain_bubble.dart';
import 'package:mental_warior/widgets/level_up_animation.dart';
import 'package:mental_warior/utils/app_theme.dart';


class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final CategoryService _categoryService = CategoryService();
  TabController? _tabController;
  List<Category> _categories = [];
  bool _isLoading = true;
  bool _isInitialized = false;

  // Dialog controllers - lazy initialization
  TextEditingController? _labelController;
  TextEditingController? _descriptionController;
  TextEditingController? _dateController;
  TextEditingController? _repeatEndDateController;
  TextEditingController? _repeatOccurrencesController;

  // Scroll offset for gradient fade effect
  double _scrollOffset = 0.0;
  Timer? _scrollThrottleTimer;

  Category? _currentCategory;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializePageAsync();
  }

  // Async initialization to prevent blocking UI
  Future<void> _initializePageAsync() async {
    await Future.microtask(() => _loadCategories());
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;

    try {
      final categories = await _categoryService.getCategories();
      if (!mounted) return;

      final allTasksCategory =
          Category(id: -1, label: "All Tasks", isDefault: 0);
      final updatedCategories = [allTasksCategory, ...categories];

      // Only rebuild if categories actually changed
      if (!_categoriesEqual(_categories, updatedCategories)) {
        await _updateTabController(updatedCategories);
      }

      if (mounted && _isLoading) {
        setState(() {
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
      debugPrint('Error loading categories: $e');
    }
  }

  bool _categoriesEqual(List<Category> list1, List<Category> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id || list1[i].label != list2[i].label) {
        return false;
      }
    }
    return true;
  }

  Future<void> _updateTabController(List<Category> updatedCategories) async {
    int currentIndex = _tabController?.index ?? 0;
    if (currentIndex >= updatedCategories.length) {
      currentIndex =
          updatedCategories.isEmpty ? 0 : updatedCategories.length - 1;
    }

    _tabController?.removeListener(_tabControllerListener);
    _tabController?.dispose();

    final newController = TabController(
      length: updatedCategories.length,
      vsync: this,
      initialIndex: currentIndex,
    );

    newController.addListener(_tabControllerListener);

    if (mounted) {
      setState(() {
        _categories = updatedCategories;
        _tabController = newController;
        _currentCategory = updatedCategories.isNotEmpty
            ? updatedCategories[currentIndex]
            : null;
        _isInitialized = true;
      });
    }
  }

  void _tabControllerListener() {
    if (_tabController != null &&
        !_tabController!.indexIsChanging &&
        mounted &&
        _categories.isNotEmpty) {
      final newCategory = _categories[_tabController!.index];
      if (_currentCategory?.id != newCategory.id) {
        setState(() {
          _currentCategory = newCategory;
        });
      }
    }
  }

  Future<void> _deleteCategory(Category category) async {
    if (category.isDefault == 1) {
      _showErrorSnackBar('Cannot delete default category');
      return;
    }

    final bool? confirm = await _showDeleteConfirmDialog(category);
    if (confirm == true && mounted) {
      // Show loading indicator
      _showLoadingDialog('Deleting category...');

      try {
        await _categoryService.deleteCategory(category.id);
        await _loadCategories();
        if (mounted && context.mounted)
          Navigator.of(context).pop(); // Close loading dialog
      } catch (e) {
        if (mounted && context.mounted)
          Navigator.of(context).pop(); // Close loading dialog
        _showErrorSnackBar('Error deleting category');
      }
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        content: Row(
          children: [
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.accent)),
            const SizedBox(width: 16),
            Text(message, style: AppTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message,
            style: AppTheme.bodyMedium.copyWith(color: Colors.white)),
        backgroundColor: AppTheme.error,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmDialog(Category category) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusLg),
        title: Text('Delete Category?', style: AppTheme.headlineMedium),
        content: Text(
          'Are you sure you want to delete "${category.label}"?',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollThrottleTimer?.cancel();
    _tabController?.removeListener(_tabControllerListener);
    _tabController?.dispose();
    _labelController?.dispose();
    _descriptionController?.dispose();
    _dateController?.dispose();
    _repeatEndDateController?.dispose();
    _repeatOccurrencesController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return _buildBody();
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_categories.isEmpty) {
      return _buildEmptyState();
    }

    return _buildMainContent();
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(showTabs: false),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.accent)),
            const SizedBox(height: 16),
            Text('Loading categories...',
                style: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(showTabs: false),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined,
                size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No categories found',
                style: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              onPressed: _loadCategories,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(showTabs: true),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            physics: const BouncingScrollPhysics(),
            children: _categories
                .map(
                  (category) => OptimizedCategoryTasksView(
                    key: ValueKey(category.id),
                    category: category,
                    onScrollOffsetChanged: (offset) {
                      setState(() {
                        _scrollOffset = offset;
                      });
                    },
                  ),
                )
                .toList(),
          ),
          if (_isInitialized)
            Positioned(
              bottom: 16,
              right: 16,
              child: _buildFAB(),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({required bool showTabs}) {
    // Calculate fade factor based on scroll offset (0 to 1)
    // Fade completes after scrolling 200 pixels
    double fadeFactor = (_scrollOffset / 200).clamp(0.0, 1.0);

    // Interpolate color: start with accent blue, fade to black
    final accentColor = AppTheme.accent;
    final fadedColor = Color.lerp(
      accentColor.withOpacity(0.15),
      Colors.black.withOpacity(0.15),
      fadeFactor,
    )!;

    return AppBar(
      backgroundColor: AppTheme.background,
      elevation: 0,
      toolbarHeight: 100,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              fadedColor,
              AppTheme.background,
            ],
          ),
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 48, left: 11.0),
              child: Text('Tasks', style: AppTheme.displayMedium),
            ),
          ],
        ),
      ),
      bottom: showTabs
          ? TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              labelColor: AppTheme.accent,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle:
                  AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              unselectedLabelStyle: AppTheme.bodyMedium,
              indicatorColor: AppTheme.accent,
              indicatorWeight: 2,
              dividerColor: AppTheme.surfaceBorder,
              tabs: _categories
                  .map((category) => GestureDetector(
                        onLongPress: () => _deleteCategory(category),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12.0, horizontal: 8),
                          constraints: const BoxConstraints(minWidth: 80),
                          child:
                              Text(category.label, textAlign: TextAlign.center),
                        ),
                      ))
                  .toList(),
            )
          : null,
    );
  }

  Widget _buildFAB() {
    return AnimatedScale(
      scale: _isInitialized ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      child: Material(
        color: Colors.transparent,
        child: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'task') {
              Category categoryToUse = _currentCategory ??
                  (_categories.isNotEmpty
                      ? _categories.first
                      : Category(id: -1, label: "General", isDefault: 0));
              _showAddTaskDialog(context, categoryToUse);
            } else if (value == 'category') {
              _showAddCategoryDialog(context);
            }
          },
          offset: const Offset(-60, -50),
          shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusLg),
          color: AppTheme.surface,
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'task',
              child: Row(
                children: [
                  Icon(Icons.assignment_outlined,
                      color: AppTheme.accent, size: 20),
                  const SizedBox(width: 12),
                  Text('Create Task', style: AppTheme.bodyMedium),
                ],
              ),
            ),
            PopupMenuDivider(
              height: 1,
            ),
            PopupMenuItem<String>(
              value: 'category',
              child: Row(
                children: [
                  Icon(Icons.category_outlined,
                      color: AppTheme.accent, size: 20),
                  const SizedBox(width: 12),
                  Text('Create Category', style: AppTheme.bodyMedium),
                ],
              ),
            ),
          ],
          child: InkWell(
            borderRadius: BorderRadius.circular(100),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.6), width: 2),
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final TextEditingController categoryController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusLg),
        title: Text('New Category',
            style: AppTheme.headlineMedium.copyWith(color: AppTheme.accent)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: categoryController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Category name',
              hintStyle: TextStyle(color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: AppTheme.borderRadiusMd,
                borderSide: BorderSide(color: AppTheme.surfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppTheme.borderRadiusMd,
                borderSide: BorderSide(color: AppTheme.surfaceBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppTheme.borderRadiusMd,
                borderSide: BorderSide(color: AppTheme.accent, width: 2),
              ),
            ),
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
            validator: (value) =>
                value?.isEmpty ?? true ? 'Category name is required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusMd),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context);
                _showLoadingDialog('Adding category...');
                try {
                  await _categoryService.addCategory(categoryController.text);
                  await _loadCategories();
                  if (mounted && context.mounted)
                    Navigator.of(context).pop(); // Close loading dialog
                } catch (e) {
                  if (mounted && context.mounted)
                    Navigator.of(context).pop(); // Close loading dialog
                  _showErrorSnackBar('Error adding category');
                }
              }
            },
            child: Text('Add',
                style: AppTheme.labelLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }

  // Simplified task dialog - using lazy initialization
  Future<void> _showAddTaskDialog(
      BuildContext context, Category category) async {
    // Set selected category - if current tab is "All Tasks", use default category
    Category? defaultCategory;
    try {
      defaultCategory = await _categoryService.getDefaultCategory();
    } catch (e) {
      defaultCategory = Category(id: 0, label: "Default", isDefault: 1);
    }
    
    final categoryToUse = category.id == -1 ? defaultCategory : category;
    
    // Use the home page's task dialog
    final homePageState = HomePage.of(context);
    if (homePageState != null && mounted) {
      // Set the selected category in HomePage state before showing dialog
      homePageState.selectedCategory = categoryToUse;
      
      await homePageState.taskFormDialog(
        context,
        task: null,
        add: true,
        changeCompletedTask: false,
      );
      
      // Trigger refresh after dialog closes
      TaskService.tasksUpdatedNotifier.value =
          !TaskService.tasksUpdatedNotifier.value;
    }
  }





}

// Optimized CategoryTasksView with better performance
class OptimizedCategoryTasksView extends StatefulWidget {
  final Category category;
  final Function(double)? onScrollOffsetChanged;

  const OptimizedCategoryTasksView({
    super.key,
    required this.category,
    this.onScrollOffsetChanged,
  });

  @override
  State<OptimizedCategoryTasksView> createState() =>
      _OptimizedCategoryTasksViewState();
}

class _OptimizedCategoryTasksViewState extends State<OptimizedCategoryTasksView>
    with AutomaticKeepAliveClientMixin {
  final TaskService _taskService = TaskService();
  final CompletedTaskService _completedTaskService = CompletedTaskService();
  final PendingTaskService _pendingTaskService = PendingTaskService();
  final XPService _xpService = XPService();
  
  late ScrollController _localScrollController;
  Timer? _scrollThrottleTimer;
  
  List<Task> _tasks = [];
  List<Task> _completedTasks = [];
  List<Task> _visibleCompletedTasks = []; // Only visible completed tasks
  List<Task> _pendingTasks = []; // Future tasks to be activated
  bool _isLoading = true;
  bool _isExpandedCompleted = false;
  bool _isExpandedPending = false;
  bool _isProcessingTask = false;
  bool _isLoadingMoreCompleted = false;

  // Pagination for completed tasks
  static const int _completedTasksPageSize = 20;
  int _currentCompletedPage = 0;
  bool _hasMoreCompletedTasks = true;
  
  // Sorting options
  String _sortBy = 'deadline'; // 'deadline', 'importance', 'name'

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _localScrollController = ScrollController();
    _localScrollController.addListener(_onScroll);
    _loadDataAsync();
    TaskService.tasksUpdatedNotifier.addListener(_refreshTasks);
  }

  void _onScroll() {
    // More aggressive throttling to prevent UI lag (33ms = 30fps)
    if (_scrollThrottleTimer?.isActive ?? false) return;

    widget.onScrollOffsetChanged?.call(_localScrollController.offset);

    _scrollThrottleTimer = Timer(const Duration(milliseconds: 33), () {
      _scrollThrottleTimer = null;
    });
  }

  Future<void> _loadDataAsync() async {
    await Future.wait(
        [_loadTasks(), _loadCompletedTasks(), _loadPendingTasks()]);
  }

  void _refreshTasks() {
    if (mounted) {
      _loadDataAsync();
    }
  }

  @override
  void dispose() {
    _localScrollController.removeListener(_onScroll);
    _localScrollController.dispose();
    _scrollThrottleTimer?.cancel();
    TaskService.tasksUpdatedNotifier.removeListener(_refreshTasks);
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final allTasks = await _taskService.getTasks();

      final filteredTasks = widget.category.id == -1
          ? allTasks
          : allTasks
              .where((task) => task.category == widget.category.label)
              .toList();

      if (mounted) {
        setState(() {
          _tasks = filteredTasks;
          // Apply sorting after loading
          _applySort();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Error loading tasks: $e');
    }
  }

  void _applySort() {
    switch (_sortBy) {
      case 'deadline':
        _tasks.sort((a, b) {
          try {
            final aDeadline =
                a.deadline.isNotEmpty ? a.deadline.split(' ')[0] : '';
            final bDeadline =
                b.deadline.isNotEmpty ? b.deadline.split(' ')[0] : '';

            // Tasks without due date go to bottom
            if (aDeadline.isEmpty && bDeadline.isEmpty) return 0;
            if (aDeadline.isEmpty) return 1;
            if (bDeadline.isEmpty) return -1;

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final tomorrow = today.add(const Duration(days: 1));
            final todayStr =
                "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
            final tomorrowStr =
                "${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}";

            // Today tasks come first
            if (aDeadline == todayStr && bDeadline != todayStr) return -1;
            if (aDeadline != todayStr && bDeadline == todayStr) return 1;

            // Tomorrow tasks come second
            if (aDeadline == tomorrowStr && bDeadline != tomorrowStr) return -1;
            if (aDeadline != tomorrowStr && bDeadline == tomorrowStr) return 1;

            // Other dates sorted chronologically
            final aDate = DateTime.parse(aDeadline);
            final bDate = DateTime.parse(bDeadline);
            return aDate.compareTo(bDate);
          } catch (e) {
            return 0;
          }
        });
        break;
      case 'importance':
        _tasks.sort((a, b) => b.importance.compareTo(a.importance));
        break;
      case 'name':
        _tasks.sort((a, b) => a.label.compareTo(b.label));
        break;
    }
  }

  void _sortTasks() {
    setState(() {
      _applySort();
    });
  }

  Future<void> _loadCompletedTasks({bool loadMore = false}) async {
    if (_isLoadingMoreCompleted) return;
    
    try {
      if (loadMore) {
        setState(() {
          _isLoadingMoreCompleted = true;
        });
      }

      final allCompletedTasks = await _completedTaskService.getCompletedTasks();

      final filteredTasks = widget.category.id == -1
          ? allCompletedTasks
          : allCompletedTasks
              .where((task) => task.category == widget.category.label)
              .toList();

      if (mounted) {
        setState(() {
          _completedTasks = filteredTasks;

          if (!loadMore) {
            // Reset pagination when loading fresh data
            _currentCompletedPage = 0;
            _visibleCompletedTasks = [];
          }
          
          // Calculate pagination
          final startIndex = _currentCompletedPage * _completedTasksPageSize;
          final endIndex = (startIndex + _completedTasksPageSize)
              .clamp(0, _completedTasks.length);

          if (loadMore && startIndex < _completedTasks.length) {
            // Add more tasks to visible list
            _visibleCompletedTasks
                .addAll(_completedTasks.sublist(startIndex, endIndex));
            _currentCompletedPage++;
          } else if (!loadMore) {
            // Initial load
            _visibleCompletedTasks =
                _completedTasks.take(_completedTasksPageSize).toList();
            if (_completedTasks.isNotEmpty) {
              _currentCompletedPage = 1;
            }
          }

          _hasMoreCompletedTasks =
              _visibleCompletedTasks.length < _completedTasks.length;
          _isLoadingMoreCompleted = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMoreCompleted = false;
        });
      }
      debugPrint('Error loading completed tasks: $e');
    }
  }

  Future<void> _loadPendingTasks() async {
    try {
      final allPendingTasks = await _pendingTaskService.getPendingTasks();

      final filteredTasks = widget.category.id == -1
          ? allPendingTasks
          : allPendingTasks
              .where((task) => task.category == widget.category.label)
              .toList();

      if (mounted) {
        setState(() {
          _pendingTasks = filteredTasks;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending tasks: $e');
    }
  }

  Future<void> _markTaskCompleted(Task task) async {
    if (_isProcessingTask) return;

    setState(() {
      _isProcessingTask = true;
    });

    try {
      // Show optimistic UI update - remove from active tasks
      setState(() {
        _tasks.removeWhere((t) => t.id == task.id);
      });

      // Background processing
      await _processTaskCompletion(task);

      // Award XP and show animations
      final xpResult = await _xpService.addTaskXP();

      if (mounted) {
        showXPGainBubble(context, xpResult['xpGained']);

        if (xpResult['didLevelUp'] == true) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              showLevelUpAnimation(
                context,
                newLevel: xpResult['newLevel'],
                newRank: xpResult['userXP'].rank,
                xpGained: xpResult['xpGained'],
              );
            }
          });
        }
      }

      // Reload completed tasks to show the newly completed task
      await _loadCompletedTasks();
    } catch (e) {
      // Revert optimistic update on error
      await _loadTasks();
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error completing task: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingTask = false;
        });
      }
    }
  }

  Future<void> _processTaskCompletion(Task task) async {
    // Process repeat functionality
    String? nextDeadlineStr;
    if (task.repeatFrequency != null && task.repeatInterval != null) {
      final nextDeadline = _calculateNextDeadline(task);
      nextDeadlineStr = _formatDateTime(nextDeadline);
    }

    // Add to completed tasks
    await _completedTaskService.addCompletedTask(
      task.label,
      task.deadline,
      task.description,
      task.category,
      nextDeadline: nextDeadlineStr,
    );

    // Handle repeat tasks
    if (task.repeatFrequency != null && task.repeatInterval != null) {
      await _handleRepeatTask(task);
    }

    // Delete original task
    await _taskService.deleteTask(task.id);
    
    // Check for due pending tasks
    final pendingTaskService = PendingTaskService();
    await pendingTaskService.checkForDueTasks();
  }

  Future<void> _handleRepeatTask(Task task) async {
    final nextDeadline = _calculateNextDeadline(task);
    bool shouldCreateNext = true;

    // Check end conditions
    if (task.repeatEndType == 'on' && task.repeatEndDate != null) {
      final endDate = _parseDateTime(task.repeatEndDate!);
      shouldCreateNext = nextDeadline.isBefore(endDate) ||
          nextDeadline.isAtSameMomentAs(endDate);
    } else if (task.repeatEndType == 'after' &&
        task.repeatOccurrences != null) {
      final remaining = task.repeatOccurrences! - 1;
      shouldCreateNext = remaining > 0;
    }

    if (shouldCreateNext) {
      final pendingTaskService = PendingTaskService();
      final nextDeadlineStr = _formatDateTime(nextDeadline);
      
      // Check for duplicates
      final [pendingTasks, currentTasks] = await Future.wait([
        pendingTaskService.getPendingTasks(),
        _taskService.getTasks(),
      ]);

      final duplicateExists = [...currentTasks, ...pendingTasks].any(
          (existingTask) =>
              existingTask.label == task.label &&
              existingTask.deadline == nextDeadlineStr);

      if (!duplicateExists) {
        await pendingTaskService.addPendingTask(
          task.label,
          nextDeadlineStr,
          task.description,
          task.category,
          importance: task.importance,
          repeatFrequency: task.repeatFrequency,
          repeatInterval: task.repeatInterval,
          repeatEndType: task.repeatEndType,
          repeatEndDate: task.repeatEndDate,
          repeatOccurrences: task.repeatEndType == 'after'
              ? (task.repeatOccurrences! - 1)
              : task.repeatOccurrences,
        );
      }
    }
  }

  DateTime _calculateNextDeadline(Task task) {
    final currentDeadline = _parseDateTime(task.deadline);
    final interval = task.repeatInterval ?? 1;

    switch (task.repeatFrequency) {
      case 'day':
        return currentDeadline.add(Duration(days: interval));
      case 'week':
        return currentDeadline.add(Duration(days: 7 * interval));
      case 'month':
        var year = currentDeadline.year;
        var month = currentDeadline.month + interval;
        var day = currentDeadline.day;

        while (month > 12) {
          month -= 12;
          year++;
        }

        final daysInMonth = DateTime(year, month + 1, 0).day;
        if (day > daysInMonth) day = daysInMonth;

        return DateTime(
            year, month, day, currentDeadline.hour, currentDeadline.minute);
      case 'year':
        return DateTime(
          currentDeadline.year + interval,
          currentDeadline.month,
          currentDeadline.day,
          currentDeadline.hour,
          currentDeadline.minute,
        );
      default:
        return currentDeadline.add(Duration(days: interval));
    }
  }

  DateTime _parseDateTime(String dateString) {
    try {
      if (dateString.isEmpty) return DateTime.now();
      
      final parts = dateString.split(' ');
      final datePart = parts[0];
      final timePart = parts.length > 1 ? parts[1] : '00:00';
      
      final dateParts = datePart.split('-');
      final timeParts = timePart.split(':');
      
      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
    } catch (e) {
      debugPrint('Error parsing date: $e for string: $dateString');
      return DateTime.now();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} "
        "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_tasks.isEmpty &&
        _visibleCompletedTasks.isEmpty &&
        _pendingTasks.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadDataAsync,
      child: ListView(
        controller: _localScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        cacheExtent: 300, // Optimize scroll view caching
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (_tasks.isNotEmpty) ...[
            _buildSortHeader(),
            _buildSectionHeader('Active Tasks'),
            ..._buildTaskList(),
          ],
          if (_visibleCompletedTasks.isNotEmpty ||
              _pendingTasks.isNotEmpty) ...[
            const SizedBox(height: 16),
            if (_visibleCompletedTasks.isNotEmpty)
              _buildCompletedTasksSection(),
            if (_pendingTasks.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildPendingTasksSection(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 180,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.task_alt,
                  size: 80, color: Colors.grey.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                'No tasks in ${widget.category.label}',
                style: TextStyle(
                    fontSize: 18, color: Colors.grey.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Add a new task to this category',
                style: TextStyle(color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Sort By',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
              _sortTasks();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'deadline',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18),
                    SizedBox(width: 12),
                    Text('Deadline'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'importance',
                child: Row(
                  children: [
                    Icon(Icons.priority_high, size: 18),
                    SizedBox(width: 12),
                    Text('Importance'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.abc, size: 18),
                    SizedBox(width: 12),
                    Text('Task Name'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accent, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.sort, color: AppTheme.accent, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _sortBy == 'deadline'
                        ? 'Deadline'
                        : _sortBy == 'importance'
                            ? 'Importance'
                            : 'Name',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  List<Widget> _buildTaskList() {
    return _tasks
        .map((task) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: OptimizedTaskCard(
                key: ValueKey(task.id),
                task: task,
                onTaskCompleted: () => _markTaskCompleted(task),
                isProcessing: _isProcessingTask,
              ),
            ))
        .toList();
  }

  Widget _buildCompletedTasksSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppTheme.borderRadiusLg,
          color: AppTheme.surface.withOpacity(0.4),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpandedCompleted = !_isExpandedCompleted;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: _isExpandedCompleted
                      ? const BorderRadius.vertical(top: Radius.circular(20))
                      : AppTheme.borderRadiusLg,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.withValues(alpha: 0.5),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Completed Tasks',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              '${_completedTasks.length} completed',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Icon(
                      _isExpandedCompleted
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (_isExpandedCompleted) ...[
              Divider(
                height: 1,
                color: Colors.green.withValues(alpha: 0.1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    ..._visibleCompletedTasks
                        .map(_buildCompletedTaskItem)
                        .toList(),
                    if (_hasMoreCompletedTasks) _buildLoadMoreButton(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTasksSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppTheme.borderRadiusLg,
          color: AppTheme.surface.withOpacity(0.4),
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpandedPending = !_isExpandedPending;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: _isExpandedPending
                      ? const BorderRadius.vertical(top: Radius.circular(20))
                      : AppTheme.borderRadiusLg,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: AppTheme.accent.withValues(alpha: 0.5),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scheduled Tasks',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              '${_pendingTasks.length} pending',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Icon(
                      _isExpandedPending
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (_isExpandedPending) ...[
              Divider(
                height: 1,
                color: AppTheme.accent.withValues(alpha: 0.1),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: Column(
                  children: _pendingTasks
                      .map((task) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: AppTheme.borderRadiusMd,
                                border: Border.all(
                                  color:
                                      AppTheme.textSecondary.withOpacity(0.05),
                                  width: 1,
                                ),
                                color: AppTheme.surfaceLight.withOpacity(0.3),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_outlined,
                                        size: 16,
                                        color: AppTheme.textSecondary
                                            .withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          task.label,
                                          style: AppTheme.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (task.description.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      task.description,
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textSecondary
                                            .withValues(alpha: 0.6),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: AppTheme.textSecondary
                                            .withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Task Due: ${task.deadline.split(' ')[0]}',
                                          style: AppTheme.bodySmall.copyWith(
                                            color: AppTheme.textSecondary
                                                .withValues(alpha: 0.6),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: _isLoadingMoreCompleted
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : ElevatedButton.icon(
              onPressed: () => _loadCompletedTasks(loadMore: true),
              icon: const Icon(Icons.expand_more, size: 18),
              label: const Text(
                'Load More',
                style: TextStyle(fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.grey[700],
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
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
        try {
          // Remove from UI immediately
          setState(() {
            _visibleCompletedTasks.removeWhere((t) => t.id == task.id);
            _completedTasks.removeWhere((t) => t.id == task.id);
          });

          // Delete from database
          await _completedTaskService.deleteCompTask(task.id);
          
          // Show success message
          if (mounted) {
            final messenger = ScaffoldMessenger.of(context);
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(
                content: Text('Task "${task.label}" deleted'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (e) {
          // Revert on error
          await _loadCompletedTasks();
          if (mounted) {
            final messenger = ScaffoldMessenger.of(context);
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(
                content: Text('Error deleting task: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
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
                task.nextDeadline?.isNotEmpty == true
                    ? 'Next due: ${task.nextDeadline}'
                    : 'Completed on: ${task.deadline}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.nextDeadline?.isNotEmpty == true)
              Icon(Icons.event_repeat, color: Colors.blue[300], size: 20),
            IconButton(
              icon: Icon(Icons.restore, color: Colors.blue[700]),
              onPressed: () => _restoreTask(task),
              tooltip: 'Restore task',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreTask(Task task) async {
    try {
      // Show optimistic update
      setState(() {
        _visibleCompletedTasks.removeWhere((t) => t.id == task.id);
        _completedTasks.removeWhere((t) => t.id == task.id);
      });

      await _taskService.addTask(
          task.label, task.deadline, task.description, task.category,
          importance: task.importance,
          repeatFrequency: task.repeatFrequency,
          repeatInterval: task.repeatInterval,
          repeatEndType: task.repeatEndType,
          repeatEndDate: task.repeatEndDate,
          repeatOccurrences: task.repeatOccurrences,
          reminders: task.reminders);
      await _completedTaskService.deleteCompTask(task.id);
      await _xpService.subtractTaskXP();
      
      // Reload all data to ensure consistency
      await _loadDataAsync();
      
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Task "${task.label}" restored'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Revert optimistic update on error
      await _loadCompletedTasks();

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error restoring task: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Optimized TaskCard with better performance
class OptimizedTaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTaskCompleted;
  final bool isProcessing;

  const OptimizedTaskCard({
    super.key,
    required this.task,
    required this.onTaskCompleted,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isProcessing ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: isProcessing ? null : () => _showTaskDetails(context),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: AppTheme.borderRadiusLg,
            color: AppTheme.surface.withOpacity(0.6),
            boxShadow: [
              BoxShadow(
                color: AppTheme.textSecondary.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: AppTheme.textSecondary.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox on the left
              if (isProcessing)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                GestureDetector(
                  onTap: onTaskCompleted,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.accent.withOpacity(0.5),
                        width: 2.5,
                      ),
                    ),
                    child: Icon(
                      Icons.check,
                      size: 18,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              const SizedBox(width: 14),
              // Task content - expanded
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.label,
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Importance indicator - dot meter
                        _buildImportanceDots(task.importance),
                      ],
                    ),
                    if (task.description.isNotEmpty ||
                        task.deadline.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildSubtitle(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    List<TextSpan> subtitleSpans = [];

    if (task.deadline.isNotEmpty) {
      try {
        final parts = task.deadline.split(' ');
        final dateStr = parts[0];

        final DateTime deadline = DateTime.parse(dateStr);
        final DateTime now = DateTime.now();
        final DateTime today = DateTime(now.year, now.month, now.day);
        final DateTime tomorrow = today.add(const Duration(days: 1));

        String dateDisplay = '';
        bool isBlue = false;

        if (deadline.isAtSameMomentAs(today)) {
          dateDisplay = "Today";
          isBlue = true;
        } else if (deadline.isAtSameMomentAs(tomorrow)) {
          dateDisplay = "Tomorrow";
          isBlue = true;
        } else {
          // Format as "Apr 5" style
          final months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec'
          ];
          dateDisplay = '${months[deadline.month - 1]} ${deadline.day}';
        }
        
        subtitleSpans.add(TextSpan(
          text: dateDisplay,
          style: TextStyle(
            color: isBlue ? Colors.blue : AppTheme.textSecondary,
            fontSize: 12,
          ),
        ));
      } catch (e) {
        subtitleSpans.add(TextSpan(
          text: task.deadline,
          style: AppTheme.bodySmall.copyWith(fontSize: 12),
        ));
      }
    }

    if (task.description.isNotEmpty) {
      if (subtitleSpans.isNotEmpty) {
        subtitleSpans.add(TextSpan(
          text: ' • ',
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ));
      }
      subtitleSpans.add(TextSpan(
        text: task.description,
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.textSecondary,
          fontSize: 12,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: subtitleSpans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _showTaskDetails(BuildContext context) {
    // Use the existing task details dialog or fallback
    final homePageState = HomePage.of(context);
    if (homePageState != null) {
      homePageState.taskFormDialog(context, task: task, add: false);
    } else {
      _showFallbackDialog(context);
    }
  }

  void _showFallbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty) ...[
              const Text('Description:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(task.description),
              const SizedBox(height: 16),
            ],
            if (task.deadline.isNotEmpty) ...[
              const Text('Deadline:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(task.deadline),
              const SizedBox(height: 16),
            ],
            const Text('Category:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(task.category),
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
              onTaskCompleted();
            },
            child: const Text('Mark Complete'),
          ),
        ],
      ),
    );
  }

  /// Builds a minimalist dot-based importance indicator
  Widget _buildImportanceDots(int importance) {
    const double dotSize = 6.0;
    const double spacing = 3.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final bool isFilled = index < importance;
        return Container(
          margin: EdgeInsets.only(right: index < 4 ? spacing : 0),
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? Colors.white.withOpacity(0.85)
                : Colors.white.withOpacity(0.15),
            border: isFilled
                ? null
                : Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 0.5,
                  ),
          ),
        );
      }),
    );
  }

}
