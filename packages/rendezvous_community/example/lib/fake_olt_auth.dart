import 'package:flutter/material.dart';
import 'package:rendezvous_community/rendezvous_community.dart' show CommunityException;

import 'dummy_olt_client.dart';
import 'home_page.dart';
import 'main.dart' show autoLoginUser, dummyOltWsUrl;

class FakeOltAuth {
  FakeOltAuth.fixed(String token) : _current = token, _renew = null;

  FakeOltAuth.dummy(DummyOltClient client, String session, DummySocialToken first)
    : _current = first.token,
      _expiresAt = first.expiresAt,
      _renew = (() => client.socialToken(session));

  final Future<DummySocialToken> Function()? _renew;
  String? _current;
  DateTime? _expiresAt;
  bool _signedOut = false;

  Future<String?> token() async {
    if (_signedOut) return null;
    final renew = _renew;
    final expiresAt = _expiresAt;
    if (renew != null && (expiresAt == null || expiresAt.difference(DateTime.now()) < const Duration(minutes: 1))) {
      try {
        final fresh = await renew();
        _current = fresh.token;
        _expiresAt = fresh.expiresAt;
      } on DummyOltException {
        _current = null;
      }
    }
    return _current;
  }

  void logout() {
    _signedOut = true;
    _current = null;
  }
}

const demoUsers = [
  ('1001', 'budi_santoso', 'Budi Santoso'),
  ('1002', 'sari_invest', 'Sari Wulandari'),
  ('1003', 'andi_trader', 'Andi Pratama'),
  ('1004', 'rina_saham', 'Rina Kartika'),
  ('1005', 'dewi_cuan', 'Dewi Lestari'),
  ('1011', 'hidayat', 'Hidayat'),
  ('1012', 'hidayat2', 'Hidayat 2'),
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

  Future<void> _login(String id, String username) => _proceed(() async {
    final mock = 'mock:$id:$username';
    final client = DummyOltClient(dummyOltWsUrl, timeout: const Duration(seconds: 3));
    try {
      return FakeOltAuth.dummy(client, mock, await client.socialToken(mock));
    } on DummyOltException {
      return FakeOltAuth.fixed(mock);
    }
  });

  Future<void> _loginDummyOlt() => _proceed(() async {
    final client = DummyOltClient(dummyOltWsUrl);
    final session = await client.loginWithPassword(_identifier.text, _password.text);
    return FakeOltAuth.dummy(client, session.token, session.socialToken);
  });

  Future<void> _proceed(Future<FakeOltAuth> Function() signIn) async {
    setState(() => _busy = true);
    final FakeOltAuth auth;
    try {
      auth = await signIn();
      await widget.onSignedIn(auth);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        final message = switch (e) {
          DummyOltException(:final message) => 'OLT sign-in failed: $message',
          CommunityException(:final kind, :final code) =>
            'Rendezvous Community sign-in failed (${[kind.name, ?code].join(', ')})',
          _ => 'Rendezvous Community sign-in failed: $e',
        };
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
                'Pilih akun untuk login cepat. Bila OLT dummy berjalan, akun ditukar menjadi token sosial '
                'bertanda tangan; bila tidak, dipakai token mock.',
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
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              const SizedBox(height: 24),
              Card.outlined(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Login OLT dummy', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Login ke OLT dummy, lalu token sosial bertanda tangan diverifikasi auth-bridge secara '
                        'lokal (mode jwt). Butuh stack: make up DUMMY_OLT=1. Semua akun dummy: password olt12345.',
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
