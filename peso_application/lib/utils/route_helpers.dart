import 'package:flutter/material.dart';

/// Simple page route that slides the new page in from the right.
PageRouteBuilder<T> slideFromRight<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final offsetTween = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      );
      return SlideTransition(
        position: offsetTween.animate(curved),
        child: child,
      );
    },
  );
}
