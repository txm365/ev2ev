import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isEditing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _nameController.text = response?['first_name'] ?? 
                user.email?.split('@').first ?? 'User';
            _emailController.text = response?['email'] ?? user.email ?? '';
            _isLoading = false;
          });
          
          if (response == null) {
            await _createInitialProfile(user);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _nameController.text = user.email?.split('@').first ?? 'User';
            _emailController.text = user.email ?? '';
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _createInitialProfile(User user) async {
    await Supabase.instance.client.from('profiles').upsert({
      'user_id': user.id,
      'first_name': user.email?.split('@').first,
      'email': user.email,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      setState(() => _isLoading = true);
      final user = Supabase.instance.client.auth.currentUser!;
      
      await Supabase.instance.client.from('profiles').upsert({
        'user_id': user.id,
        'first_name': _nameController.text,
        'email': _emailController.text,
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      setState(() => _isEditing = false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () => _isEditing ? _saveProfile() : setState(() => _isEditing = true),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                child: Text(
                  _nameController.text.isNotEmpty 
                      ? _nameController.text[0] 
                      : '?',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                enabled: _isEditing,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                enabled: _isEditing,
                validator: (value) => 
                    value!.contains('@') ? null : 'Invalid email',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}