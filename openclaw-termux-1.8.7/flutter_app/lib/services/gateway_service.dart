import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/gateway_state.dart';
import 'native_bridge.dart';
import 'preferences_service.dart';

/// 优化的网关服务，提升启动速度和稳定性
class GatewayService {
  Timer? _healthTimer;
  Timer? _initialDelayTimer;
  Timer? _fastCheckTimer;
  StreamSubscription? _logSubscription;
  final _stateController = StreamController<GatewayState>.broadcast();
  GatewayState _state = const GatewayState();
  DateTime? _startingAt;
  bool _startInProgress = false;
  bool _isDisposed = false;
  int _consecutiveFailures = 0;
  static const int _maxFastChecks = 15;
  int _autoRestartAttempts = 0;
  static const int _maxAutoRestarts = 2;
  DateTime? _lastAutoRestart;

  static final _tokenUrlRegex = RegExp(r'https?://(?:localhost|127\.0\.0\.1):18789/#token=[0-9a-f]+');
  static final _boxDrawing = RegExp(r'[│┤├┬┴┼╮╯╰╭─╌╴╶┌┐└┘◇◆]+');

  /// Strip ANSI, box-drawing chars, and whitespace to reconstruct URLs
  static String _cleanForUrl(String text) {
    return text
        .replaceAll(AppConstants.ansiEscape, '')
        .replaceAll(_boxDrawing, '')
        .replaceAll(RegExp(r'\s+'), '');
  }

  static String _ts(String msg) => '${DateTime.now().toUtc().toIso8601String()} $msg';

  Stream<GatewayState> get stateStream => _stateController.stream;
  GatewayState get state => _state;

  void _updateState(GatewayState newState) {
    if (_isDisposed) return;
    _state = newState;
    _stateController.add(_state);
  }

  /// Check if the gateway is already running and sync the UI state.
  /// If not running but auto-start is enabled, start it automatically.
  Future<void> init() async {
    final prefs = PreferencesService();
    await prefs.init();
    final savedUrl = prefs.dashboardUrl;

    // 并行执行目录设置和 DNS 配置，减少等待时间
    await Future.wait([
      _ensureDirectories(),
      _ensureDnsConfig(),
    ]);

    // Repair corrupted config before gateway start
    await _repairConfigFile();

    final alreadyRunning = await NativeBridge.isGatewayRunning();
    if (alreadyRunning) {
      await _writeNodeAllowConfig();
      final configToken = await _readTokenFromConfig();
      final effectiveUrl = configToken != null
          ? 'http://localhost:18789/#token=$configToken'
          : savedUrl;
      if (configToken != null) prefs.dashboardUrl = effectiveUrl;
      _startingAt = DateTime.now();
      _updateState(_state.copyWith(
        status: GatewayStatus.starting,
        dashboardUrl: effectiveUrl,
        logs: [..._state.logs, _ts('[INFO] Gateway process detected, reconnecting...')],
      ));

      _subscribeLogs();
      _startHealthCheck();
    } else if (prefs.autoStartGateway) {
      _updateState(_state.copyWith(
        logs: [..._state.logs, _ts('[INFO] Auto-starting gateway...')],
      ));
      await start();
    }
  }

  /// 并行确保目录存在
  Future<void> _ensureDirectories() async {
    try {
      await NativeBridge.setupDirs();
    } catch (_) {
      // Fallback to dart:io
      try {
        final filesDir = await NativeBridge.getFilesDir();
        Directory('$filesDir/config').createSync(recursive: true);
        Directory('$filesDir/rootfs/ubuntu/root/.openclaw').createSync(recursive: true);
      } catch (_) {}
    }
  }

  /// 并行确保 DNS 配置
  Future<void> _ensureDnsConfig() async {
    const resolvContent = 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n';
    try {
      await NativeBridge.writeResolv();
    } catch (_) {
      try {
        final filesDir = await NativeBridge.getFilesDir();
        final resolvFile = File('$filesDir/config/resolv.conf');
        if (!resolvFile.existsSync()) {
          resolvFile.parent.createSync(recursive: true);
          resolvFile.writeAsStringSync(resolvContent);
        }
        final rootfsResolv = File('$filesDir/rootfs/ubuntu/etc/resolv.conf');
        if (!rootfsResolv.existsSync()) {
          rootfsResolv.parent.createSync(recursive: true);
          rootfsResolv.writeAsStringSync(resolvContent);
        }
      } catch (_) {}
    }
  }

