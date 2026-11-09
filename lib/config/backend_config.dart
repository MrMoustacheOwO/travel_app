import 'package:shared_preferences/shared_preferences.dart';

class BackendConfig {
  static const String _prefKey = 'backend_base_url';
  static const String _defaultLanUrl = 'http://192.168.1.50:8080';
  static const String _defaultEmulatorUrl = 'http://10.0.2.2:8080';
  static String _cachedBaseUrl = '';

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    _cachedBaseUrl = _normalizeUrl(stored ?? _defaultBaseUrl);
  }

  static Future<void> setBaseUrl(String value) async {
    final normalized = _normalizeUrl(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, normalized);
    _cachedBaseUrl = normalized;
  }

  static String get baseUrl {
    if (_cachedBaseUrl.isNotEmpty) {
      return _cachedBaseUrl;
    }

    const configured = String.fromEnvironment(
      'APP_BACKEND_URL',
      defaultValue: '',
    );

    if (configured.trim().isNotEmpty) {
      return _normalizeUrl(configured);
    }

    return _normalizeUrl(_defaultBaseUrl);
  }

  static String get defaultLanUrl => _defaultLanUrl;
  static String get defaultEmulatorUrl => _defaultEmulatorUrl;

  static String get _defaultBaseUrl {
    return _defaultLanUrl;
  }

  static String _normalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return _defaultLanUrl;
    }

    final withProtocol = trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'http://$trimmed';

    return withProtocol.endsWith('/')
        ? withProtocol.substring(0, withProtocol.length - 1)
        : withProtocol;
  }
}
