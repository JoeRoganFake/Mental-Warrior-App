import 'dart:async';
import 'package:flutter/material.dart';

/// A debouncer utility to prevent excessive function calls
class Debouncer {
  final int milliseconds;
  VoidCallback? action;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  run(VoidCallback action) {
    if (_timer?.isActive == true) {
      _timer?.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void cancel() {
    _timer?.cancel();
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Performance optimizations for Flutter widgets
class PerformanceUtils {
  /// Prevent unnecessary rebuilds by checking if lists are equivalent
  static bool areListsEqual<T>(List<T> list1, List<T> list2, bool Function(T, T) compare) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (!compare(list1[i], list2[i])) return false;
    }
    return true;
  }

  /// Create optimized scroll physics for smooth scrolling
  static ScrollPhysics get optimizedScrollPhysics => const PageScrollPhysics()
      .applyTo(const ClampingScrollPhysics())
      .applyTo(const ScrollPhysics(parent: ClampingScrollPhysics()));

  /// Animated container with optimized performance
  static Widget buildSmoothContainer({
    required Widget child,
    required bool isVisible,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) {
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      height: isVisible ? null : 0,
      child: AnimatedOpacity(
        duration: duration,
        opacity: isVisible ? 1.0 : 0.0,
        child: isVisible ? child : const SizedBox.shrink(),
      ),
    );
  }

  /// Optimized list view builder
  static Widget buildOptimizedListView({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    ScrollController? controller,
    EdgeInsets? padding,
    ScrollPhysics? physics,
  }) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      physics: physics ?? optimizedScrollPhysics,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      cacheExtent: 300, // Optimize cache
      addRepaintBoundaries: true,
      addAutomaticKeepAlives: true,
      addSemanticIndexes: false, // Improve performance for large lists
    );
  }

  /// Create smooth loading indicator
  static Widget buildSmoothLoadingIndicator({
    String? message,
    Color? color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(color ?? Colors.blue),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: color?.withOpacity(0.7) ?? Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  /// Optimized fade transition
  static Widget buildFadeTransition({
    required Widget child,
    required bool isVisible,
    Duration duration = const Duration(milliseconds: 200),
  }) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: duration,
      child: child,
    );
  }

  /// Optimized scale transition
  static Widget buildScaleTransition({
    required Widget child,
    required bool isVisible,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.elasticOut,
  }) {
    return AnimatedScale(
      scale: isVisible ? 1.0 : 0.0,
      duration: duration,
      curve: curve,
      child: child,
    );
  }
}

/// Mixin for automatic debouncing of setState calls
mixin DebouncedStateMixin<T extends StatefulWidget> on State<T> {
  final Debouncer _debouncer = Debouncer(milliseconds: 50);

  void debouncedSetState(VoidCallback fn) {
    _debouncer.run(() {
      if (mounted) {
        setState(fn);
      }
    });
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }
}

/// Optimized StreamBuilder alternative
class OptimizedStreamBuilder<T> extends StatefulWidget {
  final Stream<T>? stream;
  final T? initialData;
  final Widget Function(BuildContext, AsyncSnapshot<T>) builder;

  const OptimizedStreamBuilder({
    Key? key,
    this.stream,
    this.initialData,
    required this.builder,
  }) : super(key: key);

  @override
  State<OptimizedStreamBuilder<T>> createState() => _OptimizedStreamBuilderState<T>();
}

class _OptimizedStreamBuilderState<T> extends State<OptimizedStreamBuilder<T>>
    with AutomaticKeepAliveClientMixin {
  late AsyncSnapshot<T> _snapshot;
  StreamSubscription<T>? _subscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _snapshot = AsyncSnapshot<T>.withData(ConnectionState.none, widget.initialData as T);
    _subscribe();
  }

  @override
  void didUpdateWidget(OptimizedStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _unsubscribe();
      _subscribe();
    }
  }

  void _subscribe() {
    if (widget.stream != null) {
      _subscription = widget.stream!.listen(
        (T data) {
          if (mounted) {
            setState(() {
              _snapshot = AsyncSnapshot<T>.withData(ConnectionState.active, data);
            });
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (mounted) {
            setState(() {
              _snapshot = AsyncSnapshot<T>.withError(ConnectionState.active, error, stackTrace);
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _snapshot = _snapshot.inState(ConnectionState.done);
            });
          }
        },
      );
    }
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.builder(context, _snapshot);
  }
}

extension AsyncSnapshotExtension<T> on AsyncSnapshot<T> {
  AsyncSnapshot<T> inState(ConnectionState state) {
    return AsyncSnapshot<T>.withData(state, data as T);
  }
}