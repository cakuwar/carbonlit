import 'package:flutter/material.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  _PrivacyPageState createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool _privateAccount = false;
  bool _dataSharing = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: Text('Private Account'),
            subtitle: Text('Only approved followers can see your posts.'),
            value: _privateAccount,
            onChanged: (value) {
              setState(() {
                _privateAccount = value;
              });
              // TODO: Save private account preference
            },
          ),
          SwitchListTile(
            title: Text('Data Sharing'),
            subtitle: Text('Allow sharing of your data with third parties.'),
            value: _dataSharing,
            onChanged: (value) {
              setState(() {
                _dataSharing = value;
              });
              // TODO: Save data sharing preference
            },
          ),
        ],
      ),
    );
  }
}