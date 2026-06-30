import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final int counter;
  const HomeScreen({super.key, required this.counter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Home Page'),
        ],
      ),
    );
  }
}
