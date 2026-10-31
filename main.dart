// Ported from MainActivity.kt
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/history_screen.dart';
import 'screens/about_screen.dart';

void main() {
  runApp(const EkrushiApp());
}

class EkrushiApp extends StatefulWidget {
  const EkrushiApp({super.key});

  @override
  State<EkrushiApp> createState() => _EkrushiAppState();
}

class _EkrushiAppState extends State<EkrushiApp> {
  bool _showSplash = true;
  bool _isLoggedIn = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'e-krushi',
      debugShowCheckedModeBanner: false,
      theme: EkrushiTheme.light(),
      darkTheme: EkrushiTheme.dark(),
      home: _showSplash
          ? SplashScreen(onFinished: () => setState(() => _showSplash = false))
          : !_isLoggedIn
              ? LoginScreen(onLoginSuccess: () => setState(() => _isLoggedIn = true))
              : _EkrushiHome(onLogout: () => setState(() => _isLoggedIn = false)),
    );
  }
}

enum _Tab { scan, history, about }

class _EkrushiHome extends StatefulWidget {
  final VoidCallback onLogout;
  const _EkrushiHome({required this.onLogout});

  @override
  State<_EkrushiHome> createState() => _EkrushiHomeState();
}

class _EkrushiHomeState extends State<_EkrushiHome> {
  _Tab _selected = _Tab.scan;

  @override
  Widget build(BuildContext context) {
    final screens = <_Tab, Widget>{
      _Tab.scan: const ScanScreen(),
      _Tab.history: const HistoryScreen(),
      _Tab.about: AboutScreen(onLogout: widget.onLogout),
    };

    return Scaffold(
      body: IndexedStack(
        index: _Tab.values.indexOf(_selected),
        children: _Tab.values.map((t) => screens[t]!).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _Tab.values.indexOf(_selected),
        onDestinationSelected: (index) => setState(() => _selected = _Tab.values[index]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.info), label: 'About'),
        ],
      ),
    );
  }
}
