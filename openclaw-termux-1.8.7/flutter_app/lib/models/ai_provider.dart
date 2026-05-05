import 'package:flutter/material.dart';

class AiProvider {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String baseUrl;
  final List<String> defaultModels;
  final String apiKeyHint;

  const AiProvider({required this.id, required this.name, required this.description, required this.icon, required this.color, required this.baseUrl, required this.defaultModels, required this.apiKeyHint});

  // ========== 国际主流 ==========

  static const anthropic = AiProvider(
    id: 'anthropic', name: 'Anthropic',
    description: 'Claude 模型 — 强大的推理与编程能力',
    icon: Icons.psychology, color: Color(0xFFD97706),
    baseUrl: 'https://api.anthropic.com/v1',
    defaultModels: ['claude-sonnet-4-20250514','claude-opus-4-20250514','claude-haiku-4-20250506','claude-3.5-sonnet-20241022'],
    apiKeyHint: 'sk-ant-...',
  );

  static const openai = AiProvider(
    id: 'openai', name: 'OpenAI',
    description: 'GPT 和 o 系列模型',
    icon: Icons.auto_awesome, color: Color(0xFF10A37F),
    baseUrl: 'https://api.openai.com/v1',
    defaultModels: ['gpt-4o','gpt-4o-mini','o1','o1-mini','o3-mini','gpt-4-turbo','gpt-3.5-turbo'],
    apiKeyHint: 'sk-...',
  );

  static const google = AiProvider(
    id: 'google', name: 'Google Gemini',
    description: 'Gemini 多模态模型家族',
    icon: Icons.diamond, color: Color(0xFF4285F4),
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    defaultModels: ['gemini-2.5-pro','gemini-2.5-flash','gemini-2.0-flash','gemini-1.5-pro','gemini-1.5-flash'],
    apiKeyHint: 'AIza...',
  );

  static const openrouter = AiProvider(
    id: 'openrouter', name: 'OpenRouter',
    description: '统一 API 接入数百种模型',
    icon: Icons.route, color: Color(0xFF6366F1),
    baseUrl: 'https://openrouter.ai/api/v1',
    defaultModels: ['anthropic/claude-sonnet-4','openai/gpt-4o','google/gemini-2.5-pro','meta-llama/llama-3.1-405b-instruct','deepseek/deepseek-r1'],
    apiKeyHint: 'sk-or-...',
  );

  static const nvidia = AiProvider(
    id: 'nvidia', name: 'NVIDIA NIM',
    description: 'GPU 加速推理端点',
    icon: Icons.memory, color: Color(0xFF76B900),
    baseUrl: 'https://integrate.api.nvidia.com/v1',
    defaultModels: ['meta/llama-3.1-405b-instruct','meta/llama-3.3-70b-instruct','deepseek-ai/deepseek-r1','nvidia/nemotron-4-340b-instruct'],
    apiKeyHint: 'nvapi-...',
  );

  static const deepseek = AiProvider(
    id: 'deepseek', name: 'DeepSeek',
    description: '高性能开源大模型',
    icon: Icons.explore, color: Color(0xFF0EA5E9),
    baseUrl: 'https://api.deepseek.com/v1',
    defaultModels: ['deepseek-chat','deepseek-reasoner','deepseek-coder'],
    apiKeyHint: 'sk-...',
  );

  static const xai = AiProvider(
    id: 'xai', name: 'xAI',
    description: 'xAI 的 Grok 模型系列',
    icon: Icons.bolt, color: Color(0xFFEF4444),
    baseUrl: 'https://api.x.ai/v1',
    defaultModels: ['grok-3','grok-3-mini','grok-2','grok-2-mini'],
    apiKeyHint: 'xai-...',
  );

  // ========== 国内供应商 ==========

  static const qwen = AiProvider(
    id: 'qwen', name: '通义千问',
    description: 'Qwen 系列，中文优化好，国内访问快',
    icon: Icons.translate, color: Color(0xFF6236FF),
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    defaultModels: ['qwen-max','qwen-plus','qwen-turbo','qwen-long','qwen-vl-max','qwq-32b'],
    apiKeyHint: 'sk-...',
  );

  static const doubao = AiProvider(
    id: 'doubao', name: '豆包',
    description: '中文理解顶尖，API 兼容 OpenAI',
    icon: Icons.chat, color: Color(0xFF325EFF),
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    defaultModels: ['doubao-pro-32k','doubao-pro-128k','doubao-lite-32k','doubao-lite-128k','doubao-1.5-pro-256k'],
    apiKeyHint: 'ep-...',
  );

  static const zhipu = AiProvider(
    id: 'zhipu', name: '智谱清言',
    description: '逻辑推理/代码能力强，国内服务器稳定',
    icon: Icons.school, color: Color(0xFF1A73E8),
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    defaultModels: ['glm-4-plus','glm-4-0520','glm-4-air','glm-4-airx','glm-4-long','glm-4v'],
    apiKeyHint: 'xxx.yyy...',
  );

