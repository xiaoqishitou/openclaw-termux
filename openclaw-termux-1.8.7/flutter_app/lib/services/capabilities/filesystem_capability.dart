import 'dart:convert';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

class FilesystemCapability extends CapabilityHandler {
  @override
  String get name => 'filesystem';

  @override
  List<String> get commands => [
    'list',
    'read',
    'write',
    'delete',
    'mkdir',
    'info',
    'readRootfs',
    'writeRootfs',
  ];

  @override
  List<Permission> get requiredPermissions => [
    Permission.storage,
    Permission.manageExternalStorage,
  ];

  @override
  Future<bool> checkPermission() async {
    return await NativeBridge.hasStoragePermission();
  }

  @override
  Future<bool> requestPermission() async {
    return await NativeBridge.requestStoragePermission();
  }

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'filesystem.list':
        return _list(params);
      case 'filesystem.read':
        return _read(params);
      case 'filesystem.write':
        return _write(params);
      case 'filesystem.delete':
        return _delete(params);
      case 'filesystem.mkdir':
        return _mkdir(params);
      case 'filesystem.info':
        return _info(params);
      case 'filesystem.readRootfs':
        return _readRootfs(params);
      case 'filesystem.writeRootfs':
        return _writeRootfs(params);
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown filesystem command: $command',
        });
    }
  }

  Future<NodeFrame> _list(Map<String, dynamic> params) async {
    try {
      final path = params['path'] as String? ?? '/';
      final result = await NativeBridge.listDirectory(path);
      return NodeFrame.response('', payload: result);
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'FS_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _read(Map<String, dynamic> params) async {
    try {
      final path = params['path'] as String?;
      if (path == null) {
        return NodeFrame.response('', error: {
          'code': 'INVALID_ARGS',
          'message': 'path is required',
        });
      }
      final limit = params['limit'] as int?;
      final content = await NativeBridge.readFile(path, limit: limit);

      if (content == null) {
        return NodeFrame.response('', error: {
          'code': 'NOT_FOUND',
          'message': 'File not found or cannot be read',
        });
      }

      final file = File(path);
      final isBinary = await _isBinaryFile(file);

      if (isBinary) {
        final bytes = await file.readAsBytes();
        return NodeFrame.response('', payload: {
          'base64': base64Encode(bytes),
          'size': bytes.length,
          'binary': true,
        });
      }

      return NodeFrame.response('', payload: {
        'content': content,
        'size': content.length,
        'binary': false,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'FS_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _write(Map<String, dynamic> params) async {
    try {
      final path = params['path'] as String?;
      final content = params['content'] as String?;
      if (path == null || content == null) {
        return NodeFrame.response('', error: {
          'code': 'INVALID_ARGS',
          'message': 'path and content are required',
        });
      }
      final success = await NativeBridge.writeFile(path, content);
      return NodeFrame.response('', payload: {'success': success});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'FS_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _delete(Map<String, dynamic> params) async {
    try {
      final path = params['path'] as String?;
      if (path == null) {
        return NodeFrame.response('', error: {
          'code': 'INVALID_ARGS',
          'message': 'path is required',
        });
      }
      final success = await NativeBridge.deleteFile(path);
      return NodeFrame.response('', payload: {'success': success});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'FS_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _mkdir(Map<String, dynamic> params) async {
    try {
      final path = params['path'] as String?;
      if (path == null) {
        return NodeFrame.response('', error: {
          'code': 'INVALID_ARGS',
          'message': 'path is required',
        });
      }
      final success = await NativeBridge.createDirectory(path);
      return NodeFrame.response('', payload: {'success': success});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'FS_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _info(Map<String, dynamic> params) async {
    try {
      final path = params['path'] as String?;
      if (path == null) {
        return NodeFrame.response('', error: {
          'code': 'INVALID_ARGS',
          'message': 'path is required',
        });
      }
      final result = await NativeBridge.getFileInfo(path);
      return NodeFrame.response('', payload: result);
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'FS_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _readRootfs(Map<String, dynamic> params) async {
    try {
      final path = params['path'] as String?;
      if (path == null) {
        return NodeFrame.response('', error: {
          'code': 'INVALID_ARGS',
          'message': 'path is required',
        });
      }
      final content = await NativeBridge.readRootfsFile(path);
      return NodeFrame.response('', payload: {
        'content': content,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'FS_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _writeRootfs(Map<String, dynamic> params) async {
    try {
      final path = params['path'] as String?;
      final content = params['content'] as String?;
      if (path == null || content == null) {
        return NodeFrame.response('', error: {
          'code': 'INVALID_ARGS',
          'message': 'path and content are required',
        });
      }
      final success = await NativeBridge.writeRootfsFile(path, content);
      return NodeFrame.response('', payload: {'success': success});
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'FS_ERROR',
        'message': '$e',
      });
    }
  }

  Future<bool> _isBinaryFile(File file) async {
    try {
      final bytes = await file.openRead(0, 1024).expand((e) => e).toList();
      for (final byte in bytes) {
        if (byte == 0) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
