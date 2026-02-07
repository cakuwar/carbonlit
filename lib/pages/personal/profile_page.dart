import 'package:flutter/material.dart';
import 'edit_profile_page.dart';
import 'security_page.dart';
import 'notifications_page.dart';
import 'privacy_page.dart';
import 'subscription_page.dart';
import 'help_support_page.dart';
import 'terms_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _navigateToEditProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditProfilePage()),
    );
  }

  void _navigateToSecurity(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SecurityPage()),
    );
  }

  void _navigateToNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NotificationsPage()),
    );
  }

  void _navigateToPrivacy(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PrivacyPage()),
    );
  }

  void _navigateToSubscription(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SubscriptionPage()),
    );
  }

  void _navigateToHelpSupport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HelpSupportPage()),
    );
  }

  void _navigateToTermsPolicies(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TermsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF115925),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Profile Page', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF115925),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: AssetImage('assets/images/profile.png'),
                    backgroundColor: const Color.fromRGBO(241, 239, 239, 1),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Naravit',
                    style: TextStyle(
                      color: const Color.fromRGBO(241, 239, 239, 1),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4B4B4B),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit profile'),
                    onTap: () => _navigateToEditProfile(context),
                  ),
                  ListTile(
                    leading: Icon(Icons.security),
                    title: Text('Security'),
                    onTap: () => _navigateToSecurity(context),
                  ),
                  ListTile(
                    leading: Icon(Icons.notifications),
                    title: Text('Notifications'),
                    onTap: () => _navigateToNotifications(context),
                  ),
                  ListTile(
                    leading: Icon(Icons.privacy_tip),
                    title: Text('Privacy'),
                    onTap: () => _navigateToPrivacy(context),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Support & About',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4B4B4B),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.subscriptions),
                    title: Text('My Subscription'),
                    onTap: () => _navigateToSubscription(context),
                  ),
                  ListTile(
                    leading: Icon(Icons.help),
                    title: Text('Help & Support'),
                    onTap: () => _navigateToHelpSupport(context),
                  ),
                  ListTile(
                    leading: Icon(Icons.policy),
                    title: Text('Terms and Policies'),
                    onTap: () => _navigateToTermsPolicies(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}