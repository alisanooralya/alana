import 'package:flutter/material.dart';

/// Tab "Profile" — menu pengaturan (tema, reader settings, tentang app, dsb).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
          ),
          ListTile(
            leading: Icon(Icons.book),
            title: Text('Reader Settings'),
          ),
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About'),
          ),
        ],
      ),
    );
  }
}
