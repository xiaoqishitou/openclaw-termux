import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

class FlashlightCapability extends CapabilityHandler {
  @override
  String get name => 'flashlight';

  @override
  List<String> get commands => ['toggle', 'on', 'off', 'status'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'flashlight.toggle':
        return _toggle(params);
      case 'flashlight.on':
        return _turnOn();
      case 'flashlight.off':
        return _turnOff();
      case 'flashlight.status':
        return _status();
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown flashlight command: $command',
        });
    }
  }

  Future<NodeFrame> _toggle(Map<String, dynamic> params) async {
    try {
      final on = params['on'] as bool? ?? false;
      final success = await NativeBridge.toggleFlashlight(on);
      return NodeFrame.response('', payload: {
        'success': success,
        'on': on,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'FLASHLIGHT_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _turnOn() async {
    try {
      final success = await NativeBridge.toggleFlashlight(true);
      return NodeFrame.response('', payload: {
        'success': success,
        'on': true,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'FLASHLIGHT_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _turnOff() async {
    try {
      final success = await NativeBridge.toggleFlashlight(false);
      return NodeFrame.response('', payload: {
        'success': success,
        'on': false,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'FLASHLIGHT_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _status() async {
    try {
      final available = await NativeBridge.isFlashlightAvailable();
      return NodeFrame.response('', payload: {
        'available': available,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'FLASHLIGHT_ERROR',
        'message': '$e',
      });
    }
  }
}
