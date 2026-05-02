import 'package:flutter/material.dart';

/// 可选开发工具元数据 — 安装在 proot Ubuntu 环境中
class OptionalPackage {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String installCommand;
  final String uninstallCommand;
  final String checkPath;
  final String estimatedSize;
  final String completionSentinel;

  const OptionalPackage({required this.id, required this.name, required this.description, required this.icon, required this.color, required this.installCommand, required this.uninstallCommand, required this.checkPath, required this.estimatedSize, required this.completionSentinel});

  static const goPackage = OptionalPackage(
    id: 'go', name: 'Go (Golang)',
    description: 'Go 语言编译器与开发工具链',
    icon: Icons.integration_instructions, color: Colors.cyan,
    installCommand: "set -e; echo '>>> 正在通过 apt 安装 Go...'; apt-get update -qq && apt-get install -y golang; go version; echo '>>> GO_INSTALL_COMPLETE'",
    uninstallCommand: "set -e; echo '>>> 正在移除 Go...'; apt-get remove -y golang golang-go && apt-get autoremove -y; echo '>>> GO_UNINSTALL_COMPLETE'",
    checkPath: 'usr/bin/go', estimatedSize: '~150 MB', completionSentinel: 'GO_INSTALL_COMPLETE',
  );

  static const brewPackage = OptionalPackage(
    id: 'brew', name: 'Homebrew',
    description: 'Linux 上强大的包管理器',
    icon: Icons.science, color: Colors.amber,
    installCommand: "set -e; echo '>>> 正在安装 Homebrew（可能需要一些时间）...'; touch /.dockerenv; apt-get update -qq && apt-get install -y -qq build-essential procps curl file git; NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"; grep -q 'linuxbrew' /root/.bashrc 2>/dev/null || { echo 'eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"' >> /root/.bashrc; }; eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"; brew --version; echo '>>> BREW_INSTALL_COMPLETE'",
    uninstallCommand: "set -e; echo '>>> 正在移除 Homebrew...'; touch /.dockerenv; NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)\" || true; rm -rf /home/linuxbrew/.linuxbrew; sed -i '/linuxbrew/d' /root/.bashrc; echo '>>> BREW_UNINSTALL_COMPLETE'",
    checkPath: 'home/linuxbrew/.linuxbrew/bin/brew', estimatedSize: '~500 MB', completionSentinel: 'BREW_INSTALL_COMPLETE',
  );

  static const sshPackage = OptionalPackage(
    id: 'ssh', name: 'OpenSSH',
    description: 'SSH 客户端与服务端，用于安全远程访问',
    icon: Icons.vpn_key, color: Colors.teal,
    installCommand: "set -e; echo '>>> 正在安装 OpenSSH...'; apt-get update -qq && apt-get install -y openssh-client openssh-server; ssh -V; echo '>>> SSH_INSTALL_COMPLETE'",
    uninstallCommand: "set -e; echo '>>> 正在移除 OpenSSH...'; apt-get remove -y openssh-client openssh-server && apt-get autoremove -y; echo '>>> SSH_UNINSTALL_COMPLETE'",
    checkPath: 'usr/bin/ssh', estimatedSize: '~10 MB', completionSentinel: 'SSH_INSTALL_COMPLETE',
  );

  /// 所有可选软件包
  static const all = [goPackage, brewPackage, sshPackage];

  /// 卸载完成标识（从安装标识派生）
  String get uninstallSentinel => completionSentinel.replaceFirst('INSTALL', 'UNINSTALL');
}
