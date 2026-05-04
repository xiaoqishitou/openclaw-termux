import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

class AppsCapability extends CapabilityHandler {
  @override
  String get name => 'apps';

  @override
  List<String> get commands => ['list', 'launch', 'openUrl'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'apps.list':
        return _list();
      case 'apps.launch':
        return _launch(params);
      case 'apps.openUrl':
        return _openUrl(params);
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown apps command: $command',
        });
    }
  }

  Future<NodeFrame> _list() async {
    try {
      final apps = await NativeBridge.getInstalledApps();
      return NodeFrame.response('', payload: {'apps': apps});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'APPS_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _launch(Map<String, dynamic> params) async {
    try {
      final packageName = params['packageName'] as String?;
      if (packageName == null) {
        return NodeFrame.response('', error: {
          'code': 'INVALID_ARGS',
          'message': 'packageName is required',
        });
      }
      final success = await NativeBridge.launchApp(packageName);
      return NodeFrame.response('', payload: {'success': success});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'APPS_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _openUrl(Map<String, dynamic> params) async {
    try {
      final url = params['url'] as String?;
      if (url == null) {
        return NodeFrame.response('', error: {
          'code': 'INVALID_ARGS',
          'message': 'url is required',
        });
      }
      final success = await NativeBridge.openUrl(url);
      return NodeFrame.response('', payload: {'success': success});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'APPS_ERROR',
        'message': '$e',
      });
    }
  }
}
