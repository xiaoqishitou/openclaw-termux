import 'dart:convert';
import '../models/bot_platform.dart';
import 'native_bridge.dart';

/// 机器人平台配置服务
class BotConfigService {
  static const _configPath = '/root/.openclaw/bots.json';

  static String _shellEscape(String s) {
    return "'${s.replaceAll("'", "'\\''")}'";
  }

  /// 读取所有机器人平台配置
  static Future<Map<String, dynamic>> readConfig() async {
    try {
      final content = await NativeBridge.readRootfsFile(_configPath);
      if (content == null || content.isEmpty) {
        return {};
      }
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// 保存单个平台的配置
  static Future<void> savePlatformConfig({
    required BotPlatform platform,
    required Map<String, String> values,
    required bool enabled,
  }) async {
    final platformIdJson = jsonEncode(platform.id);
    final valuesJson = jsonEncode(values);
    final enabledJson = jsonEncode(enabled);

    final script = '''
const fs = require("fs");
const p = "$_configPath";
let c = {};
try { c = JSON.parse(fs.readFileSync(p, "utf8")); } catch {}
if (!c.platforms) c.platforms = {};
c.platforms[$platformIdJson] = {
  enabled: $enabledJson,
  config: $valuesJson
};
fs.mkdirSync(require("path").dirname(p), { recursive: true });
fs.writeFileSync(p, JSON.stringify(c, null, 2));
''';
    try {
      await NativeBridge.runInProot(
        'node -e ${_shellEscape(script)}',
        timeout: 15,
      );
    } catch (_) {
      await _saveConfigDirect(platform.id, values, enabled);
    }
  }

  /// 直接写入配置的 fallback
  static Future<void> _saveConfigDirect(
    String platformId,
    Map<String, String> values,
    bool enabled,
  ) async {
    Map<String, dynamic> config = {};
    try {
      final content = await NativeBridge.readRootfsFile(_configPath);
      if (content != null && content.isNotEmpty) {
        config = jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (_) {}

    config['platforms'] ??= <String, dynamic>{};
    (config['platforms'] as Map<String, dynamic>)[platformId] = {
      'enabled': enabled,
      'config': values,
    };

    const encoder = JsonEncoder.withIndent('  ');
    await NativeBridge.writeRootfsFile(_configPath, encoder.convert(config));
  }

  /// 移除平台配置
  static Future<void> removePlatformConfig(BotPlatform platform) async {
    final platformIdJson = jsonEncode(platform.id);
    final script = '''
const fs = require("fs");
const p = "$_configPath";
let c = {};
try { c = JSON.parse(fs.readFileSync(p, "utf8")); } catch {}
if (c.platforms && c.platforms[$platformIdJson]) {
  delete c.platforms[$platformIdJson];
}
fs.writeFileSync(p, JSON.stringify(c, null, 2));
''';
    try {
      await NativeBridge.runInProot(
        'node -e ${_shellEscape(script)}',
        timeout: 15,
      );
    } catch (_) {
      await _removeConfigDirect(platform.id);
    }
  }

  static Future<void> _removeConfigDirect(String platformId) async {
    Map<String, dynamic> config = {};
    try {
      final content = await NativeBridge.readRootfsFile(_configPath);
      if (content != null && content.isNotEmpty) {
        config = jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (_) {}

    final platforms = config['platforms'] as Map<String, dynamic>?;
    if (platforms != null) {
      platforms.remove(platformId);
    }

    const encoder = JsonEncoder.withIndent('  ');
    await NativeBridge.writeRootfsFile(_configPath, encoder.convert(config));
  }
}
