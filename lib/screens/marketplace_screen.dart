// lib/screens/marketplace_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/marketplace_provider.dart';

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
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: const Icon(Icons.electric_car, color: Colors.white),
                        ),
                        title: Text(listing.sellerName ?? 'Energy Provider'),
                        subtitle: Text(
                          '${listing.distance?.toStringAsFixed(1) ?? '?'} km • '
                          'R${listing.pricePerKwh.toStringAsFixed(2)}/kWh',
                        ),
                        trailing: Text('${listing.availableEnergy.toStringAsFixed(1)} kWh'),
                        onTap: () {
                          // TODO: Show request dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Request dialog coming soon!')),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildSellEnergyTab(MarketplaceProvider provider) {
    return Center(
      child: provider.myActiveListing != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sell, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  'You have an active listing',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'R${provider.myActiveListing!.pricePerKwh.toStringAsFixed(2)}/kWh',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    provider.deleteMyListing();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete Listing'),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sell, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Start selling your energy',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create a listing to let buyers know you have energy to share',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Show create listing dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Create listing dialog coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Listing'),
                ),
              ],
            ),
    );
  }

  Widget _buildMyRequestsTab(MarketplaceProvider provider) {
    return Center(
      child: provider.isLoading
          ? const CircularProgressIndicator()
          : provider.myRequests.isEmpty
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No requests yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                )
              : ListView.builder(
                  itemCount: provider.myRequests.length,
                  itemBuilder: (context, index) {
                    final request = provider.myRequests[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: const Icon(Icons.request_page, color: Colors.white),
                        ),
                        title: Text('Energy Request'),
                        subtitle: Text(
                          '${request.requestedEnergy.toStringAsFixed(1)} kWh • ${request.status}',
                        ),
                        trailing: request.status == 'pending'
                            ? TextButton(
                                onPressed: () {
                                  provider.cancelRequest(request.id);
                                },
                                child: const Text('Cancel'),
                              )
                            : null,
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildHistoryTab(MarketplaceProvider provider) {
    return Center(
      child: provider.isLoading
          ? const CircularProgressIndicator()
          : provider.myTransactions.isEmpty
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No transaction history',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                )
              : ListView.builder(
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
                        subtitle: Text(
                          transaction.energyTransferred != null
                              ? '${transaction.energyTransferred!.toStringAsFixed(2)} kWh'
                              : 'Pending',
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
}