import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../providers/bluetooth_provider.dart';

class BluetoothScanPage extends StatelessWidget {
  const BluetoothScanPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Devices')),
      body: Consumer<BluetoothProvider>(
        builder: (context, provider, _) {
          if (provider.connectedDevice != null) {
            return _ConnectedView(provider: provider);
          }
          return _ScanView(provider: provider);
        },
      ),
    );
  }
}

class _ScanView extends StatelessWidget {
  final BluetoothProvider provider;

  const _ScanView({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: provider.isScanning ? provider.stopScan : provider.startScan,
          child: Text(provider.isScanning ? 'Stop Scan' : 'Start Scan'),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: provider.devices.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(provider.devices[index].platformName),
              subtitle: Text(provider.devices[index].remoteId.toString()),
              trailing: ElevatedButton(
                child: const Text('Connect'),
                onPressed: () => provider.connect(provider.devices[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectedView extends StatelessWidget {
  final BluetoothProvider provider;

  const _ConnectedView({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text('Connected to: ${provider.connectedDevice!.platformName}'),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: provider.disconnect,
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: _ServiceList(services: provider.services),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 2,
                child: _DataView(data: provider.receivedData),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceList extends StatelessWidget {
  final List<BluetoothService> services;

  const _ServiceList({required this.services});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: services.length,
      itemBuilder: (context, index) => ExpansionTile(
        title: Text('Service: ${services[index].uuid}'),
        children: services[index].characteristics
            .map((c) => ListTile(
                  title: Text('Characteristic: ${c.uuid}'),
                  subtitle: _getProperties(c),
                  trailing: _getNotificationIcon(c),
                ))
            .toList(),
      ),
    );
  }

  Text _getProperties(BluetoothCharacteristic c) {
    List<String> props = [];
    if (c.properties.read) props.add('Read');
    if (c.properties.write) props.add('Write');
    if (c.properties.notify) props.add('Notify');
    return Text(props.join(', '));
  }

  Widget _getNotificationIcon(BluetoothCharacteristic c) {
    return c.properties.notify
        ? const Icon(Icons.notifications_active, color: Colors.green)
        : const SizedBox.shrink();
  }
}

class _DataView extends StatelessWidget {
  final String data;

  const _DataView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Received Data:', style: TextStyle(fontSize: 18)),
          Expanded(
            child: SingleChildScrollView(
              child: Text(data),
            ),
          ),
        ],
      ),
    );
  }
}