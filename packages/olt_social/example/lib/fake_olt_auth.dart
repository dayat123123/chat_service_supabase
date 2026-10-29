import 'package:flutter/material.dart';

import 'dummy_olt_client.dart';
import 'home_page.dart';
import 'main.dart' show autoLoginUser, dummyOltWsUrl;

/// Tiruan modul login OLT. Di aplikasi OLT asli, token didapat dari login
/// WebSocket OLT (username/email + password atau token). Di sini token berasal dari:
/// * token mock `mock:<olt_user_id>:<username>` (auth-bridge mode mock), atau
/// * login ke OLT dummy lewat WebSocket (auth-bridge mode websocket,
///   `make up DUMMY_OLT=1`).
class FakeOltAuth {
  FakeOltAuth(this.currentToken);

  String? currentToken;

  void logout() => currentToken = null;
}

/// User seed (lihat supabase/seed/seed.sql).
const demoUsers = [
  ('1001', 'budi_santoso', 'Budi Santoso'),
  ('1002', 'sari_invest', 'Sari Wulandari'),
  ('1003', 'andi_trader', 'Andi Pratama'),
  ('1004', 'rina_saham', 'Rina Kartika'),
  ('1005', 'dewi_cuan', 'Dewi Lestari'),
];

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onSignedIn});

  final Future<void> Function(FakeOltAuth auth) onSignedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _busy = false;
  final _identifier = TextEditingController(text: 'budi_santoso');
  final _password = TextEditingController(text: 'olt12345');

  @override
  void initState() {
    super.initState();
    // Web: http://localhost:8081/?user=sari_invest langsung masuk sebagai Sari.
    final wanted = autoLoginUser;
    final match = demoUsers.where((u) => u.$1 == wanted || u.$2 == wanted).firstOrNull;
    if (match != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _login(match.$1, match.$2));
    }
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login(String id, String username) => _proceed(() async => FakeOltAuth('mock:$id:$username'));

  /// Login ke OLT dummy lewat WebSocket (seperti aplikasi OLT), lalu pakai tokennya.
  Future<void> _loginDummyOlt() => _proceed(() async {
    final session = await DummyOltClient(dummyOltWsUrl).loginWithPassword(_identifier.text, _password.text);
    return FakeOltAuth(session.token);
  });

  Future<void> _proceed(Future<FakeOltAuth> Function() oltLogin) async {
    setState(() => _busy = true);
    final FakeOltAuth auth;
    try {
      auth = await oltLogin();
      await widget.onSignedIn(auth);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        final message = e is DummyOltException ? 'Login OLT gagal: ${e.message}' : 'Gagal masuk ke OLT Social: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HomePage(auth: auth)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Icon(Icons.candlestick_chart, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text('Rendezvous OLT (demo)', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Pilih akun untuk login (token mock). Di OLT asli, login tetap lewat WebSocket OLT.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              for (final (id, username, name) in demoUsers)
                Card(
                  child: ListTile(
                    enabled: !_busy,
                    leading: CircleAvatar(child: Text(name[0])),
                    title: Text(name),
                    subtitle: Text('@$username · OLT id $id'),
                    trailing: const Icon(Icons.login),
                    onTap: () => _login(id, username),
                  ),
                ),
              if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              const SizedBox(height: 24),
              Card.outlined(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Login OLT dummy (WebSocket)', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Token asli dari OLT dummy, diverifikasi auth-bridge mode websocket. '
                        'Butuh stack: make up DUMMY_OLT=1. Semua akun dummy: password olt12345.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _identifier,
                        enabled: !_busy,
                        decoration: const InputDecoration(labelText: 'Username / email', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: true,
                        onSubmitted: (_) => _loginDummyOlt(),
                        decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy ? null : _loginDummyOlt,
                        icon: const Icon(Icons.lan_outlined),
                        label: const Text('Masuk via OLT dummy'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
