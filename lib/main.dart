// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'providers/bluetooth_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/marketplace_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/main_screen.dart';
import 'screens/profile_screen.dart';

final supabase = Supabase.instance.client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BluetoothProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => MarketplaceProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EV2EV Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
        
        // Enhanced theme for marketplace
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        
        // Card theme for better marketplace cards
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        
        // Enhanced button themes
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        
        // Input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        
        // AppBar theme
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black87,
        ),
        
        // Bottom navigation theme
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          elevation: 8,
        ),
        
        // Tab bar theme for marketplace
        tabBarTheme: const TabBarTheme(
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(color: Colors.blue, width: 2),
            insets: EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/main': (context) => const MainScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  AuthWrapperState createState() => AuthWrapperState();
}

class AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _initializeProviders();
  }

  // Initialize providers after authentication
  void _initializeProviders() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = supabase.auth.currentSession;
      if (session != null) {
        // Initialize marketplace provider when user is authenticated
        final marketplaceProvider = context.read<MarketplaceProvider>();
        marketplaceProvider.initialize();
        
        // Initialize bluetooth provider
        final bluetoothProvider = context.read<BluetoothProvider>();
        bluetoothProvider.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Handle authentication state changes
        if (snapshot.hasData) {
          final authState = snapshot.data!;
          
          // Initialize providers when user signs in
          if (authState.event == AuthChangeEvent.signedIn) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final marketplaceProvider = context.read<MarketplaceProvider>();
                marketplaceProvider.initialize();
                
                final bluetoothProvider = context.read<BluetoothProvider>();
                bluetoothProvider.initialize();
              }
            });
          }
          
          // Clear cached data when user signs out
          if (authState.event == AuthChangeEvent.signedOut) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.read<MarketplaceProvider>().clearError();
                context.read<BluetoothProvider>().clearError();
              }
            });
          }
        }

        // Check for provider errors and show error handling
        return Consumer2<BluetoothProvider, MarketplaceProvider>(
          builder: (context, bluetoothProvider, marketplaceProvider, child) {
            // Show critical error screen if needed
            if (bluetoothProvider.errorMessage != null && 
                bluetoothProvider.errorMessage!.contains('not supported')) {
              return _buildCriticalErrorScreen(context, bluetoothProvider);
            }

            final session = supabase.auth.currentSession;
            return session == null ? const SplashScreen() : const MainScreen();
          },
        );
      },
    );
  }

  Widget _buildCriticalErrorScreen(BuildContext context, BluetoothProvider provider) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red[50]!,
              Colors.red[100]!,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bluetooth_disabled,
                    size: 64,
                    color: Colors.red[700],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Error title
                Text(
                  'Bluetooth Not Available',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Error message
                Text(
                  provider.errorMessage!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Continue button - marketplace still works
                ElevatedButton.icon(
                  onPressed: () {
                    provider.clearError();
                    Navigator.pushReplacementNamed(context, '/main');
                  },
                  icon: const Icon(Icons.store),
                  label: const Text('Continue to Marketplace'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Help text
                Text(
                  'You can still use the energy marketplace without Bluetooth.\nHardware features will be unavailable.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}