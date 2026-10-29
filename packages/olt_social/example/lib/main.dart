// Contoh aplikasi host yang meniru integrasi olt_social ke OLT.
//
// Jalankan stack Docker (make up && make seed), lalu:
//   flutter run -d windows --dart-define=OLT_SOCIAL_ANON_KEY=<ANON_KEY: make anon-key>
//   flutter run -d <emulator> --dart-define=OLT_SOCIAL_ANON_KEY=...
// Opsional: --dart-define=OLT_SOCIAL_URL=http://192.168.1.10:8000 (HP fisik).
// Web: make web-example, lalu buka http://localhost:8081 (?user=sari_invest = langsung login).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:olt_social/olt_social.dart';

import 'fake_olt_auth.dart';

const _anonKey = String.fromEnvironment('OLT_SOCIAL_ANON_KEY');
const _urlOverride = String.fromEnvironment('OLT_SOCIAL_URL');
const _dummyOltOverride = String.fromEnvironment('OLT_DUMMY_WS_URL');

/// Alamat API sosial:
/// * web: host yang sama dengan halaman, port 8000;
/// * emulator Android: localhost PC lewat 10.0.2.2;
/// * Windows: localhost.
String get socialUrl {
  if (_urlOverride.isNotEmpty) return _urlOverride;
  if (kIsWeb) return 'http://${Uri.base.host}:8000';
  return defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:8000' : 'http://localhost:8000';
}

/// Web: `?user=<username|id>` langsung login sebagai user seed itu (token mock),
/// supaya beberapa tab browser bisa dipakai sebagai user berbeda saat testing.
String? get autoLoginUser => kIsWeb ? Uri.base.queryParameters['user'] : null;

/// WebSocket OLT dummy (make up DUMMY_OLT=1): host yang sama dengan [socialUrl], port 8090.
String get dummyOltWsUrl => _dummyOltOverride.isNotEmpty
    ? _dummyOltOverride
    : Uri.parse(socialUrl).replace(scheme: 'ws', port: 8090, path: '/ws').toString();

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('id');

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5FFF), brightness: brightness),
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'OLT Social Example',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: _themeMode,
      locale: _locale,
      // Delegate olt_social + Material/Widgets/Cupertino bawaan.
      localizationsDelegates: OltSocialLocalizations.localizationsDelegates,
      supportedLocales: OltSocialLocalizations.supportedLocales,
      home: _anonKey.isEmpty
          ? const _MissingConfigPage()
          : const LoginPage(onSignedIn: _startSocial),
      builder: (context, child) => _SettingsScope(
        toggleTheme: () => setState(() {
          _themeMode = Theme.of(context).brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
        }),
        toggleLocale: () => setState(() {
          _locale = _locale.languageCode == 'id' ? const Locale('en') : const Locale('id');
        }),
        child: child!,
      ),
    );
  }

}

/// Inisialisasi olt_social setelah user login OLT. Token OLT diberikan lewat
/// callback; auth-bridge yang menukarnya menjadi JWT Supabase.
Future<void> _startSocial(FakeOltAuth auth) async {
  final social = await OltSocial.initialize(
    supabaseUrl: socialUrl,
    anonKey: _anonKey,
    oltTokenProvider: () async => auth.currentToken,
    onStockTap: openOltStockPage,
  );
  // Pastikan sesi sosial terbentuk (melempar OltSocialException bila gagal).
  await social.ensureSignedIn();
}

/// Akses toggle tema/bahasa dari halaman mana pun.
class _SettingsScope extends InheritedWidget {
  const _SettingsScope({required this.toggleTheme, required this.toggleLocale, required super.child});

  final VoidCallback toggleTheme;
  final VoidCallback toggleLocale;

  @override
  bool updateShouldNotify(_SettingsScope oldWidget) => false;
}

void toggleTheme(BuildContext context) =>
    context.getInheritedWidgetOfExactType<_SettingsScope>()?.toggleTheme();

void toggleLocale(BuildContext context) =>
    context.getInheritedWidgetOfExactType<_SettingsScope>()?.toggleLocale();

/// Contoh "halaman saham milik OLT" yang dibuka saat user mengetuk $KODE.
void openOltStockPage(BuildContext context, String code) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('Halaman saham OLT · $code')),
        body: OltStockFeed(stockCode: code),
      ),
    ),
  );
}

class _MissingConfigPage extends StatelessWidget {
  const _MissingConfigPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'OLT_SOCIAL_ANON_KEY belum diisi.\n\n'
          'Jalankan dengan:\nflutter run --dart-define=OLT_SOCIAL_ANON_KEY=<ANON_KEY: make anon-key>',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
