import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

class DeviceInfoCapability extends CapabilityHandler {
  @override
  String get name => 'deviceinfo';

  @override
  List<String> get commands => ['info', 'battery'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'deviceinfo.info':
        return _getInfo();
      case 'deviceinfo.battery':
        return _getBattery();
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown deviceinfo command: $command',
        });
    }
  }

  Future<NodeFrame> _getInfo() async {
    try {
      final info = await NativeBridge.getDeviceInfo();
      return NodeFrame.response('', payload: info);
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'DEVICEINFO_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _getBattery() async {
    try {
      final battery = await NativeBridge.getBatteryStatus();
      return NodeFrame.response('', payload: battery);
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'DEVICEINFO_ERROR',
        'message': '$e',
      });
    }
  }
}
