import 'package:flutter/material.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  _SecurityPageState createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  bool _biometricLogin = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Security'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: Text('Change Password'),
            onTap: () {
              // TODO: Implement change password functionality
            },
          ),
          SwitchListTile(
            title: Text('Enable Biometric Login'),
            value: _biometricLogin,
            onChanged: (value) {
              setState(() {
                _biometricLogin = value;
              });
              // TODO: Save biometric login preference
            },
          ),
        ],
      ),
    );
  }
}