  static const moonshot = AiProvider(
    id: 'moonshot', name: 'Moonshot AI',
    description: '超长上下文，百万 token 支持，国内节点快',
    icon: Icons.nightlight, color: Color(0xFF1E1E1E),
    baseUrl: 'https://api.moonshot.cn/v1',
    defaultModels: ['moonshot-v1-8k','moonshot-v1-32k','moonshot-v1-128k'],
    apiKeyHint: 'sk-...',
  );

  static const siliconflow = AiProvider(
    id: 'siliconflow', name: '硅基流动',
    description: '聚合开源模型，国内低延迟，按 token 计费',
    icon: Icons.bolt, color: Color(0xFF7C3AED),
    baseUrl: 'https://api.siliconflow.cn/v1',
    defaultModels: ['deepseek-ai/DeepSeek-R1','deepseek-ai/DeepSeek-V3','Qwen/Qwen2.5-72B-Instruct','meta-llama/Meta-Llama-3.1-405B-Instruct'],
    apiKeyHint: 'sk-...',
  );

  static const mimo = AiProvider(
    id: 'mimo', name: 'Mimo',
    description: 'Mimo AI 模型平台，兼容 OpenAI 和 Anthropic 接口',
    icon: Icons.chat_bubble, color: Color(0xFF8B5CF6),
    baseUrl: 'https://token-plan-cn.xiaomimo.com/v1',
    defaultModels: ['mimo-pro','mimo-standard','mimo-lite','gpt-4o','claude-sonnet-4'],
    apiKeyHint: 'mimo-...',
  );

  // ========== 海外推理平台 ==========

  static const groq = AiProvider(
    id: 'groq', name: 'Groq',
    description: 'LPU 架构，推理速度极快，延迟极低',
    icon: Icons.speed, color: Color(0xFFF55036),
    baseUrl: 'https://api.groq.com/openai/v1',
    defaultModels: ['llama-3.3-70b-versatile','llama-3.1-8b-instant','mixtral-8x7b-32768','gemma2-9b-it'],
    apiKeyHint: 'gsk_...',
  );

  static const together = AiProvider(
    id: 'together', name: 'Together AI',
    description: '开源模型低成本推理，API 兼容 OpenAI',
    icon: Icons.group_work, color: Color(0xFF00D4AA),
    baseUrl: 'https://api.together.xyz/v1',
    defaultModels: ['meta-llama/Llama-3.3-70B-Instruct-Turbo','deepseek-ai/DeepSeek-R1','Qwen/Qwen2.5-72B-Instruct-Turbo'],
    apiKeyHint: 'together_...',
  );

  static const fireworks = AiProvider(
    id: 'fireworks', name: 'Fireworks AI',
    description: '多模态/长上下文支持，推理稳定',
    icon: Icons.local_fire_department, color: Color(0xFFFF6B35),
    baseUrl: 'https://api.fireworks.ai/inference/v1',
    defaultModels: ['accounts/fireworks/models/llama-v3p3-70b-instruct','accounts/fireworks/models/qwen2p5-72b-instruct','accounts/fireworks/models/deepseek-r1'],
    apiKeyHint: 'fw_...',
  );

  // ========== 本地模型 ==========

  static const ollama = AiProvider(
    id: 'ollama', name: 'Ollama',
    description: '一键部署开源模型，操作简单，兼容 OpenAI 接口',
    icon: Icons.computer, color: Color(0xFF059669),
    baseUrl: 'http://localhost:11434/v1',
    defaultModels: ['llama3.2','qwen2.5','phi4','deepseek-r1:8b','gemma2','mistral','codellama'],
    apiKeyHint: '无需密钥（留空）',
  );

  static const mnn = AiProvider(
    id: 'mnn', name: 'MNN',
    description: '阿里开源轻量推理引擎，性能强、体积小',
    icon: Icons.memory, color: Color(0xFF00BFA5),
    baseUrl: 'http://localhost:8080/v1',
    defaultModels: ['Qwen-1.5-4B-Chat','Qwen-1.5-1.8B-Chat','Llama-3-8B-Instruct'],
    apiKeyHint: '无需密钥（留空）',
  );

  static const localai = AiProvider(
    id: 'localai', name: 'LocalAI',
    description: '开源 AI 网关，伪装 OpenAI 接口，支持多模型',
    icon: Icons.hub, color: Color(0xFF5C6BC0),
    baseUrl: 'http://localhost:8080/v1',
    defaultModels: ['gpt-4','gpt-3.5-turbo','llama3','qwen2.5'],
    apiKeyHint: '无需密钥（留空）',
  );

  static const all = [
    // 国际主流
    anthropic, openai, google, openrouter, nvidia, deepseek, xai,
    // 国内供应商
    qwen, doubao, zhipu, moonshot, siliconflow, mimo,
    // 海外推理平台
    groq, together, fireworks,
    // 本地模型
    ollama, mnn, localai,
  ];
}
