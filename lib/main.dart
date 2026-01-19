import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxibook/providers/subscription_provider.dart';
import 'package:taxibook/screens/onboarding_screen.dart';
import 'package:taxibook/providers/auth_provider.dart';
import 'package:taxibook/providers/theme_provider.dart';
import 'package:taxibook/screens/add_edit_trip_screen.dart';
import 'package:taxibook/services/log_service.dart';
import 'package:taxibook/wrappers/permission_wrapper.dart'; // NEW IMPORT
import 'screens/home_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    await Firebase.initializeApp();
    await initializeDateFormatting('zh_TW', null);

    final logService = LogService();
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    FlutterError.onError = (FlutterErrorDetails details) {
      logService.logError(details.exception, details.stack, reason: 'FlutterError');
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    
    PlatformDispatcher.instance.onError = (error, stack) {
      logService.logError(error, stack, reason: 'PlatformDispatcher');
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => ThemeProvider()),
          ChangeNotifierProvider(create: (context) => AuthProvider()),
          ChangeNotifierProvider(create: (context) => SubscriptionProvider()),
        ],
        child: MyApp(hasSeenOnboarding: hasSeenOnboarding),
      ),
    );
  }, (error, stack) {
    LogService().logError(error, stack, reason: 'runZonedGuarded');
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class MyApp extends StatelessWidget {
  final bool hasSeenOnboarding;

  const MyApp({super.key, required this.hasSeenOnboarding});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: '計程車帳本',
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: themeProvider.themeMode,
          home: hasSeenOnboarding ? const AuthWrapper() : const OnboardingScreen(),
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'TW'),
            Locale('en', 'US'),
          ],
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    var baseTheme = ThemeData(brightness: brightness, useMaterial3: true);
    var colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.yellow.shade800,
      brightness: brightness,
      primary: Colors.yellow.shade800,
      onPrimary: Colors.black,
      secondary: Colors.green,
      onSecondary: brightness == Brightness.dark ? Colors.black : Colors.white,
      error: Colors.red,
      onError: Colors.black,
    );

    return baseTheme.copyWith(
      colorScheme: colorScheme,
      primaryColor: Colors.yellow.shade800,
      bottomAppBarTheme: BottomAppBarThemeData(
        color: colorScheme.surface,
        elevation: 2,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    switch (authProvider.status) {
      case AuthStatus.uninitialized:
      case AuthStatus.authenticating:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.authenticated:
      case AuthStatus.unauthenticated:
        // UPDATED: Navigate to the PermissionWrapper instead of MainScreen directly.
        return const PermissionWrapper();
    }
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();
  final GlobalKey<StatsScreenState> _statsScreenKey = GlobalKey<StatsScreenState>();
  final GlobalKey<State<HistoryScreen>> _historyScreenKey = GlobalKey<State<HistoryScreen>>();

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      HomeScreen(key: _homeScreenKey),
      StatsScreen(key: _statsScreenKey),
      HistoryScreen(key: _historyScreenKey, onDataUpdated: _refreshAllPages),
      const SettingsScreen(),
    ];
  }
  
  void _refreshAllPages() {
    _homeScreenKey.currentState?.loadInitialData();
    _statsScreenKey.currentState?.loadStats();
    (_historyScreenKey.currentState as dynamic)?.loadTrips();
  }

  static const List<String> _pageTitles = ['首頁', '統計資料', '歷史行程', '設定'];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _navigateToAddTrip() async {
    _homeScreenKey.currentState?.stopAllIdleTimers();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditTripScreen(),
      ),
    );

    if (result == true || result == 'TRIP_SAVED') {
      _refreshAllPages();
      if (result == 'TRIP_SAVED') {
        _homeScreenKey.currentState?.suggestNearestHotspotAfterTrip();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> navItems = [
      _buildNavItem(icon: Icons.home_filled, label: '首頁', index: 0),
      _buildNavItem(icon: Icons.bar_chart, label: '統計', index: 1),
      _buildNavItem(icon: Icons.history, label: '歷史行程', index: 2),
      _buildNavItem(icon: Icons.settings, label: '設定', index: 3),
    ];

    final currentTitle = _pageTitles[_selectedIndex];
    final isHomePage = _selectedIndex == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentTitle),
        centerTitle: true,
        elevation: 0,
        actions: const [], // Removed the hotspot sharing button
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _widgetOptions,
          ),
          if (isHomePage)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: () => _homeScreenKey.currentState?.fetchAndStoreLocation(),
                tooltip: '取得目前位置',
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                child: const Icon(Icons.my_location),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddTrip,
        elevation: 2.0,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            navItems[0],
            navItems[1],
            const SizedBox(width: 48), // The space for the FAB
            navItems[2],
            navItems[3],
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = (_selectedIndex == index);
    return IconButton(
      icon: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
      onPressed: () => _onItemTapped(index),
      tooltip: label,
    );
  }
}
