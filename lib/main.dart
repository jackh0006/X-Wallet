import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'localized_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'screens/screens.dart';
import 'security.dart';
import 'memory_protection.dart';
import 'tor_manager.dart';
import 'l10n/app_localizations.dart';

/// Global state shared by every screen is declared in app_state.dart.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await MemoryProtection.initialize();
  await appState.init();
  runApp(const XWalletApp());
}

class XWalletApp extends StatefulWidget {
  const XWalletApp({super.key});

  @override
  State<XWalletApp> createState() => _XWalletAppState();
}

class _XWalletAppState extends State<XWalletApp> with WidgetsBindingObserver {
  DateTime _lastActivity = DateTime.now();
  Timer? _idleTimer;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        await TorManager.instance.stop();
        return AppExitResponse.exit;
      },
    );
    _idleTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkIdle(),
    );
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _idleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _activity() => _lastActivity = DateTime.now();

  /// Idle auto-lock: budget comes from settings (0 = background-only lock).
  void _checkIdle() {
    final budget = appState.autoLockSeconds;
    if (budget <= 0) return;
    if (appState.appLocked || !appState.usePin) return;
    if (DateTime.now().difference(_lastActivity).inSeconds >= budget) {
      appState.lockApp();
      if (appState.unlocked) appState.lock();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // Best effort: the window is gone, so do not leave our private Tor
      // daemon running in the background. Only the captured child is killed.
      unawaited(TorManager.instance.stop());
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      appState.lockApp();
      if (appState.unlocked) appState.lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return Listener(
          onPointerDown: (_) => _activity(),
          onPointerMove: (_) => _activity(),
          onPointerUp: (_) => _activity(),
          child: MaterialApp(
            title: 'X Wallet',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('fa'),
              Locale('ar'),
              Locale('zh'),
              Locale('ru'),
              Locale('es'),
            ],
            locale: appState.localeObj,
            themeMode: appState.themeMode,
            theme: _lightTheme(),
            darkTheme: appState.isAmoled ? _amoledTheme() : _darkTheme(),
            home: appState.appLocked ? const AppLockScreen() : const Shell(),
          ),
        );
      },
    );
  }

  ThemeData _lightTheme() {
    const gold = Color(0xFFF0B90B);
    const goldLight = Color(0xFFFCD535);
    const bg = Color(0xFFF5F5F5);
    const surface = Color(0xFFFFFFFF);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.light,
        ).copyWith(
          primary: gold,
          secondary: goldLight,
          surface: surface,
          onSurface: Colors.black87,
        );
    return _baseTheme(scheme, Brightness.light, bg, surface);
  }

  ThemeData _darkTheme() {
    const gold = Color(0xFFF0B90B);
    const goldLight = Color(0xFFFCD535);
    const bg = Color(0xFF0B0E11);
    const surface = Color(0xFF161A1E);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
        ).copyWith(
          primary: gold,
          secondary: goldLight,
          surface: surface,
          onSurface: Colors.white,
        );
    return _baseTheme(scheme, Brightness.dark, bg, surface);
  }

  ThemeData _amoledTheme() {
    const gold = Color(0xFFF0B90B);
    const goldLight = Color(0xFFFCD535);
    const bg = Color(0xFF000000); // True black for AMOLED
    const surface = Color(0xFF121212);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
        ).copyWith(
          primary: gold,
          secondary: goldLight,
          surface: surface,
          onSurface: Colors.white,
        );
    return _baseTheme(scheme, Brightness.dark, bg, surface);
  }

  ThemeData _baseTheme(
    ColorScheme scheme,
    Brightness brightness,
    Color bg,
    Color surface,
  ) {
    final isAmoled =
        brightness == Brightness.dark && bg == const Color(0xFF000000);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: isAmoled ? Colors.transparent : bg,
        foregroundColor: brightness == Brightness.light
            ? Colors.black87
            : Colors.white,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: brightness == Brightness.light
                ? const Color(0xFFE0E0E0)
                : const Color(0xFF2B3139),
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? const Color(0xFFFAFAFA)
            : const Color(0xFF1E2329),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: brightness == Brightness.light
                ? const Color(0xFFE0E0E0)
                : const Color(0xFF2B3139),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: brightness == Brightness.light
                ? const Color(0xFFE0E0E0)
                : const Color(0xFF2B3139),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: brightness == Brightness.light
            ? const Color(0xFFF5F5F5)
            : (isAmoled ? const Color(0xFF000000) : const Color(0xFF12161B)),
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brightness == Brightness.light
            ? const Color(0xFF333333)
            : (isAmoled ? const Color(0xFF1A1A1A) : const Color(0xFF2B3139)),
        contentTextStyle: TextStyle(
          color: brightness == Brightness.light ? Colors.white : Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          // Binance yellow is too light for white text (about 1.8:1).  Black
          // remains comfortably readable in every supported theme.
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      dividerColor: brightness == Brightness.light
          ? const Color(0xFFE0E0E0)
          : const Color(0xFF2B3139),
      iconTheme: IconThemeData(
        color: brightness == Brightness.light ? Colors.black87 : Colors.white,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          color: brightness == Brightness.light ? Colors.black87 : Colors.white,
        ),
        bodyMedium: TextStyle(
          color: brightness == Brightness.light
              ? Colors.black54
              : Colors.white70,
        ),
      ),
    );
  }
}

