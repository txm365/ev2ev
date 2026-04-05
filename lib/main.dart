// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'constants/app_themes.dart';
import 'providers/bluetooth_provider.dart';
import 'providers/map_provider.dart';
import 'providers/marketplace_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/blockchain_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/main_screen.dart';
import 'screens/profile_screen.dart';

final supabase = Supabase.instance.client;

/// Global key — lets any screen call navigateToTab() without importing main_screen.dart
final GlobalKey<MainScreenState> mainScreenKey = GlobalKey<MainScreenState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => BluetoothProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => MarketplaceProvider()),
        ChangeNotifierProvider(create: (_) => BlockchainProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'EV2EV Energy Trading',
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: themeProvider.themeMode,

          // Lock font scale — ignores phone accessibility font size
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.noScaling,
              ),
              child: child!,
            );
          },

          home: const SplashScreen(),
          routes: {
            '/main': (context) => MainScreen(key: mainScreenKey),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/profile': (context) => const ProfileScreen(),
          },
        );
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
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final authState = snapshot.data!;
          if (authState.session != null) {
            return MainScreen(key: mainScreenKey);
          } else {
            return const LoginScreen();
          }
        }
        return const SplashScreen();
      },
    );
  }
}