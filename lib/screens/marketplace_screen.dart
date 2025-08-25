// lib/screens/marketplace_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/create_listing_dialog.dart';
import '../widgets/energy_request_dialog.dart';
import '../widgets/listing_card.dart';
import '../widgets/request_card.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  MarketplaceScreenState createState() => MarketplaceScreenState();
}

class MarketplaceScreenState extends State<MarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Initialize marketplace data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final marketplaceProvider = context.read<MarketplaceProvider>();
      marketplaceProvider.initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.marketplace),
        elevation: 2,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.textOnPrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_cart), text: AppStrings.buyEnergy),
            Tab(icon: Icon(Icons.sell), text: AppStrings.sellEnergy),
            Tab(icon: Icon(Icons.request_page), text: AppStrings.myRequests),
            Tab(icon: Icon(Icons.history), text: AppStrings.history),
          ],
        ),
        actions: [
          Consumer<MarketplaceProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => provider.refreshAll(),
                tooltip: AppStrings.refresh,
              );
            },
          ),
        ],
      ),
      body: Consumer<MarketplaceProvider>(
        builder: (context, provider, child) {
          if (provider.errorMessage != null) {
            return _buildErrorView(provider);
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildBuyEnergyTab(provider),
              _buildSellEnergyTab(provider),
              _buildMyRequestsTab(provider),
              _buildHistoryTab(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorView(MarketplaceProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              provider.errorMessage!,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              provider.clearError();
              provider.refreshAll();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyEnergyTab(MarketplaceProvider provider) {
    return Column(
      children: [
        // Search and Filter Bar
        _buildSearchAndFilterBar(provider),
        
        // Listings
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => provider.getNearbyListings(),
            child: provider.nearbyListings.isEmpty
                ? _buildEmptyBuyerView(provider)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.nearbyListings.length,
                    itemBuilder: (context, index) {
                      final listing = provider.nearbyListings[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ListingCard(
                          listing: listing,
                          onTap: () => _showEnergyRequestDialog(context, listing),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilterBar(MarketplaceProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            onChanged: provider.updateSearchQuery,
            decoration: InputDecoration(
              hintText: 'Search by location, vehicle type, or seller...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: provider.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => provider.updateSearchQuery(''),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
          const SizedBox(height: 12),
          
          // Quick Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'Distance: ${provider.maxDistance.toInt()}km',
                  onTap: () => _showDistanceFilter(provider),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Max Price: R${provider.maxPrice.toStringAsFixed(1)}',
                  onTap: () => _showPriceFilter(provider),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  provider.selectedVehicleType == 'all' 
                      ? 'All Vehicles' 
                      : provider.selectedVehicleType,
                  onTap: () => _showVehicleTypeFilter(provider),
                ),
                const SizedBox(width: 8),
                if (provider.searchQuery.isNotEmpty || 
                    provider.selectedVehicleType != 'all' ||
                    provider.maxDistance != 10.0 ||
                    provider.maxPrice != 5.0)
                  _buildFilterChip(
                    'Clear Filters',
                    isAction: true,
                    onTap: provider.clearFilters,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {bool isAction = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isAction ? AppColors.warning.withOpacity(0.1) : AppColors.info.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAction ? AppColors.warning : AppColors.info,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isAction ? AppColors.warning : AppColors.info,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyBuyerView(MarketplaceProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            'No energy listings found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search filters or check back later',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              provider.clearFilters();
              provider.getNearbyListings();
            },
            icon: const Icon(Icons.refresh),
            label: const Text(AppStrings.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildSellEnergyTab(MarketplaceProvider provider) {
    if (provider.myActiveListing != null) {
      return _buildActiveListingView(provider);
    } else {
      return _buildCreateListingView(provider);
    }
  }

  Widget _buildActiveListingView(MarketplaceProvider provider) {
    final listing = provider.myActiveListing!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: listing.status == 'available' 
                  ? AppColors.energyAvailable
                  : AppColors.energyPaused,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  listing.status == 'available' ? Icons.check_circle : Icons.pause_circle,
                  color: AppColors.textOnPrimary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your energy listing is ${listing.status.toUpperCase()}',
                        style: const TextStyle(
                          color: AppColors.textOnPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        listing.status == 'available' 
                            ? 'Buyers can see and request your energy'
                            : 'Your listing is paused and not visible to buyers',
                        style: const TextStyle(
                          color: AppColors.textOnPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Listing Details Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Listing Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showEditListingDialog(context, provider, listing),
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit listing',
                      ),
                    ],
                  ),
                  const Divider(),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailColumn(
                          AppStrings.pricePerKwh, 
                          'R${listing.pricePerKwh.toStringAsFixed(2)}'
                        ),
                      ),
                      Expanded(
                        child: _buildDetailColumn(
                          AppStrings.availableEnergy, 
                          '${listing.availableEnergy.toStringAsFixed(1)} kWh'
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailColumn(
                          AppStrings.minimumSale, 
                          '${listing.minEnergySale.toStringAsFixed(1)} kWh'
                        ),
                      ),
                      Expanded(
                        child: _buildDetailColumn(
                          AppStrings.maximumSale, 
                          '${listing.maxEnergySale.toStringAsFixed(1)} kWh'
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailColumn(AppStrings.vehicleType, listing.vehicleType),
                      ),
                      Expanded(
                        child: _buildDetailColumn(AppStrings.connectorType, listing.connectorType),
                      ),
                    ],
                  ),
                  
                  if (listing.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.info.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Description:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.info,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            listing.description!,
                            style: const TextStyle(color: AppColors.info),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Received Requests Section
          if (provider.receivedRequests.isNotEmpty) ...[
            Text(
              'Received Requests (${provider.receivedRequests.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...provider.receivedRequests.map((request) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RequestCard(
                request: request,
                isReceived: true,
                onAccept: () => _handleRequestResponse(provider, request.id, 'accepted'),
                onReject: () => _handleRequestResponse(provider, request.id, 'rejected'),
              ),
            )),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 48, color: AppColors.textTertiary),
                    const SizedBox(height: 12),
                    Text(
                      'No requests yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Buyers will see your listing and can send requests',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _toggleListingStatus(provider, listing.status),
                  icon: Icon(listing.status == 'available' ? Icons.pause : Icons.play_arrow),
                  label: Text(listing.status == 'available' ? 'Pause Listing' : 'Resume Listing'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showDeleteConfirmation(context, provider),
                  icon: const Icon(Icons.delete),
                  label: const Text(AppStrings.delete),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreateListingView(MarketplaceProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sell, 
              size: 64, 
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Start selling your energy',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Create a listing to let buyers know you have energy to share. Set your price, availability, and start earning!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showCreateListingDialog(context, provider),
            icon: const Icon(Icons.add),
            label: const Text(AppStrings.createListing),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              // Show tips dialog or navigate to help
            },
            icon: const Icon(Icons.help_outline),
            label: const Text('Tips for selling energy'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildMyRequestsTab(MarketplaceProvider provider) {
    return RefreshIndicator(
      onRefresh: () => provider.getMyRequests(),
      child: provider.myRequests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.request_page, size: 64, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'No requests yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse the Buy Energy tab to request energy from sellers',
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _tabController.animateTo(0),
                    child: const Text('Browse Energy'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.myRequests.length,
              itemBuilder: (context, index) {
                final request = provider.myRequests[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RequestCard(
                    request: request,
                    isReceived: false,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHistoryTab(MarketplaceProvider provider) {
    return RefreshIndicator(
      onRefresh: () => provider.getMyTransactions(),
      child: provider.myTransactions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'No transaction history',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your completed energy trades will appear here',
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.myTransactions.length,
              itemBuilder: (context, index) {
                final transaction = provider.myTransactions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: transaction.status == 'completed' 
                          ? AppColors.success.withOpacity(0.2)
                          : AppColors.warning.withOpacity(0.2),
                      child: Icon(
                        transaction.status == 'completed' 
                            ? Icons.check 
                            : Icons.pending,
                        color: transaction.status == 'completed' 
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                    title: const Text('Energy Trade'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${transaction.energyTransferred?.toStringAsFixed(1) ?? 0} kWh'),
                        Text(
                          transaction.status.toUpperCase(),
                          style: TextStyle(
                            color: transaction.status == 'completed' 
                                ? AppColors.success
                                : AppColors.warning,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: transaction.totalAmount != null
                        ? Text(
                            'R${transaction.totalAmount!.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }

  // Dialog and Action Methods
  void _showCreateListingDialog(BuildContext context, MarketplaceProvider provider) {
    showDialog(
      context: context,
      builder: (context) => CreateListingDialog(
        onSubmit: (data) async {
          Navigator.of(context).pop();
          
          final success = await provider.createEnergyListing(
            pricePerKwh: data['pricePerKwh'],
            availableEnergy: data['availableEnergy'],
            minEnergySale: data['minEnergySale'],
            maxEnergySale: data['maxEnergySale'],
            vehicleType: data['vehicleType'],
            connectorType: data['connectorType'],
            availabilityEnd: data['availabilityEnd'],
            description: data['description'],
          );

          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(AppStrings.listingCreated),
                backgroundColor: AppColors.success,
              ),
            );
            _tabController.animateTo(1); // Switch to sell tab
          }
        },
      ),
    );
  }

  void _showEditListingDialog(BuildContext context, MarketplaceProvider provider, listing) {
    showDialog(
      context: context,
      builder: (context) => CreateListingDialog(
        onSubmit: (data) async {
          Navigator.of(context).pop();
          
          final success = await provider.updateEnergyListing(
            listingId: listing.id,
            pricePerKwh: data['pricePerKwh'],
            availableEnergy: data['availableEnergy'],
            minEnergySale: data['minEnergySale'],
            maxEnergySale: data['maxEnergySale'],
            vehicleType: data['vehicleType'],
            connectorType: data['connectorType'],
            availabilityEnd: data['availabilityEnd'],
            description: data['description'],
          );

          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(AppStrings.listingUpdated),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, MarketplaceProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing'),
        content: const Text(
          'Are you sure you want to delete your energy listing? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              final success = await provider.deleteMyListing();
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(AppStrings.listingDeleted),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textOnPrimary,
            ),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleListingStatus(MarketplaceProvider provider, String currentStatus) async {
    final newStatus = currentStatus == 'available' ? 'paused' : 'available';
    final success = await provider.updateListingStatus(newStatus);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Listing ${newStatus == 'available' ? 'resumed' : 'paused'} successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handleRequestResponse(MarketplaceProvider provider, String requestId, String status) async {
    final success = await provider.respondToRequest(requestId, status);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request $status successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showEnergyRequestDialog(BuildContext context, listing) {
    showDialog(
      context: context,
      builder: (context) => EnergyRequestDialog(
        listing: listing,
        onSubmit: (data) async {
          Navigator.of(context).pop();
          
          final provider = context.read<MarketplaceProvider>();
          final success = await provider.createEnergyRequest(
            listingId: data['listingId'],
            requestedEnergy: data['requestedEnergy'],
            offeredPricePerKwh: data['offeredPricePerKwh'],
            message: data['message'],
          );

          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(AppStrings.requestSent),
                backgroundColor: AppColors.success,
              ),
            );
            _tabController.animateTo(2); // Switch to My Requests tab
          }
        },
      ),
    );
  }

  void _showDistanceFilter(MarketplaceProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Distance'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${provider.maxDistance.toInt()} km'),
                Slider(
                  value: provider.maxDistance,
                  min: 1.0,
                  max: 50.0,
                  divisions: 49,
                  onChanged: (value) {
                    setState(() {});
                    provider.updateDistanceFilter(value);
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showPriceFilter(MarketplaceProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maximum Price'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('R${provider.maxPrice.toStringAsFixed(1)} per kWh'),
                Slider(
                  value: provider.maxPrice,
                  min: 0.5,
                  max: 10.0,
                  divisions: 95,
                  onChanged: (value) {
                    setState(() {});
                    provider.updatePriceFilter(value);
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showVehicleTypeFilter(MarketplaceProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vehicle Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            'all',
            'Electric Car',
            'Electric Van',
            'Electric Truck',
            'Electric Bus',
          ].map((type) => ListTile(
            title: Text(type == 'all' ? 'All Vehicles' : type),
            onTap: () {
              provider.updateVehicleTypeFilter(type);
              Navigator.of(context).pop();
            },
            trailing: provider.selectedVehicleType == type 
                ? const Icon(Icons.check, color: AppColors.success)
                : null,
          )).toList(),
        ),
      ),
    );
  }
}