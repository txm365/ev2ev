// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import 'dashboard_page.dart';
import 'marketplace_screen.dart'; // Add marketplace import
import 'transaction_page.dart';
import 'profile_screen.dart';
import '../providers/marketplace_provider.dart';
import '../providers/bluetooth_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late PageController _pageController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  // Pages list with marketplace included
  static final List<Widget> _pages = [
    const DashboardPage(),
    const MarketplaceScreen(), // Add marketplace screen
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
    _pageController = PageController(initialPage: _selectedIndex);
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );

    // Initialize marketplace data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMarketplace();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _initializeMarketplace() {
    final marketplaceProvider = context.read<MarketplaceProvider>();
    marketplaceProvider.getCurrentLocation();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Animate to the selected page
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    // Show/hide FAB based on selected page
    if (index == 1) { // Marketplace page
      _fabAnimationController.forward();
    } else {
      _fabAnimationController.reverse();
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Show/hide FAB based on selected page
    if (index == 1) { // Marketplace page
      _fabAnimationController.forward();
    } else {
      _fabAnimationController.reverse();
    }
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildQuickActionsSheet(),
    );
  }

  Widget _buildQuickActionsSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Action items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildQuickActionItem(
                  icon: Icons.sell,
                  title: 'Create Energy Listing',
                  subtitle: 'Start selling your excess energy',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to marketplace and show create listing dialog
                    setState(() => _selectedIndex = 1);
                    _pageController.animateToPage(1, 
                      duration: const Duration(milliseconds: 300), 
                      curve: Curves.easeInOut);
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickActionItem(
                  icon: Icons.search,
                  title: 'Find Energy Nearby',
                  subtitle: 'Browse available energy providers',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 1);
                    _pageController.animateToPage(1, 
                      duration: const Duration(milliseconds: 300), 
                      curve: Curves.easeInOut);
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickActionItem(
                  icon: Icons.bluetooth,
                  title: 'Connect Device',
                  subtitle: 'Connect to your EV hardware',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 0);
                    _pageController.animateToPage(0, 
                      duration: const Duration(milliseconds: 300), 
                      curve: Curves.easeInOut);
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
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

      // Bottom Navigation Bar with badges
      bottomNavigationBar: Consumer2<MarketplaceProvider, BluetoothProvider>(
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
            child: BottomNavigationBar(
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
                        Icons.warning,
                        size: 10,
                        color: Colors.white,
                      ),
                      badgeStyle: const badges.BadgeStyle(
                        badgeColor: Colors.orange,
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
                    child: _selectedIndex == index ? item.activeIcon : icon,
                  ),
                  label: item.label,
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

// Extension removed as it was unused