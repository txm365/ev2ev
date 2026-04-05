// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;

import './dashboard_page.dart';
import './marketplace_screen.dart';
import './map_page.dart';
import './profile_screen.dart';
import './wallet_screen.dart';
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

  // Cache provider references so dispose() never touches context
  bt.BluetoothProvider? _bluetoothProvider;
  mp.MarketplaceProvider? _marketplaceProvider;

  bool _hasShownConnectionSuccessDialog = false;

  static final List<Widget> _pages = [
    const DashboardPage(),
    const MarketplaceScreen(),
    const MapPage(),
    const WalletScreen(),
    const ProfileScreen(),
  ];

  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.store_outlined),
      activeIcon: Icon(Icons.store),
      label: 'Marketplace',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.map_outlined),
      activeIcon: Icon(Icons.map),
      label: 'Map',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.account_balance_wallet_outlined),
      activeIcon: Icon(Icons.account_balance_wallet),
      label: 'Wallet',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
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
    // Overlay toast — floats above everything, not tied to any Scaffold
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => _ConnectionToast(
        onDashboard: () => _onItemTapped(0),
      ),
    );
    overlay.insert(entry);
    // Auto-remove after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

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

  /// Public — lets child screens switch tabs via mainScreenKey
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

              // Badge on Marketplace tab for pending received requests
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

// ── Overlay toast widget ───────────────────────────────────────────────────
// Renders directly on the Overlay stack so it appears above every tab/page
// without going through ScaffoldMessenger.
class _ConnectionToast extends StatefulWidget {
  final VoidCallback onDashboard;
  const _ConnectionToast({required this.onDashboard});

  @override
  State<_ConnectionToast> createState() => _ConnectionToastState();
}

class _ConnectionToastState extends State<_ConnectionToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPad + 12,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth_connected,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'EV connected successfully',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onDashboard,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Dashboard',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}