  void _subscribeLogs() {
    _logSubscription?.cancel();
    _logSubscription = NativeBridge.gatewayLogStream.listen(
      (log) {
        final logs = [..._state.logs, log];
        if (logs.length > 500) {
          logs.removeRange(0, logs.length - 500);
        }
        String? dashboardUrl;
        final cleanLog = _cleanForUrl(log);
        final urlMatch = _tokenUrlRegex.firstMatch(cleanLog);
        if (urlMatch != null) {
          dashboardUrl = urlMatch.group(0);
          final prefs = PreferencesService();
          prefs.init().then((_) => prefs.dashboardUrl = dashboardUrl);
          if (dashboardUrl != null) {
            NativeBridge.showUrlNotification(dashboardUrl, title: 'Dashboard Ready');
          }
        }
        _updateState(_state.copyWith(logs: logs, dashboardUrl: dashboardUrl));
      },
      onError: (_) {},
    );
  }

  Future<void> _writeNodeAllowConfig() async {
    const allowCommands = [
      'camera.snap', 'camera.clip', 'camera.list',
      'canvas.navigate', 'canvas.eval', 'canvas.snapshot',
      'flash.on', 'flash.off', 'flash.toggle', 'flash.status',
      'location.get',
      'battery.status',
      'screen.record',
      'sensor.read', 'sensor.list',
      'haptic.vibrate',
      'serial.list', 'serial.connect', 'serial.disconnect', 'serial.write', 'serial.read',
      // 新增系统工具命令
      'filesystem.list', 'filesystem.read', 'filesystem.write', 'filesystem.delete',
      'filesystem.mkdir', 'filesystem.info', 'filesystem.readRootfs', 'filesystem.writeRootfs',
      'apps.list', 'apps.launch', 'apps.openUrl',
      'clipboard.read', 'clipboard.write',
      'flashlight.toggle', 'flashlight.on', 'flashlight.off', 'flashlight.status',
      'deviceinfo.info', 'deviceinfo.battery',
      'contacts.list', 'contacts.callLogs', 'contacts.sms', 'contacts.sendSms',
    ];
    final allowJson = jsonEncode(allowCommands);
    final script = '''
const fs = require("fs");
const p = "/root/.openclaw/openclaw.json";
let c = {};
try { c = JSON.parse(fs.readFileSync(p, "utf8")); } catch {}
if (!c.gateway) c.gateway = {};
if (!c.gateway.mode) c.gateway.mode = "local";
if (!c.gateway.nodes) c.gateway.nodes = {};
c.gateway.nodes.denyCommands = [];
c.gateway.nodes.allowCommands = $allowJson;
if (c.models && c.models.providers) {
  for (const [pid, prov] of Object.entries(c.models.providers)) {
    if (prov && Array.isArray(prov.models)) {
      prov.models = prov.models.map(m => typeof m === "string" ? { id: m } : m);
    }
  }
}
fs.writeFileSync(p, JSON.stringify(c, null, 2));
''';
    var prootOk = false;
    try {
      await NativeBridge.runInProot(
        'node -e ${_shellEscape(script)}',
        timeout: 15,
      );
      prootOk = true;
    } catch (_) {}

    if (!prootOk) {
      try {
        final filesDir = await NativeBridge.getFilesDir();
        final configFile = File('$filesDir/rootfs/ubuntu/root/.openclaw/openclaw.json');
        Map<String, dynamic> config = {};
        if (configFile.existsSync()) {
          try {
            config = Map<String, dynamic>.from(
                jsonDecode(configFile.readAsStringSync()) as Map);
          } catch (_) {}
        }
        config.putIfAbsent('gateway', () => <String, dynamic>{});
        final gw = config['gateway'] as Map<String, dynamic>;
        gw.putIfAbsent('mode', () => 'local');
        gw.putIfAbsent('nodes', () => <String, dynamic>{});
        final nodes = gw['nodes'] as Map<String, dynamic>;
        nodes['denyCommands'] = <String>[];
        nodes['allowCommands'] = allowCommands;
        _repairModelEntries(config);
        configFile.parent.createSync(recursive: true);
        configFile.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(config),
        );
      } catch (_) {}
    }
  }

  Future<void> _repairConfigFile() async {
    try {
      final filesDir = await NativeBridge.getFilesDir();
      final configFile = File('$filesDir/rootfs/ubuntu/root/.openclaw/openclaw.json');
      if (!configFile.existsSync()) return;
      final content = configFile.readAsStringSync();
      if (content.isEmpty) return;

      Map<String, dynamic> config;
      try {
        config = Map<String, dynamic>.from(jsonDecode(content) as Map);
      } catch (_) {
        return;
      }

      bool modified = false;
      config.putIfAbsent('gateway', () => <String, dynamic>{});
      final gw = config['gateway'] as Map<String, dynamic>;
      if (!gw.containsKey('mode')) {
        gw['mode'] = 'local';
        modified = true;
      }

      final models = config['models'] as Map<String, dynamic>?;
      if (models != null) {
        final providers = models['providers'] as Map<String, dynamic>?;
        if (providers != null) {
          for (final entry in providers.values) {
            if (entry is Map<String, dynamic>) {
              final modelsList = entry['models'];
              if (modelsList is List) {
                for (int i = 0; i < modelsList.length; i++) {
                  if (modelsList[i] is String) {
                    modelsList[i] = {'id': modelsList[i]};
                    modified = true;
                  }
                }
              }
            }
          }
        }
      }

      if (modified) {
        configFile.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(config),
        );
      }
    } catch (_) {}
  }

  static void _repairModelEntries(Map<String, dynamic> config) {
    final models = config['models'] as Map<String, dynamic>?;
    if (models == null) return;
    final providers = models['providers'] as Map<String, dynamic>?;
    if (providers == null) return;
    for (final entry in providers.values) {
      if (entry is Map<String, dynamic>) {
        final modelsList = entry['models'];
        if (modelsList is List) {
          entry['models'] = modelsList.map((m) {
            if (m is String) return {'id': m};
            return m;
          }).toList();
        }
      }
    }
  }

  Future<String?> _readTokenFromConfig() async {
    try {
      final raw = await NativeBridge.readRootfsFile('root/.openclaw/openclaw.json');
      if (raw == null) return null;
      final config = jsonDecode(raw) as Map<String, dynamic>;
      final token = config['gateway']?['auth']?['token'];
      if (token is String && token.isNotEmpty) return token;
    } catch (_) {}
    return null;
  }

  static String _shellEscape(String s) {
    return "'${s.replaceAll("'", "'\\''")}'";
  }

  Future<void> start() async {
    if (_startInProgress) return;
    _startInProgress = true;
    _consecutiveFailures = 0;
    _autoRestartAttempts = 0;

    final prefs = PreferencesService();
    await prefs.init();
    prefs.dashboardUrl = null;

    _updateState(_state.copyWith(
      status: GatewayStatus.starting,
      clearError: true,
      clearDashboardUrl: true,
      logs: [..._state.logs, _ts('[INFO] Starting gateway...')],
    ));

    try {
      // 并行执行准备工作
      await Future.wait([
        _ensureDirectories(),
        _ensureDnsConfig(),
      ]);
      await _writeNodeAllowConfig();
      _startingAt = DateTime.now();
      await NativeBridge.startGateway();
      _subscribeLogs();
      _startHealthCheck();
    } catch (e) {
      _updateState(_state.copyWith(
        status: GatewayStatus.error,
        errorMessage: 'Failed to start: $e',
        logs: [..._state.logs, _ts('[ERROR] Failed to start: $e')],
      ));
    } finally {
      _startInProgress = false;
    }
  }

  Future<void> stop() async {
    _cancelAllTimers();
    _logSubscription?.cancel();
    _startingAt = null;

    try {
      await NativeBridge.stopGateway();
      _updateState(GatewayState(
        status: GatewayStatus.stopped,
        logs: [..._state.logs, _ts('[INFO] Gateway stopped')],
      ));
    } catch (e) {
      _updateState(_state.copyWith(
        status: GatewayStatus.error,
        errorMessage: 'Failed to stop: $e',
      ));
    }
  }

  void _cancelAllTimers() {
    _initialDelayTimer?.cancel();
    _initialDelayTimer = null;
    _healthTimer?.cancel();
    _healthTimer = null;
    _fastCheckTimer?.cancel();
    _fastCheckTimer = null;
  }

  /// 优化的健康检查：
  /// 1. 启动后快速检查（每2秒，最多15次）
  /// 2. 成功后切换到常规检查（每5秒）
  /// 3. 失败重试机制
  void _startHealthCheck() {
    _cancelAllTimers();
    int fastCheckCount = 0;

    // 快速检查阶段：启动后每2秒检查一次
    _fastCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_state.status == GatewayStatus.stopped || _isDisposed) {
        timer.cancel();
        return;
      }

      fastCheckCount++;
      if (fastCheckCount > _maxFastChecks) {
        timer.cancel();
        _fastCheckTimer = null;
        // 切换到常规检查
        _healthTimer = Timer.periodic(
          const Duration(milliseconds: AppConstants.healthCheckIntervalMs),
          (_) => _checkHealth(),
        );
        return;
      }

      await _checkHealthFast();
    });
  }

  /// 快速健康检查，减少延迟
  Future<void> _checkHealthFast() async {
    try {
      final response = await http
          .head(Uri.parse(AppConstants.gatewayUrl))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode < 500 && _state.status != GatewayStatus.running) {
        String? configUrl = _state.dashboardUrl;
        try {
          final token = await _readTokenFromConfig();
          if (token != null) {
            configUrl = 'http://localhost:18789/#token=$token';
            final prefs = PreferencesService();
            await prefs.init();
            prefs.dashboardUrl = configUrl;
          }
        } catch (_) {}

        _updateState(_state.copyWith(
          status: GatewayStatus.running,
          startedAt: DateTime.now(),
          dashboardUrl: configUrl,
          logs: [..._state.logs, _ts('[INFO] Gateway is healthy')],
        ));

        // 成功后取消快速检查，切换到常规检查
        _fastCheckTimer?.cancel();
        _fastCheckTimer = null;
        _healthTimer = Timer.periodic(
          const Duration(milliseconds: AppConstants.healthCheckIntervalMs),
          (_) => _checkHealth(),
        );
      }
    } catch (_) {
      // 快速检查阶段不记录错误，避免日志刷屏
    }
  }

  Future<void> _checkHealth() async {
    try {
      final response = await http
          .head(Uri.parse(AppConstants.gatewayUrl))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode < 500 && _state.status != GatewayStatus.running) {
        String? configUrl = _state.dashboardUrl;
        try {
          final token = await _readTokenFromConfig();
          if (token != null) {
            configUrl = 'http://localhost:18789/#token=$token';
            final prefs = PreferencesService();
            await prefs.init();
            prefs.dashboardUrl = configUrl;
          }
        } catch (_) {}

        _consecutiveFailures = 0;
        _updateState(_state.copyWith(
          status: GatewayStatus.running,
          startedAt: DateTime.now(),
          dashboardUrl: configUrl,
          logs: [..._state.logs, _ts('[INFO] Gateway is healthy')],
        ));
      } else if (response.statusCode < 500) {
        // 正常运行中，重置失败计数
        _consecutiveFailures = 0;
      }
    } catch (_) {
      _consecutiveFailures++;
      final isRunning = await NativeBridge.isGatewayRunning();
      if (!isRunning && _state.status != GatewayStatus.stopped) {
        // 增加容错：连续失败3次才判定为停止
        if (_startingAt != null &&
            _state.status == GatewayStatus.starting &&
            DateTime.now().difference(_startingAt!).inSeconds < 120) {
          _updateState(_state.copyWith(
            logs: [..._state.logs, _ts('[INFO] Starting, waiting for gateway...')],
          ));
          return;
        }
        if (_consecutiveFailures < 3) {
          // 短暂失败，继续等待
          return;
        }
        _updateState(_state.copyWith(
          status: GatewayStatus.stopped,
          logs: [..._state.logs, _ts('[WARN] Gateway process not running')],
        ));
        _cancelAllTimers();

        // 自动重启：如果网关意外停止且未超过最大重试次数
        _tryAutoRestart();
      }
    }
  }

  void _tryAutoRestart() {
    if (_autoRestartAttempts >= _maxAutoRestarts) return;
    final now = DateTime.now();
    if (_lastAutoRestart != null && now.difference(_lastAutoRestart!).inMinutes < 5) return;

    _autoRestartAttempts++;
    _lastAutoRestart = now;

    _updateState(_state.copyWith(
      logs: [..._state.logs, _ts('[INFO] 自动重启网关（第 $_autoRestartAttempts 次）...')],
    ));

    Future.delayed(const Duration(seconds: 3), () {
      if (_state.status == GatewayStatus.stopped && !_isDisposed) {
        start();
      }
    });
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http
          .head(Uri.parse(AppConstants.gatewayUrl))
          .timeout(const Duration(seconds: 3));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _isDisposed = true;
    _cancelAllTimers();
    _logSubscription?.cancel();
    _stateController.close();
  }
}
