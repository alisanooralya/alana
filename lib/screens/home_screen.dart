import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final int counter;
  final VoidCallback incrementCounter;

  const HomeScreen({super.key, required this.counter, required this.incrementCounter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('You have pushed the button this many times:'),
          Text(
            '$counter',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ),
    );
  }
}
