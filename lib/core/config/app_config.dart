/// App-wide configuration. Override serverUrl at runtime for LAN play.
class AppConfig {
  static String serverUrl = 'ws://localhost:8080/ws';

  static String get httpBase => serverUrl
      .replaceFirst('ws://', 'http://')
      .replaceFirst('wss://', 'https://');
}

