import 'package:flutter/material.dart';

/// Custom page route with slide transition animation
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  
  SlidePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
}

/// Show dialog with fade animation
Future<T?> showAnimatedDialog<T>({
  required BuildContext context,
  required Widget dialog,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => dialog,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        ),
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ).drive(Tween<double>(begin: 0.95, end: 1.0)),
          child: child,
        ),
      );
    },
  );
}

/// Show modal bottom sheet with slide animation
Future<T?> showAnimatedModalBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  double? elevation,
  ShapeBorder? shape,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: backgroundColor,
    elevation: elevation,
    shape: shape,
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 300),
    ),
  );
}
