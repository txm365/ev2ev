import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  final Map<String, String> profileData = {};
  bool isEditing = false;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  void _loadProfileData() {
    setState(() {
      profileData.addAll({
        'name': 'John Doe',
        'email': 'john@example.com',
        'phone': '+1 555 123 4567',
        'location': 'San Francisco, CA'
      });
      nameController.text = profileData['name']!;
      emailController.text = profileData['email']!;
      phoneController.text = profileData['phone']!;
      locationController.text = profileData['location']!;
    });
  }

  void _saveProfileData() {
    setState(() {
      profileData
        ..['name'] = nameController.text
        ..['email'] = emailController.text
        ..['phone'] = phoneController.text
        ..['location'] = locationController.text;
      isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.check : Icons.edit),
            onPressed: () => setState(() => isEditing ? _saveProfileData() : isEditing = !isEditing),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 40)),
            _buildEditableField('Name', nameController),
            _buildEditableField('Email', emailController),
            _buildEditableField('Phone', phoneController),
            _buildEditableField('Location', locationController),
            if (!isEditing) ...[
              const ListTile(
                leading: Icon(Icons.history),
                title: Text('Transaction History'),
              ),
              const ListTile(
                leading: Icon(Icons.payment),
                title: Text('Payment Methods'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller) {
    return isEditing
        ? TextFormField(
            controller: controller,
            decoration: InputDecoration(labelText: label),
          )
        : ListTile(
            leading: Icon(_getIconForLabel(label)),
            title: Text(controller.text),
          );
  }

  IconData _getIconForLabel(String label) {
    switch (label) {
      case 'Name': return Icons.person;
      case 'Email': return Icons.email;
      case 'Phone': return Icons.phone;
      default: return Icons.location_on;
    }
  }
}