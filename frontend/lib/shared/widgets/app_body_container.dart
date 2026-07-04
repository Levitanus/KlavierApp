import 'package:flutter/material.dart';

class AppBodyContainer extends StatelessWidget {
  const AppBodyContainer({
    super.key,
    required this.child,
    this.maxWidth = 1000,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}