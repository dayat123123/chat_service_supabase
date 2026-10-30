import 'package:cs_console/src/app/console_app.dart';
import 'package:cs_console/src/app/console_config.dart';
import 'package:cs_console/src/app/console_dependencies.dart';
import 'package:cs_console/src/core/browser/session_tab_storage.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = ConsoleConfig.fromEnvironment();
  await Supabase.initialize(
    url: config.apiUrl,
    publishableKey: config.anonKey,
    authOptions: const FlutterAuthClientOptions(localStorage: SessionTabStorage(), detectSessionInUri: false),
  );
  runApp(ConsoleApp(deps: ConsoleDependencies.create(config, Supabase.instance.client)));
}
