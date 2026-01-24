// lib/main.dart
import 'dart:async';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:animations/animations.dart';
import 'package:attendance_management/translations/locale_keys.g.dart';
import 'package:attendance_management/views/bluetooth_page.dart';
import 'package:attendance_management/views/events_page.dart';
import 'package:attendance_management/views/home_page.dart';
import 'package:attendance_management/views/members_page.dart';
import 'package:attendance_management/views/settings_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  final savedThemeMode = await AdaptiveTheme.getThemeMode();
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('id')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: MainApp(savedThemeData: savedThemeMode),
    ),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key, required this.savedThemeData});

  final AdaptiveThemeMode? savedThemeData;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late ThemeData _lightTheme;
  late ThemeData _nightTheme;

  @override
  void initState() {
    super.initState();

    _lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green.shade400,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(backgroundColor: Colors.green.shade400),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.green.shade400,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey.shade700,
      ),
    );

    _nightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green.shade800,
        brightness: Brightness.dark,
      ),
      appBarTheme: AppBarTheme(backgroundColor: Colors.green.shade800),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.green,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey.shade800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: _lightTheme,
      dark: _nightTheme,
      initial: widget.savedThemeData ?? AdaptiveThemeMode.light,
      builder: (theme, darkTheme) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Presence Management',
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: theme,
        darkTheme: darkTheme,
        home: const MainPage(),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 2;
  bool _canCloseApp = false;
  DateTime? _currentBackPressTime;
  late final TabController _tabController;

  final pageList = [MemberPage(), EventPage(), HomePage(), BluetoothPage(), SettingPage()];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onPopInvoked(bool canPop, Object? result) {
    if (_selectedIndex != 2) {
      setState(() {
        _selectedIndex = 2;
      });
      return;
    }

    DateTime now = DateTime.now();
    if (_currentBackPressTime == null ||
        now.difference(_currentBackPressTime!) > Duration(seconds: 2)) {
      _currentBackPressTime = now;
      Toastification().show(
        context: context,
        title: Text(LocaleKeys.exit_alert_title.tr(context: context)),
        description: Text(LocaleKeys.exit_alert_desc.tr(context: context)),
        type: ToastificationType.info,
        style: ToastificationStyle.flat,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: Duration(seconds: 2),
        animationDuration: Duration(milliseconds: 500),
      );

      // Disable pop invoke and close the toast after 2s timeout
      Future.delayed(Duration(seconds: 2), () => setState(() => _canCloseApp = false));
      setState(() => _canCloseApp = true);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: pageList.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _selectedIndex) {
        setState(() => _selectedIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canCloseApp && _selectedIndex == 2 ? true : false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        appBar: AppBar(
          title: Center(child: Text(LocaleKeys.app_title.tr(context: context))),
          leading: Container(
            margin: const EdgeInsets.only(left: 12.0),
            child: Image.asset("assets/app-icon.png"),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade800],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          leadingWidth: 55.0,
          actions: <Widget>[
            ValueListenableBuilder<AdaptiveThemeMode?>(
              valueListenable: AdaptiveTheme.of(context).modeChangeNotifier,
              builder: (context, mode, _) {
                final isLight = mode == AdaptiveThemeMode.light;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return RotationTransition(
                      turns: child.key == ValueKey('icon1')
                          ? Tween<double>(begin: 1, end: 0.75).animate(animation)
                          : Tween<double>(begin: 0.75, end: 1).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: IconButton(
                    key: ValueKey(isLight ? 'icon1' : 'icon2'),
                    onPressed: () {
                      if (isLight) {
                        AdaptiveTheme.of(context).setDark();
                      } else {
                        AdaptiveTheme.of(context).setLight();
                      }
                    },
                    icon: Icon(isLight ? Icons.wb_sunny : Icons.nights_stay),
                  ),
                );
              },
            ),
          ],
        ),
        floatingActionButton: SizedBox(
          height: 64,
          width: 64,
          child: Transform.translate(
            offset: Offset(0, 10),
            child: FloatingActionButton(
              onPressed: () => _onItemTapped(2),
              elevation: 12.0,
              shape: CircleBorder(),
              tooltip: LocaleKeys.navbar_icon_title_home.tr(context: context),
              backgroundColor: Theme.of(context).brightness == Brightness.light
                  ? Colors.green.shade400
                  : Colors.green.shade600,
              child: Icon(
                Icons.home,
                color: _selectedIndex == 2
                    ? Theme.of(context).bottomNavigationBarTheme.selectedItemColor
                    : Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          onTap: _onItemTapped,
          showSelectedLabels: true,
          showUnselectedLabels: false,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.group),
              label: LocaleKeys.navbar_icon_title_member.tr(context: context),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event),
              label: LocaleKeys.navbar_icon_title_event.tr(context: context),
            ),
            BottomNavigationBarItem(icon: SizedBox.shrink(), label: ""),
            BottomNavigationBarItem(
              icon: Icon(Icons.bluetooth),
              label: LocaleKeys.navbar_icon_title_bluetooth.tr(context: context),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: LocaleKeys.navbar_icon_title_setting.tr(context: context),
            ),
          ],
        ),
        body: PageTransitionSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, primaryAnimation, secondaryAnimation) => FadeThroughTransition(
            fillColor: Colors.transparent,
            animation: primaryAnimation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          ),
          child: pageList[_selectedIndex],
        ),
      ),
    );
  }
}
