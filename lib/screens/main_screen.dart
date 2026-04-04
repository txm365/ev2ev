// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;

import './dashboard_page.dart';
import './marketplace_screen.dart';
import './map_page.dart';
import './profile_screen.dart';
import '../providers/marketplace_provider.dart' as mp;
import '../providers/bluetooth_provider.dart' as bt;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;
  late PageController _pageController;

  // ── Cache provider references so dispose() never touches context ──
  bt.BluetoothProvider? _bluetoothProvider;
  mp.MarketplaceProvider? _marketplaceProvider;

  bool _hasShownConnectionSuccessDialog = false;

  static final List<Widget> _pages = [
    const DashboardPage(),
    const MarketplaceScreen(),
    const MapPage(),
    const ProfileScreen(),
  ];

  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard),
      activeIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.store),
      activeIcon: Icon(Icons.store),
      label: 'Marketplace',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.map),
      activeIcon: Icon(Icons.map),
      label: 'Map',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _selectedIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bluetoothProvider =
          Provider.of<bt.BluetoothProvider>(context, listen: false);
      _marketplaceProvider =
          Provider.of<mp.MarketplaceProvider>(context, listen: false);

      _bluetoothProvider?.initialize();
      _bluetoothProvider?.addListener(_handleBluetoothStateChanges);
    });
  }

  void _handleBluetoothStateChanges() {
    if (!mounted || _bluetoothProvider == null) return;

    if (_bluetoothProvider!.isConnected &&
        !_hasShownConnectionSuccessDialog &&
        _selectedIndex != 0) {
      _hasShownConnectionSuccessDialog = true;
      _showConnectionSuccessDialog();
    }

    if (!_bluetoothProvider!.isConnected) {
      _hasShownConnectionSuccessDialog = false;
    }
  }

  void _showConnectionSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'Connected Successfully',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
          'Your EV is now connected and ready for energy trading. '
          'You can view real-time data on the Dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _onItemTapped(0);
            },
            child: const Text('View Dashboard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── dispose() only uses cached references — context is never touched ──
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _bluetoothProvider?.removeListener(_handleBluetoothStateChanges);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _selectedIndex == 1) {
      _marketplaceProvider?.refreshAll();
    }
  }

  /// Public method so child screens can switch tabs without importing main_screen.dart
  void navigateToTab(int index) => _onItemTapped(index);

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _pages,
      ),
      bottomNavigationBar: Consumer2<bt.BluetoothProvider,
          mp.MarketplaceProvider>(
        builder: (context, bluetoothProvider, marketplaceProvider, child) {
          final pendingRequestsCount = marketplaceProvider.receivedRequests
              .where((r) => r.status == 'pending')
              .length;

          return BottomNavigationBar(
            items: _navItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              if (index == 1 && pendingRequestsCount > 0) {
                return BottomNavigationBarItem(
                  icon: badges.Badge(
                    badgeContent: Text(
                      pendingRequestsCount.toString(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10),
                    ),
                    child: item.icon,
                  ),
                  activeIcon: badges.Badge(
                    badgeContent: Text(
                      pendingRequestsCount.toString(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10),
                    ),
                    child: item.activeIcon,
                  ),
                  label: item.label,
                );
              }

              return item;
            }).toList(),
            currentIndex: _selectedIndex,
            selectedItemColor: cs.primary,
            unselectedItemColor: cs.onSurface.withValues(alpha: 0.5),
            type: BottomNavigationBarType.fixed,
            onTap: _onItemTapped,
          );
        },
      ),
    );
  }
}