/// PIN/biometric gate shown when the optional app lock is enabled.
///
/// Rate-limited: after failed entries an exponential cooldown applies
/// (1 s, 2 s, 4 s … up to 15 min) and it is enforced by the stored window.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _pin = TextEditingController();
  String? _error;
  Duration _wait = Duration.zero;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startTicker();
    _migrateLegacyPin();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _refreshWait());
  }

  Future<void> _refreshWait() async {
    var wait = Duration.zero;
    if (_wait.inSeconds > 0 || !_dismissibleBackoffDone) {
      try {
        wait = await AppSecurity.backoffRemaining();
      } catch (_) {
        wait = Duration.zero;
      }
    }
    if (!mounted) return;
    if (wait != _wait) setState(() => _wait = wait);
    if (_wait != Duration.zero) {
      setState(
        () => _error = 'Too many attempts. Locked for ${_wait.inSeconds}s.',
      );
      _dismissibleBackoffDone = false;
    } else if (!_dismissibleBackoffDone) {
      setState(() => _error = null);
      _dismissibleBackoffDone = true;
    }
  }

  bool _dismissibleBackoffDone = true;

  /// v1.0.2 stored a plain SHA-256 record, which is below the new bar. It is
  /// invalidated in place and the user creates a fresh Argon2id PIN in
  /// Settings afterwards. Unreadable secure storage must never crash the
  /// lock screen, so failures simply mean "not legacy".
  Future<void> _migrateLegacyPin() async {
    try {
      if (await AppSecurity.pinIsLegacy()) {
        await AppSecurity.clearPin();
        await appState.setUsePin(false);
        appState.unlockApp();
      }
    } catch (_) {
      // Platform channel unavailable (tests) or storage failure — treated as
      // not-legacy; nothing is erased merely because we could not read.
    }
  }

  Future<void> _unlock() async {
    if (await AppSecurity.backoffRemaining() > Duration.zero) {
      setState(() => _error = 'Locked. Please wait for the cooldown.');
      return;
    }
    if (await AppSecurity.authenticate('Unlock X Wallet')) {
      appState.unlockApp();
      return;
    }
    final ok = await AppSecurity.verifyPin(_pin.text);
    if (ok) {
      appState.unlockApp();
    } else {
      // State refresh shows the new cooldown immediately.
      await _refreshWait();
      if (mounted) {
        setState(() => _error ??= 'Incorrect PIN.');
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lockedOut = _wait > Duration.zero;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icon/x-wallet-1024.png',
                  width: 84,
                  height: 84,
                ),
                const SizedBox(height: 18),
                const Text(
                  'X Wallet',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  lockedOut
                      ? 'Too many failed attempts. Try again in ${_wait.inSeconds} s.'
                      : 'Enter your PIN to continue',
                  style: TextStyle(
                    color: lockedOut ? Colors.orange : Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  enabled: !lockedOut,
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _unlock(),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: lockedOut ? null : _unlock,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  @override
  void initState() {
    super.initState();
    // The visible tab lives in appState (round 6) so that flows like import
    // or create can move the user onto the wallet that just became visible.
    appState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    appState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final pages = [
      const HomePage(),
      const WalletPage(),
      const SendPage(),
      const InspectPage(),
      const SettingsPage(),
    ];
    return Scaffold(
      body: IndexedStack(index: appState.tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: appState.tab,
        onDestinationSelected: (i) => appState.focusTab(i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: strings.home,
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: strings.wallet,
          ),
          NavigationDestination(
            icon: Icon(Icons.send_outlined),
            selectedIcon: Icon(Icons.send),
            label: strings.send,
          ),
          NavigationDestination(
            icon: Icon(Icons.travel_explore_outlined),
            selectedIcon: Icon(Icons.travel_explore),
            label: strings.inspect,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: strings.settings,
          ),
        ],
      ),
    );
  }
}
