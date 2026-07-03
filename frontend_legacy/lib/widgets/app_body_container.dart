/// Container for app body width constraint
import 'package:flutter/material.dart';

class AppBodyContainer extends StatelessWidget {
  final Widget child;
  const AppBodyContainer({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1000),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: child,
      ),
    );
  }
}
