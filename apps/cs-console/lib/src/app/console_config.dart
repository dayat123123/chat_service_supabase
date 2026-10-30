class ConsoleConfig {
  const ConsoleConfig({required this.apiUrl, required this.anonKey});

  factory ConsoleConfig.fromEnvironment() => const ConsoleConfig(
    apiUrl: String.fromEnvironment('CS_CONSOLE_API', defaultValue: 'http://localhost:8000'),
    anonKey: String.fromEnvironment('CS_CONSOLE_ANON_KEY'),
  );

  final String apiUrl;
  final String anonKey;

  String get adapterUrl => '$apiUrl/cs/v1';
}
