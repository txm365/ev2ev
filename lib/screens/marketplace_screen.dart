// lib/screens/marketplace_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/create_listing_dialog.dart';
import '../widgets/energy_request_dialog.dart';
import '../widgets/listing_card.dart';
import '../widgets/request_card.dart';

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
      marketplaceProvider.getCurrentLocation();
      marketplaceProvider.getNearbyListings();
      marketplaceProvider.getMyRequests();
      marketplaceProvider.getMyTransactions();
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
        title: const Text('Energy Marketplace'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_cart), text: 'Buy Energy'),
            Tab(icon: Icon(Icons.sell), text: 'Sell Energy'),
            Tab(icon: Icon(Icons.request_page), text: 'My Requests'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: Consumer<MarketplaceProvider>(
        builder: (context, provider, child) {
          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    provider.errorMessage!,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      provider.clearError();
                      provider.getCurrentLocation();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
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

  Widget _buildBuyEnergyTab(MarketplaceProvider provider) {
    return RefreshIndicator(
      onRefresh: () => provider.getNearbyListings(),
      child: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.nearbyListings.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No energy sellers found nearby',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Pull down to refresh',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: provider.nearbyListings.length,
                  itemBuilder: (context, index) {
                    final listing = provider.nearbyListings[index];
                    return ListingCard(
                      listing: listing,
                      onTap: () => _showRequestDialog(context, listing, provider),
                    );
                  },
                ),
    );
  }

  Widget _buildSellEnergyTab(MarketplaceProvider provider) {
    return Center(
      child: provider.myActiveListing != null
          ? _buildActiveListingView(provider)
          : _buildCreateListingView(provider),
    );
  }

  Widget _buildActiveListingView(MarketplaceProvider provider) {
    final listing = provider.myActiveListing!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Active listing card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.sell, color: Colors.green, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Active Listing',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Status: ${listing.status.toUpperCase()}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusChip(listing.status),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Listing details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildDetailColumn('Price per kWh', 'R${listing.pricePerKwh.toStringAsFixed(2)}'),
                            _buildDetailColumn('Available', '${listing.availableEnergy.toStringAsFixed(1)} kWh'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildDetailColumn('Min Sale', '${listing.minEnergySale.toStringAsFixed(1)} kWh'),
                            _buildDetailColumn('Max Sale', '${listing.maxEnergySale.toStringAsFixed(1)} kWh'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildDetailColumn('Vehicle', listing.vehicleType.toUpperCase()),
                            _buildDetailColumn('Connector', listing.connectorType),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  if (listing.description?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Description:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            listing.description!,
                            style: TextStyle(color: Colors.blue[700]),
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
          
          // Received requests section
          if (provider.receivedRequests.isNotEmpty) ...[
            Text(
              'Received Requests (${provider.receivedRequests.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...provider.receivedRequests.map((request) => RequestCard(
              request: request,
              isReceived: true,
              onAccept: () => _handleRequestResponse(provider, request.id, 'accepted'),
              onReject: () => _handleRequestResponse(provider, request.id, 'rejected'),
            )),
          ] else ...[
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No requests yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Buyers will see your listing and can send requests',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pauseListing(provider),
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
                  onPressed: () => _deleteListing(provider),
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Listing'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.sell, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        const Text(
          'Start selling your energy',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Create a listing to let buyers know you have energy to share',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _showCreateListingDialog(context, provider),
          icon: const Icon(Icons.add),
          label: const Text('Create Listing'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildMyRequestsTab(MarketplaceProvider provider) {
    return RefreshIndicator(
      onRefresh: () => provider.getMyRequests(),
      child: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.myRequests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No requests yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Find energy sellers and send requests',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: provider.myRequests.length,
                  itemBuilder: (context, index) {
                    final request = provider.myRequests[index];
                    return RequestCard(
                      request: request,
                      isReceived: false,
                      onCancel: () => _cancelRequest(provider, request.id),
                    );
                  },
                ),
    );
  }

  Widget _buildHistoryTab(MarketplaceProvider provider) {
    return RefreshIndicator(
      onRefresh: () => provider.getMyTransactions(),
      child: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.myTransactions.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No transaction history',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: provider.myTransactions.length,
                  itemBuilder: (context, index) {
                    final transaction = provider.myTransactions[index];
                    final isSeller = transaction.sellerId == provider.currentUserId;
                    
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: transaction.status == 'completed' 
                              ? Colors.green 
                              : Colors.orange,
                          child: Icon(
                            isSeller ? Icons.sell : Icons.shopping_cart,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(isSeller ? 'Sold Energy' : 'Bought Energy'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction.energyTransferred != null
                                  ? '${transaction.energyTransferred!.toStringAsFixed(2)} kWh'
                                  : 'Pending',
                            ),
                            Text(
                              'Status: ${transaction.status.toUpperCase()}',
                              style: TextStyle(
                                color: transaction.status == 'completed' 
                                    ? Colors.green 
                                    : Colors.orange,
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

  Widget _buildDetailColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
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

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'available':
        color = Colors.green;
        break;
      case 'paused':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Action methods
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
                content: Text('Energy listing created successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _showRequestDialog(BuildContext context, listing, MarketplaceProvider provider) {
    showDialog(
      context: context,
      builder: (context) => EnergyRequestDialog(
        listing: listing,
        onSubmit: (data) async {
          Navigator.of(context).pop();
          
          final success = await provider.createEnergyRequest(
            listingId: listing.id,
            requestedEnergy: data['requestedEnergy'],
            offeredPricePerKwh: data['offeredPricePerKwh'],
            message: data['message'],
          );

          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Energy request sent successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _handleRequestResponse(MarketplaceProvider provider, String requestId, String status) async {
    final success = await provider.respondToRequest(requestId, status);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${status.toLowerCase()} successfully!'),
          backgroundColor: status == 'accepted' ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  void _cancelRequest(MarketplaceProvider provider, String requestId) async {
    final success = await provider.cancelRequest(requestId);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request cancelled successfully!'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _pauseListing(MarketplaceProvider provider) async {
    final currentStatus = provider.myActiveListing?.status ?? 'available';
    final newStatus = currentStatus == 'available' ? 'paused' : 'available';
    
    final success = await provider.updateListingStatus(newStatus);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Listing ${newStatus.toLowerCase()} successfully!'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _deleteListing(MarketplaceProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing'),
        content: const Text('Are you sure you want to delete this listing? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await provider.deleteMyListing();
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing deleted successfully!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}