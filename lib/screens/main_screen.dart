// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import 'dashboard_page.dart';
import 'marketplace_screen.dart';
import 'transaction_page.dart';
import 'profile_screen.dart';
import 'bluetooth_scan_page.dart';
import '../providers/marketplace_provider.dart';
import '../providers/bluetooth_provider.dart' as bt;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;
  late PageController _pageController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  
  // Auto-routing state
  bool _hasShownConnectionSuccessDialog = false;

  // Pages list with marketplace included
  static final List<Widget> _pages = [
    const DashboardPage(),
    const MarketplaceScreen(),
    const TransactionPage(),
    const ProfileScreen(),
  ];

  // Navigation items with marketplace
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
      icon: Icon(Icons.swap_horiz),
      activeIcon: Icon(Icons.swap_horiz),
      label: 'Transactions',
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
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );

    // Initialize Bluetooth provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bluetoothProvider = Provider.of<bt.BluetoothProvider>(context, listen: false);
      bluetoothProvider.initialize();
      
      // Listen for auto-routing conditions
      bluetoothProvider.addListener(_handleBluetoothStateChanges);
    });

    _updateFabVisibility();
  }

  void _handleBluetoothStateChanges() {
    if (!mounted) return;
    
    final bluetoothProvider = Provider.of<bt.BluetoothProvider>(context, listen: false);
    
    // Check if we should auto-route to dashboard
    if (bluetoothProvider.shouldAutoRouteToDashboard() && 
        !_hasShownConnectionSuccessDialog &&
        _selectedIndex != 0) {
      
      _hasShownConnectionSuccessDialog = true;
      
      // Show success notification and auto-navigate
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showConnectionSuccessAndNavigate(bluetoothProvider);
        }
      });
    }
    
    // Reset the flag if connection is lost
    if (!bluetoothProvider.isConnected) {
      _hasShownConnectionSuccessDialog = false;
    }
  }

  void _showConnectionSuccessAndNavigate(bt.BluetoothProvider bluetoothProvider) {
    if (!mounted) return;
    
    // Show a brief success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Device Connected Successfully!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Connected to ${bluetoothProvider.connectedDevice?.platformName ?? "device"}'),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () => _navigateToDashboard(),
        ),
      ),
    );
    
    // Auto-navigate to dashboard after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _selectedIndex != 0) {
        _navigateToDashboard();
      }
    });
  }

  void _navigateToDashboard() {
    if (!mounted) return;
    
    setState(() => _selectedIndex = 0);
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed && mounted) {
      // App returned to foreground, check for auto-reconnection
      final bluetoothProvider = Provider.of<bt.BluetoothProvider>(context, listen: false);
      if (!bluetoothProvider.isConnected && bluetoothProvider.autoConnectionEnabled) {
        bluetoothProvider.attemptAutoReconnect();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (mounted) {
      final bluetoothProvider = Provider.of<bt.BluetoothProvider>(context, listen: false);
      bluetoothProvider.removeListener(_handleBluetoothStateChanges);
    }
    
    _pageController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _updateFabVisibility();
    }
  }

  void _onPageChanged(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
      _updateFabVisibility();
    }
  }

  void _updateFabVisibility() {
    if (_selectedIndex == 1) { // Marketplace page
      _fabAnimationController.forward();
    } else {
      _fabAnimationController.reverse();
    }
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Add your quick action buttons here
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Create Listing'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBluetoothActions(bt.BluetoothProvider bluetoothProvider) {
    if (bluetoothProvider.isConnected) {
      // Show connected device dialog with options
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bluetooth Device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text('Connected to:'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                bluetoothProvider.connectedDevice!.platformName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (bluetoothProvider.isDataStreaming) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stream, size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Data Streaming',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'Vehicle: ${bluetoothProvider.vehicleName}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                try {
                  await bluetoothProvider.disconnect();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Device disconnected successfully'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Disconnect failed: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    
                    // Try force disconnect if normal disconnect fails
                    try {
                      await bluetoothProvider.forceDisconnect();
                    } catch (forceError) {
                      debugPrint('Force disconnect also failed: $forceError');
                    }
                  }
                }
              },
              child: const Text('Disconnect'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BluetoothScanPage()),
                );
              },
              child: const Text('Manage'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToDashboard();
              },
              child: const Text('View Dashboard'),
            ),
          ],
        ),
      );
    } else {
      // Navigate to Bluetooth scan page with auto-features
      bluetoothProvider.resetUserDisconnectFlag();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BluetoothScanPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _pages,
      ),
      
      // Floating Action Button (shows only on marketplace page)
      floatingActionButton: AnimatedBuilder(
        animation: _fabAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabAnimation.value,
            child: _fabAnimation.value > 0
                ? FloatingActionButton.extended(
                    onPressed: _showQuickActions,
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add),
                    label: const Text('Quick Actions'),
                    elevation: 4,
                  )
                : const SizedBox.shrink(),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      // Bottom Navigation Bar with enhanced badges and connection status
      bottomNavigationBar: Consumer2<MarketplaceProvider, bt.BluetoothProvider>(
        builder: (context, marketplaceProvider, bluetoothProvider, child) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bluetooth Connection Status Bar
                if (bluetoothProvider.isConnected && bluetoothProvider.isDataStreaming)
                  _buildConnectionStatusBar(bluetoothProvider),
                
                BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  selectedItemColor: Colors.blue,
                  unselectedItemColor: Colors.grey[600],
                  selectedFontSize: 12,
                  unselectedFontSize: 12,
                  items: _navItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    
                    Widget icon = item.icon;
                    
                    // Add badges for specific tabs
                    if (index == 1) { // Marketplace tab
                      final hasNewRequests = marketplaceProvider.receivedRequests
                          .where((r) => r.status == 'pending').length;
                      if (hasNewRequests > 0) {
                        icon = badges.Badge(
                          badgeContent: Text(
                            hasNewRequests.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                          badgeStyle: const badges.BadgeStyle(
                            badgeColor: Colors.red,
                            padding: EdgeInsets.all(4),
                          ),
                          child: item.icon,
                        );
                      }
                    } else if (index == 0) { // Dashboard tab
                      if (!bluetoothProvider.isConnected) {
                        icon = badges.Badge(
                          badgeContent: const Icon(
                            Icons.bluetooth_disabled,
                            size: 8,
                            color: Colors.white,
                          ),
                          badgeStyle: const badges.BadgeStyle(
                            badgeColor: Colors.orange,
                            padding: EdgeInsets.all(2),
                          ),
                          child: item.icon,
                        );
                      } else if (bluetoothProvider.isDataStreaming) {
                        icon = badges.Badge(
                          badgeContent: const Icon(
                            Icons.stream,
                            size: 8,
                            color: Colors.white,
                          ),
                          badgeStyle: const badges.BadgeStyle(
                            badgeColor: Colors.green,
                            padding: EdgeInsets.all(2),
                          ),
                          child: item.icon,
                        );
                      }
                    }
                    
                    return BottomNavigationBarItem(
                      icon: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.all(_selectedIndex == index ? 8 : 4),
                        decoration: BoxDecoration(
                          color: _selectedIndex == index 
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: icon,
                      ),
                      activeIcon: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: icon,
                      ),
                      label: item.label!,
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatusBar(bt.BluetoothProvider bluetoothProvider) {
    return GestureDetector(
      onTap: () => _showBluetoothActions(bluetoothProvider),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.green.shade50,
        child: Row(
          children: [
            Icon(
              Icons.bluetooth_connected,
              size: 16,
              color: Colors.green.shade700,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Connected to ${bluetoothProvider.connectedDevice?.platformName ?? "device"}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (bluetoothProvider.isDataStreaming) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'STREAMING',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.keyboard_arrow_up,
              size: 16,
              color: Colors.green.shade700,
            ),
          ],
        ),
      ),
    );
  }
}