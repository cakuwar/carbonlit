import 'package:flutter/material.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Help & Support'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: Text('FAQ'),
            onTap: () {
              // TODO: Implement FAQ functionality
            },
          ),
          ListTile(
            title: Text('Contact Support'),
            onTap: () {
              // TODO: Implement contact support functionality
            },
          ),
        ],
      ),
    );
  }
}