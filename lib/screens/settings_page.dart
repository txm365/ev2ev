import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vehicle_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  String _vehicleType = 'car';
  
  final List<Map<String, dynamic>> _vehicleTypes = [
    {'value': 'car', 'label': 'Car', 'icon': Icons.directions_car},
    {'value': 'ebike', 'label': 'E-Bike', 'icon': Icons.electric_bike},
    {'value': 'scooter', 'label': 'Scooter', 'icon': Icons.electric_scooter},
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final settings = Provider.of<VehicleSettings>(context, listen: false);
    await settings.loadSettings();
    if (mounted) {
      setState(() {
        _nameController.text = settings.name;
        _modelController.text = settings.model;
        _vehicleType = settings.type;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final settings = Provider.of<VehicleSettings>(context, listen: false);
        await settings.saveSettings(
          name: _nameController.text.trim(),
          model: _modelController.text.trim(),
          type: _vehicleType,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings saved successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving settings: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Settings'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Name',
                  prefixIcon: Icon(Icons.car_rental),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Model',
                  prefixIcon: Icon(Icons.model_training),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 30),
              const Text(
                'Select Vehicle Type:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.8,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: _vehicleTypes.length,
                itemBuilder: (context, index) {
                  final type = _vehicleTypes[index];
                  return GestureDetector(
                    onTap: () => setState(() => _vehicleType = type['value']),
                    child: Card(
                      elevation: 2,
                      color: _vehicleType == type['value']
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(type['icon'], 
                                size: 32, 
                                color: _vehicleType == type['value']
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              type['label'],
                              style: TextStyle(
                                color: _vehicleType == type['value']
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save Settings'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _saveSettings,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}