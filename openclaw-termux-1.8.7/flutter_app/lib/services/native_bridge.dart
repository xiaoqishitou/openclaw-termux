import 'package:flutter/services.dart';
import '../constants.dart';

class NativeBridge {
  static const _channel = MethodChannel(AppConstants.channelName);
  static const _eventChannel = EventChannel(AppConstants.eventChannelName);

  static Future<String> getProotPath() async {
    return await _channel.invokeMethod('getProotPath');
  }

  static Future<String> getArch() async {
    return await _channel.invokeMethod('getArch');
  }

  static Future<String> getFilesDir() async {
    return await _channel.invokeMethod('getFilesDir');
  }

  static Future<String> getNativeLibDir() async {
    return await _channel.invokeMethod('getNativeLibDir');
  }

  static Future<bool> isBootstrapComplete() async {
    return await _channel.invokeMethod('isBootstrapComplete');
  }

  static Future<Map<String, dynamic>> getBootstrapStatus() async {
    final result = await _channel.invokeMethod('getBootstrapStatus');
    return Map<String, dynamic>.from(result);
  }

  static Future<bool> extractRootfs(String tarPath) async {
    return await _channel.invokeMethod('extractRootfs', {'tarPath': tarPath});
  }

  static Future<String> runInProot(String command, {int timeout = 900}) async {
    return await _channel.invokeMethod('runInProot', {'command': command, 'timeout': timeout});
  }

  static Future<bool> startGateway() async {
    return await _channel.invokeMethod('startGateway');
  }

  static Future<bool> stopGateway() async {
    return await _channel.invokeMethod('stopGateway');
  }

  static Future<bool> isGatewayRunning() async {
    return await _channel.invokeMethod('isGatewayRunning');
  }

