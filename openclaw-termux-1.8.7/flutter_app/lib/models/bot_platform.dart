import 'package:flutter/material.dart';

/// 机器人平台配置元数据
class BotPlatform {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final List<BotConfigField> configFields;

  const BotPlatform({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.configFields,
  });

  static const feishu = BotPlatform(
    id: 'feishu',
    name: '飞书',
    description: '飞书企业协作平台机器人',
    icon: Icons.chat,
    color: Color(0xFF3370FF),
    configFields: [
      BotConfigField(key: 'appId', label: 'App ID', hint: 'cli_xxxxxxxxxxxx'),
      BotConfigField(key: 'appSecret', label: 'App Secret', hint: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', isSecret: true),
      BotConfigField(key: 'encryptKey', label: 'Encrypt Key', hint: '可选，用于事件加密', isSecret: true),
      BotConfigField(key: 'verificationToken', label: 'Verification Token', hint: '可选', isSecret: true),
    ],
  );

  static const wechat = BotPlatform(
    id: 'wechat',
    name: '微信',
    description: '微信公众号/企业微信机器人',
    icon: Icons.wechat,
    color: Color(0xFF07C160),
    configFields: [
      BotConfigField(key: 'appId', label: 'App ID', hint: 'wx_xxxxxxxxxxxxxxxx'),
      BotConfigField(key: 'appSecret', label: 'App Secret', hint: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', isSecret: true),
      BotConfigField(key: 'token', label: 'Token', hint: '用于消息验证'),
      BotConfigField(key: 'encodingAesKey', label: 'Encoding AES Key', hint: '可选，用于消息加密', isSecret: true),
    ],
  );

  static const qq = BotPlatform(
    id: 'qq',
    name: 'QQ',
    description: 'QQ Bot 机器人（OneBot 协议）',
    icon: Icons.smart_toy,
    color: Color(0xFF12B7F5),
    configFields: [
      BotConfigField(key: 'wsUrl', label: 'WebSocket URL', hint: 'ws://127.0.0.1:3001'),
      BotConfigField(key: 'accessToken', label: 'Access Token', hint: '可选', isSecret: true),
      BotConfigField(key: 'qqNumber', label: 'QQ 号', hint: '机器人 QQ 号码'),
    ],
  );

  static const discord = BotPlatform(
    id: 'discord',
    name: 'Discord',
    description: 'Discord Bot 机器人',
    icon: Icons.videogame_asset,
    color: Color(0xFF5865F2),
    configFields: [
      BotConfigField(key: 'botToken', label: 'Bot Token', hint: 'xxxxxxxxxxxxxxxxxxxxxxxx.xxxxxx.xxxxxxxxxxxxxxxxxxxxxxxxxxx', isSecret: true),
      BotConfigField(key: 'clientId', label: 'Client ID', hint: 'xxxxxxxxxxxxxxxxxx'),
      BotConfigField(key: 'clientSecret', label: 'Client Secret', hint: '可选', isSecret: true),
    ],
  );

  static const telegram = BotPlatform(
    id: 'telegram',
    name: 'Telegram',
    description: 'Telegram Bot 机器人',
    icon: Icons.send,
    color: Color(0xFF26A5E4),
    configFields: [
      BotConfigField(key: 'botToken', label: 'Bot Token', hint: 'xxxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', isSecret: true),
      BotConfigField(key: 'webhookUrl', label: 'Webhook URL', hint: '可选，用于接收消息'),
      BotConfigField(key: 'allowedUsers', label: '允许的用户 ID', hint: '可选，逗号分隔'),
    ],
  );

  static const slack = BotPlatform(
    id: 'slack',
    name: 'Slack',
    description: 'Slack Bot 机器人',
    icon: Icons.workspaces,
    color: Color(0xFF4A154B),
    configFields: [
      BotConfigField(key: 'botToken', label: 'Bot Token', hint: 'xoxb-xxxxxxxxxxxx-xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxx', isSecret: true),
      BotConfigField(key: 'signingSecret', label: 'Signing Secret', hint: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', isSecret: true),
      BotConfigField(key: 'appToken', label: 'App Token', hint: '可选，用于 Socket Mode', isSecret: true),
    ],
  );

  static const all = [feishu, wechat, qq, discord, telegram, slack];
}

class BotConfigField {
  final String key;
  final String label;
  final String hint;
  final bool isSecret;

  const BotConfigField({
    required this.key,
    required this.label,
    required this.hint,
    this.isSecret = false,
  });
}
