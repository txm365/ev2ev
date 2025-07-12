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
import '../providers/bluetooth_provider.dart';
import '../widgets/create_listing_dialog.dart';

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
                  onTap: () => _handleCreateListing(),
                ),
                const SizedBox(height: 12),
                _buildQuickActionItem(
                  icon: Icons.search,
                  title: 'Find Energy Nearby',
                  subtitle: 'Browse available energy providers',
                  color: Colors.blue,
                  onTap: () => _handleFindEnergy(),
                ),
                const SizedBox(height: 12),
                _buildQuickActionItem(
                  icon: Icons.bluetooth,
                  title: 'Connect Device',
                  subtitle: 'Connect to your EV hardware',
                  color: Colors.orange,
                  onTap: () => _handleConnectDevice(),
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

  // Quick action handlers
  void _handleCreateListing() {
    Navigator.pop(context); // Close bottom sheet
    
    final marketplaceProvider = context.read<MarketplaceProvider>();
    
    // Check if user already has an active listing
    if (marketplaceProvider.myActiveListing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have an active listing. Delete it first to create a new one.'),
          backgroundColor: Colors.orange,
        ),
      );
      // Navigate to marketplace to show existing listing
      setState(() => _selectedIndex = 1);
      _pageController.animateToPage(1, 
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeInOut);
      return;
    }

    // Show create listing dialog
    showDialog(
      context: context,
      builder: (context) => CreateListingDialog(
        onSubmit: (data) async {
          Navigator.of(context).pop();
          
          // Show loading indicator
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );

          final success = await marketplaceProvider.createEnergyListing(
            pricePerKwh: data['pricePerKwh'],
            availableEnergy: data['availableEnergy'],
            minEnergySale: data['minEnergySale'],
            maxEnergySale: data['maxEnergySale'],
            vehicleType: data['vehicleType'],
            connectorType: data['connectorType'],
            availabilityEnd: data['availabilityEnd'],
            description: data['description'],
          );

          // Close loading indicator
          Navigator.of(context).pop();

          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Energy listing created successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Navigate to marketplace sell tab
            setState(() => _selectedIndex = 1);
            _pageController.animateToPage(1, 
              duration: const Duration(milliseconds: 300), 
              curve: Curves.easeInOut);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to create listing: ${marketplaceProvider.errorMessage ?? "Unknown error"}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  void _handleFindEnergy() {
    Navigator.pop(context); // Close bottom sheet
    
    // Navigate to marketplace buy tab
    setState(() => _selectedIndex = 1);
    _pageController.animateToPage(1, 
      duration: const Duration(milliseconds: 300), 
      curve: Curves.easeInOut);

    // Refresh nearby listings
    final marketplaceProvider = context.read<MarketplaceProvider>();
    marketplaceProvider.getNearbyListings();
  }

  void _handleConnectDevice() {
    Navigator.pop(context); // Close bottom sheet
    
    final bluetoothProvider = context.read<BluetoothProvider>();
    
    if (bluetoothProvider.isConnected) {
      // If already connected, show option to disconnect or go to dashboard
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Device Connected'),
          content: Text('Already connected to ${bluetoothProvider.connectedDevice?.platformName ?? "device"}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                bluetoothProvider.disconnect();
              },
              child: const Text('Disconnect'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _selectedIndex = 0);
                _pageController.animateToPage(0, 
                  duration: const Duration(milliseconds: 300), 
                  curve: Curves.easeInOut);
              },
              child: const Text('View Dashboard'),
            ),
          ],
        ),
      );
    } else {
      // Navigate to Bluetooth scan page
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

      // Bottom Navigation Bar with badges
      bottomNavigationBar: Consumer2<MarketplaceProvider, BluetoothProvider>(
        builder: (context, marketplaceProvider, bluetoothProvider, child) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
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
                          ? Colors.blue.withOpacity(0.1) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: icon,
                  ),
                  activeIcon: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
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