import 'package:flutter/material.dart';
import 'package:alana/example_library_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Alana Demo',
      theme: ThemeData(
        colorSheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ExampleLibraryScreen(),
    );
  }
}
