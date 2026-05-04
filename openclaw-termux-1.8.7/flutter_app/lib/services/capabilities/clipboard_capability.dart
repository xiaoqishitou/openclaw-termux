import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

class ClipboardCapability extends CapabilityHandler {
  @override
  String get name => 'clipboard';

  @override
  List<String> get commands => ['read', 'write'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'clipboard.read':
        return _read();
      case 'clipboard.write':
        return _write(params);
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown clipboard command: $command',
        });
    }
  }

  Future<NodeFrame> _read() async {
    try {
      final text = await NativeBridge.getClipboardText();
      return NodeFrame.response('', payload: {
        'text': text,
        'hasContent': text != null && text.isNotEmpty,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CLIPBOARD_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _write(Map<String, dynamic> params) async {
    try {
      final text = params['text'] as String?;
      if (text == null) {
        return NodeFrame.response('', error: {
          'code': 'INVALID_ARGS',
          'message': 'text is required',
        });
      }
      final success = await NativeBridge.setClipboardText(text);
      return NodeFrame.response('', payload: {'success': success});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CLIPBOARD_ERROR',
        'message': '$e',
      });
    }
  }
}
