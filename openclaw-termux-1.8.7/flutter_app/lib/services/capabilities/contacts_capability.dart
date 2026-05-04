import 'package:permission_handler/permission_handler.dart';
import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

class ContactsCapability extends CapabilityHandler {
  @override
  String get name => 'contacts';

  @override
  List<String> get commands => ['list', 'callLogs', 'sms', 'sendSms'];

  @override
  List<Permission> get requiredPermissions => [
    Permission.contacts,
    Permission.phone,
    Permission.sms,
  ];

  @override
  Future<bool> checkPermission() async {
    return await Permission.contacts.isGranted;
  }

  @override
  Future<bool> requestPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'contacts.list':
        return _list();
      case 'contacts.callLogs':
        return _callLogs(params);
      case 'contacts.sms':
        return _sms(params);
      case 'contacts.sendSms':
        return _sendSms(params);
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown contacts command: $command',
        });
    }
  }

  Future<NodeFrame> _list() async {
    try {
      final contacts = await NativeBridge.getContacts();
      return NodeFrame.response('', payload: {'contacts': contacts});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CONTACTS_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _callLogs(Map<String, dynamic> params) async {
    try {
      final limit = params['limit'] as int? ?? 100;
      final logs = await NativeBridge.getCallLogs(limit: limit);
      return NodeFrame.response('', payload: {'callLogs': logs});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CONTACTS_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _sms(Map<String, dynamic> params) async {
    try {
      final limit = params['limit'] as int? ?? 100;
      final messages = await NativeBridge.getSmsMessages(limit: limit);
      return NodeFrame.response('', payload: {'messages': messages});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CONTACTS_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _sendSms(Map<String, dynamic> params) async {
    try {
      final phoneNumber = params['phoneNumber'] as String?;
      final message = params['message'] as String?;
      if (phoneNumber == null || message == null) {
        return NodeFrame.response('', error: {
          'code': 'INVALID_ARGS',
          'message': 'phoneNumber and message are required',
        });
      }
      final success = await NativeBridge.sendSms(phoneNumber, message);
      return NodeFrame.response('', payload: {'success': success});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'CONTACTS_ERROR',
        'message': '$e',
      });
    }
  }
}
