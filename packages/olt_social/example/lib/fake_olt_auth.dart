import 'package:flutter/material.dart';

import 'home_page.dart';

/// Tiruan modul login OLT. Di aplikasi OLT asli, token didapat dari login
/// WebSocket OLT (username/email + password atau token). Di sini dipakai token
/// mock `mock:<olt_user_id>:<username>` yang diterima auth-bridge mode mock.
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

  Future<void> _login(String id, String username) async {
    setState(() => _busy = true);
    final auth = FakeOltAuth('mock:$id:$username');
    try {
      await widget.onSignedIn(auth);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal masuk ke OLT Social: $e')));
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
            ],
          ),
        ),
      ),
    );
  }
}
