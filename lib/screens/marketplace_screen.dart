// lib/screens/marketplace_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/marketplace_provider.dart';
import '../providers/map_provider.dart';
import '../widgets/create_listing_dialog.dart';
import '../widgets/energy_request_dialog.dart';
import '../widgets/listing_card.dart';
import '../widgets/request_card.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../models/energy_listing.dart';
import '../models/energy_request.dart';
import './main_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  MarketplaceScreenState createState() => MarketplaceScreenState();
}

class MarketplaceScreenState extends State<MarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  MarketplaceProvider? _provider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_provider == null) {
      _provider = context.read<MarketplaceProvider>();
      _initializeMarketplace();
    }
  }

  void _initializeMarketplace() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider?.initialize();
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
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              provider.errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
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
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Search and Filter Bar ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          // FIX: was Colors.grey[100] (white-ish, stays white in dark mode)
          color: cs.surfaceContainerHighest,
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by location, vehicle type...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  // FIX: was Colors.white (hardcoded white box in dark mode)
                  fillColor: cs.surface,
                ),
                onChanged: (value) => provider.updateSearchQuery(value),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      'Distance: ${provider.maxDistance.toInt()}km',
                      Icons.location_on,
                      () => _showDistanceFilter(context, provider),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Price: R${provider.maxPrice.toStringAsFixed(1)}/kWh',
                      Icons.attach_money,
                      () => _showPriceFilter(context, provider),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      provider.selectedVehicleType == 'all'
                          ? 'All Vehicles'
                          : provider.selectedVehicleType,
                      Icons.electric_car,
                      () => _showVehicleTypeFilter(context, provider),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Listings List ─────────────────────────────────────────────────
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
                          onTap: () => _showEnergyRequestDialog(
                              context, listing, provider),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // FIX: chip colour now adapts — uses primary from theme instead of fixed AppColors.info
  Widget _buildFilterChip(
      String label, IconData icon, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.primary, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: cs.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyBuyerView(MarketplaceProvider provider) {
    // FIX: was AppColors.textTertiary / textSecondary — hardcoded dark greys
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 64, color: cs.onSurface.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            'No energy listings found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search filters or check back later',
            style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
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
      return _buildCreateListingView(context, provider);
    }
  }

  Widget _buildActiveListingView(MarketplaceProvider provider) {
    final listing = provider.myActiveListing!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header — keeps green/orange intentionally
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
                  listing.status == 'available'
                      ? Icons.check_circle
                      : Icons.pause_circle,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.status == 'available'
                            ? 'Listing Active'
                            : 'Listing Paused',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        listing.status == 'available'
                            ? 'Your energy is available for buyers'
                            : 'Your listing is currently paused',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailColumn('Price per kWh',
                            'R${listing.pricePerKwh.toStringAsFixed(2)}'),
                      ),
                      Expanded(
                        child: _buildDetailColumn('Available Energy',
                            '${listing.availableEnergy.toStringAsFixed(1)} kWh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailColumn('Min Sale',
                            '${listing.minEnergySale.toStringAsFixed(1)} kWh'),
                      ),
                      Expanded(
                        child: _buildDetailColumn('Max Sale',
                            '${listing.maxEnergySale.toStringAsFixed(1)} kWh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailColumn(
                            'Vehicle Type', listing.vehicleType),
                      ),
                      Expanded(
                        child: _buildDetailColumn(
                            'Connector', listing.connectorType),
                      ),
                    ],
                  ),
                  if (listing.description != null &&
                      listing.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.info.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Description:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.info)),
                          const SizedBox(height: 4),
                          Text(listing.description!,
                              style:
                                  const TextStyle(color: AppColors.info)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Received Requests
          if (provider.receivedRequests.isNotEmpty) ...[
            Text(
              'Received Requests (${provider.receivedRequests.length})',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...provider.receivedRequests.map((request) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RequestCard(
                    request: request,
                    isReceived: true,
                    onAccept: () => _handleRequestResponse(
                        context, provider, request.id, 'accepted'),
                    onReject: () => _handleRequestResponse(
                        context, provider, request.id, 'rejected'),
                    onViewOnMap: request.status == 'accepted'
                        ? () => _handleViewOnMap(context, request)
                        : null,
                  ),
                )),
          ] else ...[
            // FIX: was hardcoded AppColors.textTertiary / textSecondary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.inbox,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.4)),
                    const SizedBox(height: 12),
                    Text(
                      'No requests yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Buyers will see your listing and can send requests',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5)),
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
                  onPressed: () => _toggleListingStatus(
                      context, provider, listing.status),
                  icon: Icon(listing.status == 'available'
                      ? Icons.pause
                      : Icons.play_arrow),
                  label: Text(listing.status == 'available'
                      ? 'Pause'
                      : 'Resume'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: listing.status == 'available'
                        ? AppColors.warning
                        : AppColors.success,
                    side: BorderSide(
                      color: listing.status == 'available'
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showEditListingDialog(context, provider, listing),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showDeleteConfirmation(context, provider),
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreateListingView(
      BuildContext context, MarketplaceProvider provider) {
    // FIX: was AppColors.textSecondary (hardcoded dark grey)
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.electric_bolt,
                size: 80, color: AppColors.primaryGreen),
            const SizedBox(height: 24),
            const Text(
              'Start Selling Energy',
              style:
                  TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first energy listing and start earning!\nSet your price, availability, and start earning!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.6),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () =>
                  _showCreateListingDialog(context, provider),
              icon: const Icon(Icons.add),
              label: const Text(AppStrings.createListing),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.help_outline),
              label: const Text('Tips for selling energy'),
            ),
          ],
        ),
      ),
    );
  }

  // FIX: was AppColors.textSecondary (hardcoded dark grey)
  Widget _buildDetailColumn(String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: cs.onSurface.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildMyRequestsTab(MarketplaceProvider provider) {
    // FIX: was AppColors.textTertiary / textSecondary
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () => provider.getMyRequests(),
      child: provider.myRequests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.request_page,
                      size: 64, color: cs.onSurface.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'No requests yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse the Buy Energy tab to request energy from sellers',
                    style:
                        TextStyle(color: cs.onSurface.withOpacity(0.5)),
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
                    onViewOnMap: request.status == 'accepted'
                        ? () => _handleViewOnMap(context, request)
                        : null,
                    onCancel: request.status == 'pending'
                        ? () => _handleCancelRequest(
                            context, provider, request.id)
                        : null,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHistoryTab(MarketplaceProvider provider) {
    // FIX: was AppColors.textTertiary / textSecondary
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () => provider.getMyTransactions(),
      child: provider.myTransactions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history,
                      size: 64, color: cs.onSurface.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'No transaction history',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your completed energy trades will appear here',
                    style:
                        TextStyle(color: cs.onSurface.withOpacity(0.5)),
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
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          transaction.status == 'completed'
                              ? AppColors.success
                              : AppColors.warning,
                      child: Icon(
                        transaction.status == 'completed'
                            ? Icons.check
                            : Icons.hourglass_empty,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      transaction.sellerName ??
                          transaction.buyerName ??
                          'Energy Trade',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Energy: ${transaction.energyTransferred?.toStringAsFixed(1) ?? 0} kWh'),
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
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }

  // ==========================================================================
  // DIALOG AND ACTION METHODS
  // ==========================================================================

  void _showCreateListingDialog(
      BuildContext context, MarketplaceProvider provider) {
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
          if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(AppStrings.listingCreated),
                backgroundColor: AppColors.success,
              ),
            );
            _tabController.animateTo(1);
          }
        },
      ),
    );
  }

  void _showEditListingDialog(BuildContext context,
      MarketplaceProvider provider, EnergyListing listing) {
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
          if (success && context.mounted) {
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

  void _showDeleteConfirmation(
      BuildContext context, MarketplaceProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing'),
        content: const Text(
            'Are you sure you want to delete your energy listing?\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await provider.deleteMyListing();
              if (success && context.mounted) {
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

  Future<void> _toggleListingStatus(BuildContext context,
      MarketplaceProvider provider, String currentStatus) async {
    final newStatus =
        currentStatus == 'available' ? 'paused' : 'available';
    final success = await provider.updateListingStatus(newStatus);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Listing ${newStatus == 'available' ? 'resumed' : 'paused'} successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handleRequestResponse(BuildContext context,
      MarketplaceProvider provider, String requestId,
      String status) async {
    final success =
        await provider.respondToRequest(requestId, status);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request $status successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showEnergyRequestDialog(BuildContext context,
      EnergyListing listing, MarketplaceProvider provider) {
    showDialog(
      context: context,
      builder: (context) => EnergyRequestDialog(
        listing: listing,
        onSubmit: (data) async {
          Navigator.of(context).pop();
          final success = await provider.createEnergyRequest(
            listingId: data['listingId'],
            requestedEnergy: data['requestedEnergy'],
            offeredPricePerKwh: data['offeredPricePerKwh'],
            message: data['message'],
          );
          if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(AppStrings.requestSent),
                backgroundColor: AppColors.success,
              ),
            );
            _tabController.animateTo(2);
          }
        },
      ),
    );
  }

  Future<void> _handleCancelRequest(BuildContext context,
      MarketplaceProvider provider, String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text(
            'Are you sure you want to cancel this energy request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request cancellation feature coming soon'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _handleViewOnMap(
      BuildContext context, EnergyRequest request) async {
    final mapProvider =
        Provider.of<MapProvider>(context, listen: false);
    final marketplaceProvider =
        Provider.of<MarketplaceProvider>(context, listen: false);

    if (request.sellerLocationLat == null ||
        request.sellerLocationLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seller location not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Position? currentPosition = marketplaceProvider.currentPosition;
    if (currentPosition == null) {
      currentPosition =
          await marketplaceProvider.getCurrentLocation();
      if (currentPosition == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not get your current location'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    final buyerLocation = LatLng(
        currentPosition.latitude, currentPosition.longitude);
    final sellerLocation = LatLng(
        request.sellerLocationLat!, request.sellerLocationLng!);

    mapProvider.setRouteFromCoordinates(
      start: buyerLocation,
      end: sellerLocation,
      destinationName: request.sellerName ?? 'Seller',
    );

    if (context.mounted) {
      final mainScreenState =
          context.findAncestorStateOfType<MainScreenState>();
      mainScreenState?.navigateToTab(2);
    }
  }

  // ==========================================================================
  // FILTER DIALOGS
  // ==========================================================================

  void _showDistanceFilter(
      BuildContext context, MarketplaceProvider provider) {
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

  void _showPriceFilter(
      BuildContext context, MarketplaceProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maximum Price'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'R${provider.maxPrice.toStringAsFixed(1)} per kWh'),
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

  void _showVehicleTypeFilter(
      BuildContext context, MarketplaceProvider provider) {
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
          ]
              .map((type) => ListTile(
                    title:
                        Text(type == 'all' ? 'All Vehicles' : type),
                    onTap: () {
                      provider.updateVehicleTypeFilter(type);
                      Navigator.of(context).pop();
                    },
                    trailing: provider.selectedVehicleType == type
                        ? const Icon(Icons.check,
                            color: AppColors.success)
                        : null,
                  ))
              .toList(),
        ),
      ),
    );
  }
}