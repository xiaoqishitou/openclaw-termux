import 'package:flutter/material.dart';

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

  static const sshPackage = OptionalPackage(
    id: 'ssh', name: 'OpenSSH',
    description: 'SSH 客户端与服务端，用于安全远程访问',
    icon: Icons.vpn_key, color: Colors.teal,
    installCommand: "set -e; echo '>>> 正在安装 OpenSSH...'; apt-get update -qq && apt-get install -y openssh-client openssh-server; ssh -V; echo '>>> SSH_INSTALL_COMPLETE'",
    uninstallCommand: "set -e; echo '>>> 正在移除 OpenSSH...'; apt-get remove -y openssh-client openssh-server && apt-get autoremove -y; echo '>>> SSH_UNINSTALL_COMPLETE'",
    checkPath: 'usr/bin/ssh', estimatedSize: '~10 MB', completionSentinel: 'SSH_INSTALL_COMPLETE',
  );

  static const adbPackage = OptionalPackage(
    id: 'adb', name: 'ADB',
    description: 'Android 调试桥，连接管理设备',
    icon: Icons.phone_android, color: Colors.green,
    installCommand: "set -e; echo '>>> 正在安装 ADB...'; apt-get update -qq && apt-get install -y android-tools-adb; adb version; echo '>>> ADB_INSTALL_COMPLETE'",
    uninstallCommand: "set -e; echo '>>> 正在移除 ADB...'; apt-get remove -y android-tools-adb && apt-get autoremove -y; echo '>>> ADB_UNINSTALL_COMPLETE'",
    checkPath: 'usr/bin/adb', estimatedSize: '~30 MB', completionSentinel: 'ADB_INSTALL_COMPLETE',
  );

  static const cpolarPackage = OptionalPackage(
    id: 'cpolar', name: 'Cpolar',
    description: '内网穿透，将本地服务暴露到公网',
    icon: Icons.cloud, color: Colors.blue,
    installCommand: "set -e; echo '>>> 正在安装 Cpolar...'; apt-get update -qq && apt-get install -y curl; curl -L -o /tmp/cpolar.tar.gz https://static.cpolar.com/downloads/releases/3.3.12/cpolar-stable-linux-arm.tar.gz || curl -L -o /tmp/cpolar.tar.gz https://static.cpolar.com/downloads/releases/3.3.12/cpolar-stable-linux-amd64.tar.gz; tar -xzf /tmp/cpolar.tar.gz -C /usr/local/bin/ 2>/dev/null || tar -xzf /tmp/cpolar.tar.gz -C /tmp/ && mv /tmp/cpolar /usr/local/bin/; chmod +x /usr/local/bin/cpolar; cpolar version; echo '>>> CPOLAR_INSTALL_COMPLETE'",
    uninstallCommand: "set -e; echo '>>> 正在移除 Cpolar...'; rm -f /usr/local/bin/cpolar; rm -f /tmp/cpolar.tar.gz; echo '>>> CPOLAR_UNINSTALL_COMPLETE'",
    checkPath: 'usr/local/bin/cpolar', estimatedSize: '~15 MB', completionSentinel: 'CPOLAR_INSTALL_COMPLETE',
  );

  static const buildEssentialPackage = OptionalPackage(
    id: 'build-essential', name: 'Build Essential',
    description: 'C/C++ 编译工具链（gcc, g++, make）',
    icon: Icons.build, color: Colors.orange,
    installCommand: "set -e; echo '>>> 正在安装 build-essential...'; apt-get update -qq && apt-get install -y build-essential; gcc --version | head -1; echo '>>> BUILDESSENTIAL_INSTALL_COMPLETE'",
    uninstallCommand: "set -e; echo '>>> 正在移除 build-essential...'; apt-get remove -y build-essential gcc g++ make && apt-get autoremove -y; echo '>>> BUILDESSENTIAL_UNINSTALL_COMPLETE'",
    checkPath: 'usr/bin/gcc', estimatedSize: '~80 MB', completionSentinel: 'BUILDESSENTIAL_INSTALL_COMPLETE',
  );

  static const gitPackage = OptionalPackage(
    id: 'git', name: 'Git',
    description: '分布式版本控制系统',
    icon: Icons.source, color: Color(0xFFF05032),
    installCommand: "set -e; echo '>>> 正在安装 Git...'; apt-get update -qq && apt-get install -y git; git --version; echo '>>> GIT_INSTALL_COMPLETE'",
    uninstallCommand: "set -e; echo '>>> 正在移除 Git...'; apt-get remove -y git && apt-get autoremove -y; echo '>>> GIT_UNINSTALL_COMPLETE'",
    checkPath: 'usr/bin/git', estimatedSize: '~40 MB', completionSentinel: 'GIT_INSTALL_COMPLETE',
  );

  static const zshPackage = OptionalPackage(
    id: 'zsh', name: 'Zsh + Oh My Zsh',
    description: '强大的 Shell 及其配置框架',
    icon: Icons.terminal, color: Color(0xFF5A7E9E),
    installCommand: "set -e; echo '>>> 正在安装 Zsh...'; apt-get update -qq && apt-get install -y zsh curl git; sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" --unattended; chsh -s /bin/zsh 2>/dev/null || true; zsh --version; echo '>>> ZSH_INSTALL_COMPLETE'",
    uninstallCommand: "set -e; echo '>>> 正在移除 Zsh...'; rm -rf /root/.oh-my-zsh; apt-get remove -y zsh && apt-get autoremove -y; echo '>>> ZSH_UNINSTALL_COMPLETE'",
    checkPath: 'usr/bin/zsh', estimatedSize: '~50 MB', completionSentinel: 'ZSH_INSTALL_COMPLETE',
  );

  static const tmuxPackage = OptionalPackage(
    id: 'tmux', name: 'Tmux',
    description: '终端复用器，支持多窗口和会话管理',
    icon: Icons.view_agenda, color: Color(0xFF66BB6A),
    installCommand: "set -e; echo '>>> 正在安装 Tmux...'; apt-get update -qq && apt-get install -y tmux; tmux -V; echo '>>> TMUX_INSTALL_COMPLETE'",
    uninstallCommand: "set -e; echo '>>> 正在移除 Tmux...'; apt-get remove -y tmux && apt-get autoremove -y; echo '>>> TMUX_UNINSTALL_COMPLETE'",
    checkPath: 'usr/bin/tmux', estimatedSize: '~5 MB', completionSentinel: 'TMUX_INSTALL_COMPLETE',
  );

  static const all = [
    goPackage, sshPackage, adbPackage, cpolarPackage,
    buildEssentialPackage, gitPackage, zshPackage, tmuxPackage,
  ];

  String get uninstallSentinel => completionSentinel.replaceFirst('INSTALL', 'UNINSTALL');
}
