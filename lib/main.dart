import 'package:flutter/material.dart';
import 'l10n/strings.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/stock_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/my_money_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  runApp(const MenyaBizApp());
}

class MenyaBizApp extends StatelessWidget {
  const MenyaBizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'MenyaBiz',
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: MainNavigation(
            key: ValueKey(AppSettings.instance.language),
          ),
        );
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    StockScreen(),
    SalesScreen(),
    ChatScreen(),
    MyMoneyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home), label: tr('home')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.inventory_2), label: tr('stock')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.point_of_sale), label: tr('sales')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.chat_bubble), label: tr('chat')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.wallet), label: tr('my_money')),
        ],
      ),
    );
  }
}