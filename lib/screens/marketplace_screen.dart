// lib/screens/marketplace_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
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
import '../main.dart' show mainScreenKey;
import 'package:url_launcher/url_launcher.dart';

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
        // colours inherited from appBarTheme in app_themes.dart
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
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: provider.nearbyListings.length,
                    itemBuilder: (context, index) {
                      final listing = provider.nearbyListings[index];
                      return Padding(
                        padding: EdgeInsets.zero,
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
          color: cs.primary.withValues(alpha: 0.12),
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
              size: 64, color: cs.onSurface.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'No energy listings found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search filters or check back later',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
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
    final cs = Theme.of(context).colorScheme;
    final isAvailable = listing.status == 'available';
    final statusColor = isAvailable ? const Color(0xFF2E7D32) : const Color(0xFFE65100);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── My Listing card ────────────────────────────────────────────────
          Card(
            elevation: 2,
            shadowColor: statusColor.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Accent bar
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor, statusColor.withValues(alpha: 0.4)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: statusColor.withValues(alpha: 0.12),
                            child: Icon(
                              isAvailable ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                              color: statusColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAvailable ? 'Listing Active' : 'Listing Paused',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  isAvailable
                                      ? 'Your energy is visible to buyers'
                                      : 'Hidden from buyers',
                                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              isAvailable ? 'Live' : 'Paused',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Stats row
                      Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              _listingStatTile(context, Icons.bolt, Colors.amber[700]!,
                                  'R${listing.pricePerKwh.toStringAsFixed(2)}', 'per kWh'),
                              _listingVDivider(cs),
                              _listingStatTile(context, Icons.battery_charging_full, Colors.green,
                                  '${listing.availableEnergy.toStringAsFixed(1)} kWh', 'Available'),
                              _listingVDivider(cs),
                              _listingStatTile(context, Icons.electrical_services, cs.primary,
                                  listing.connectorType, 'Connector'),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Second stats row
                      Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              _listingStatTile(context, Icons.electric_car, cs.primary,
                                  listing.vehicleType, 'Vehicle'),
                              _listingVDivider(cs),
                              _listingStatTile(context, Icons.arrow_downward, Colors.teal,
                                  '${listing.minEnergySale.toStringAsFixed(1)} kWh', 'Min Sale'),
                              _listingVDivider(cs),
                              _listingStatTile(context, Icons.arrow_upward, Colors.deepOrange,
                                  '${listing.maxEnergySale.toStringAsFixed(1)} kWh', 'Max Sale'),
                            ],
                          ),
                        ),
                      ),

                      // Description
                      if (listing.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, size: 14, color: cs.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  listing.description!,
                                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _toggleListingStatus(context, provider, listing.status),
                              icon: Icon(isAvailable ? Icons.pause : Icons.play_arrow, size: 16),
                              label: Text(isAvailable ? 'Pause' : 'Resume'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isAvailable ? Colors.orange : Colors.green,
                                side: BorderSide(color: isAvailable ? Colors.orange : Colors.green),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showEditListingDialog(context, provider, listing),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Edit'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showDeleteConfirmation(context, provider),
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text('Delete'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Received Requests ───────────────────────────────────────────────
          Row(
            children: [
              Text(
                'Buyer Requests',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: cs.onSurface),
              ),
              const SizedBox(width: 8),
              if (provider.receivedRequests.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${provider.receivedRequests.length}',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold, color: cs.onPrimary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (provider.receivedRequests.isNotEmpty)
            ...provider.receivedRequests.map((request) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RequestCard(
                    request: request,
                    isReceived: true,
                    onAccept: () => _handleRequestResponse(context, provider, request.id, 'accepted'),
                    onReject: () => _handleRequestResponse(context, provider, request.id, 'rejected'),
                    onShowOnMap: request.status == 'accepted' && request.sellerLocationLat != null
                        ? () => _handleViewOnMap(context, request)
                        : null,
                    onNavigate: request.status == 'accepted' && request.sellerLocationLat != null
                        ? () => _handleNavigate(
                            request.sellerLocationLat!,
                            request.sellerLocationLng!,
                            request.buyerName ?? 'Buyer')
                        : null,
                  ),
                ))
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 44,
                        color: cs.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: 10),
                    Text('No requests yet',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 4),
                    Text('Buyers will see your listing and send requests here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurface.withValues(alpha: 0.4))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _listingStatTile(BuildContext context, IconData icon, Color iconColor,
      String value, String label) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 4),
            Text(value,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 1),
            Text(label,
                style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.45))),
          ],
        ),
      ),
    );
  }

  Widget _listingVDivider(ColorScheme cs) => Container(
        width: 1,
        margin: const EdgeInsets.symmetric(vertical: 8),
        color: cs.onSurface.withValues(alpha: 0.08),
      );

  Widget _buildCreateListingView(
      BuildContext context, MarketplaceProvider provider) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Green gradient header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bolt_rounded,
                            size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Start Selling Energy',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Share your EV battery with nearby drivers\nand earn while you're parked",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Benefits list
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _benefitRow(cs, Icons.attach_money_rounded, Colors.green,
                          'Set your own price', 'Choose R/kWh that works for you'),
                      const SizedBox(height: 14),
                      _benefitRow(cs, Icons.schedule_rounded, cs.primary,
                          'Control availability', 'Set hours or leave it always-on'),
                      const SizedBox(height: 14),
                      _benefitRow(cs, Icons.verified_user_rounded, Colors.teal,
                          'Verified transactions', 'Secure peer-to-peer energy trading'),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showCreateListingDialog(context, provider),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text(
                            'Create Energy Listing',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitRow(ColorScheme cs, IconData icon, Color color,
      String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.55))),
            ],
          ),
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
                      size: 64, color: cs.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'No requests yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse the Buy Energy tab to request energy from sellers',
                    style:
                        TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: provider.myRequests.length,
              itemBuilder: (context, index) {
                final request = provider.myRequests[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RequestCard(
                    request: request,
                    isReceived: false,
                    onShowOnMap: request.status == 'accepted' &&
                            request.sellerLocationLat != null
                        ? () => _handleViewOnMap(context, request)
                        : null,
                    onNavigate: request.status == 'accepted' &&
                            request.sellerLocationLat != null
                        ? () => _handleNavigate(
                            request.sellerLocationLat!,
                            request.sellerLocationLng!,
                            request.sellerName ?? 'Seller')
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
                      size: 64, color: cs.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'No transaction history',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your completed energy trades will appear here',
                    style:
                        TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
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

    // 1. Signal MapProvider that a route is pending — MapPage will auto-plot it
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    mapProvider.setRouteFromCoordinates(
      start: const LatLng(0, 0), // placeholder; map_page reads its own position
      end: LatLng(request.sellerLocationLat!, request.sellerLocationLng!),
      destinationName: request.sellerName ?? 'Seller',
      isAcceptedRoute: true, // energy approved → show Navigate not Request Energy
    );

    // 2. Switch to Map tab — map_page detects isNavigating and auto-routes
    mainScreenKey.currentState?.navigateToTab(2);
  }

  void _handleNavigate(double lat, double lng, String label) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Navigate with...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.navigation, color: Colors.blue),
              title: const Text('Google Maps'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final url = Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_car, color: Colors.teal),
              title: const Text('Waze'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final url = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  final fallback = Uri.parse(
                      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
                  if (await canLaunchUrl(fallback)) {
                    await launchUrl(fallback,
                        mode: LaunchMode.externalApplication);
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.map, color: Colors.orange),
              title: const Text('Default Maps App'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final url = Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
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