  /// 检测是否在模拟器上运行
  static Future<bool> isEmulator() async {
    try {
      return await _channel.invokeMethod('isEmulator');
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setupDirs() async {
    return await _channel.invokeMethod('setupDirs');
  }

  static Future<bool> installBionicBypass() async {
    return await _channel.invokeMethod('installBionicBypass');
  }

  static Future<bool> writeResolv() async {
    return await _channel.invokeMethod('writeResolv');
  }

  static Future<int> extractDebPackages() async {
    return await _channel.invokeMethod('extractDebPackages');
  }

  static Future<bool> extractNodeTarball(String tarPath) async {
    return await _channel.invokeMethod('extractNodeTarball', {'tarPath': tarPath});
  }

  static Future<bool> createBinWrappers(String packageName) async {
    return await _channel.invokeMethod('createBinWrappers', {'packageName': packageName});
  }

  static Future<bool> startTerminalService() async {
    return await _channel.invokeMethod('startTerminalService');
  }

  static Future<bool> stopTerminalService() async {
    return await _channel.invokeMethod('stopTerminalService');
  }

  static Future<bool> isTerminalServiceRunning() async {
    return await _channel.invokeMethod('isTerminalServiceRunning');
  }

  static Future<bool> startNodeService() async {
    return await _channel.invokeMethod('startNodeService');
  }

  static Future<bool> stopNodeService() async {
    return await _channel.invokeMethod('stopNodeService');
  }

  static Future<bool> isNodeServiceRunning() async {
    return await _channel.invokeMethod('isNodeServiceRunning');
  }

  static Future<Map<String, dynamic>> getBatteryStatus() async {
    final result = await _channel.invokeMethod('getBatteryStatus');
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<bool> updateNodeNotification(String text) async {
    return await _channel.invokeMethod('updateNodeNotification', {'text': text});
  }

  static Future<bool> requestBatteryOptimization() async {
    return await _channel.invokeMethod('requestBatteryOptimization');
  }

  static Future<bool> isBatteryOptimized() async {
    return await _channel.invokeMethod('isBatteryOptimized');
  }

  static Future<bool> startSetupService() async {
    return await _channel.invokeMethod('startSetupService');
  }

  static Future<bool> updateSetupNotification(String text, {int progress = -1}) async {
    return await _channel.invokeMethod('updateSetupNotification', {'text': text, 'progress': progress});
  }

  static Future<bool> stopSetupService() async {
    return await _channel.invokeMethod('stopSetupService');
  }

  static Future<bool> showUrlNotification(String url, {String title = 'URL Detected'}) async {
    return await _channel.invokeMethod('showUrlNotification', {'url': url, 'title': title});
  }

  static Stream<String> get gatewayLogStream {
    return _eventChannel.receiveBroadcastStream().map((event) => event.toString());
  }

  static Future<String?> requestScreenCapture(int durationMs) async {
    return await _channel.invokeMethod('requestScreenCapture', {'durationMs': durationMs});
  }

  static Future<bool> stopScreenCapture() async {
    return await _channel.invokeMethod('stopScreenCapture');
  }

  static Future<bool> requestStoragePermission() async {
    return await _channel.invokeMethod('requestStoragePermission');
  }

  static Future<bool> hasStoragePermission() async {
    return await _channel.invokeMethod('hasStoragePermission');
  }

  static Future<String> getExternalStoragePath() async {
    return await _channel.invokeMethod('getExternalStoragePath');
  }

  static Future<String?> readRootfsFile(String path) async {
    return await _channel.invokeMethod('readRootfsFile', {'path': path});
  }

  static Future<bool> writeRootfsFile(String path, String content) async {
    return await _channel.invokeMethod('writeRootfsFile', {'path': path, 'content': content});
  }

  // SSH Service
  static Future<bool> startSshd({int port = 8022}) async {
    return await _channel.invokeMethod('startSshd', {'port': port});
  }

  static Future<bool> stopSshd() async {
    return await _channel.invokeMethod('stopSshd');
  }

  static Future<bool> isSshdRunning() async {
    return await _channel.invokeMethod('isSshdRunning');
  }

  static Future<int> getSshdPort() async {
    return await _channel.invokeMethod('getSshdPort');
  }

  static Future<List<String>> getDeviceIps() async {
    final result = await _channel.invokeMethod('getDeviceIps');
    return List<String>.from(result);
  }

  static Future<bool> bringToForeground() async {
    return await _channel.invokeMethod('bringToForeground');
  }

  static Future<bool> setRootPassword(String password) async {
    return await _channel.invokeMethod('setRootPassword', {'password': password});
  }

  static Future<bool> copyBundledAsset(String assetPath, String destPath) async {
    return await _channel.invokeMethod('copyBundledAsset', {'assetPath': assetPath, 'destPath': destPath});
  }

  // ========== 文件系统工具 ==========

  static Future<Map<String, dynamic>> listDirectory(String path) async {
    final result = await _channel.invokeMethod('listDirectory', {'path': path});
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<String?> readFile(String path, {int? limit}) async {
    return await _channel.invokeMethod('readFile', {'path': path, 'limit': limit});
  }

  static Future<bool> writeFile(String path, String content) async {
    return await _channel.invokeMethod('writeFile', {'path': path, 'content': content});
  }

  static Future<bool> deleteFile(String path) async {
    return await _channel.invokeMethod('deleteFile', {'path': path});
  }

  static Future<bool> createDirectory(String path) async {
    return await _channel.invokeMethod('createDirectory', {'path': path});
  }

  static Future<Map<String, dynamic>> getFileInfo(String path) async {
    final result = await _channel.invokeMethod('getFileInfo', {'path': path});
    return Map<String, dynamic>.from(result as Map);
  }

  // ========== 应用管理工具 ==========

  static Future<List<dynamic>> getInstalledApps() async {
    final result = await _channel.invokeMethod('getInstalledApps');
    return List<dynamic>.from(result);
  }

  static Future<bool> launchApp(String packageName) async {
    return await _channel.invokeMethod('launchApp', {'packageName': packageName});
  }

  static Future<bool> openUrl(String url) async {
    return await _channel.invokeMethod('openUrl', {'url': url});
  }

  // ========== 剪贴板工具 ==========

  static Future<String?> getClipboardText() async {
    return await _channel.invokeMethod('getClipboardText');
  }

  static Future<bool> setClipboardText(String text) async {
    return await _channel.invokeMethod('setClipboardText', {'text': text});
  }

  // ========== 手电筒工具 ==========

  static Future<bool> toggleFlashlight(bool on) async {
    return await _channel.invokeMethod('toggleFlashlight', {'on': on});
  }

  static Future<bool> isFlashlightAvailable() async {
    return await _channel.invokeMethod('isFlashlightAvailable');
  }

  // ========== 设备信息工具 ==========

  static Future<Map<String, dynamic>> getDeviceInfo() async {
    final result = await _channel.invokeMethod('getDeviceInfo');
    return Map<String, dynamic>.from(result as Map);
  }

  // ========== 联系人工具 ==========

  static Future<List<dynamic>> getContacts() async {
    final result = await _channel.invokeMethod('getContacts');
    return List<dynamic>.from(result);
  }

  // ========== 通话记录工具 ==========

  static Future<List<dynamic>> getCallLogs({int limit = 100}) async {
    final result = await _channel.invokeMethod('getCallLogs', {'limit': limit});
    return List<dynamic>.from(result);
  }

  // ========== 短信工具 ==========

  static Future<List<dynamic>> getSmsMessages({int limit = 100}) async {
    final result = await _channel.invokeMethod('getSmsMessages', {'limit': limit});
    return List<dynamic>.from(result);
  }

  static Future<bool> sendSms(String phoneNumber, String message) async {
    return await _channel.invokeMethod('sendSms', {'phoneNumber': phoneNumber, 'message': message});
  }
}
