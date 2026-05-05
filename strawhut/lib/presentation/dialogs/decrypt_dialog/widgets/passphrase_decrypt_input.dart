import 'package:flutter/material.dart';
import 'package:strawhut/l10n/l10n.dart';

/// 解密对话框 - 暗号输入组件
///
/// 提供暗号（passphrase）输入功能，用于协商密钥加密模式的解密流程。
///
/// 架构位置：应用层（Presentation Layer）→ 解密对话框子组件
/// 使用场景：DecryptDialog 中检测到协商密钥模式时显示
///
/// 功能：
/// - 暗号输入框（带密码可见性切换）
/// - 提示信息：此卡片通过暗号加密
/// - 提示文本：请与创作者确认暗号内容
///
/// 外部通过 GlobalKey<PassphraseDecryptInputState> 访问：
/// - passphrase: 获取当前暗号值（String?）
/// - clear(): 清空输入
class PassphraseDecryptInput extends StatefulWidget {
  /// 创建解密暗号输入组件实例
  const PassphraseDecryptInput({super.key});

  @override
  State<PassphraseDecryptInput> createState() => PassphraseDecryptInputState();
}

/// PassphraseDecryptInput 的公开状态类
///
/// 通过 GlobalKey 暴露给父组件，提供取值和清空功能。
class PassphraseDecryptInputState extends State<PassphraseDecryptInput> {
  /// 暗号输入控制器
  final _controller = TextEditingController();

  /// 暗号是否可见
  bool _obscurePassphrase = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 获取当前暗号值
  ///
  /// 返回：当前文本框中的暗号字符串（已 trim），如果为空则返回 null
  String? get passphrase {
    final text = _controller.text.trim();
    return text.isEmpty ? null : text;
  }

  /// 清空输入
  void clear() {
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 提示信息：此卡片通过暗号加密
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, color: Colors.blue[700], size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.decryptPassphraseInfo,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 暗号输入框
        TextField(
          controller: _controller,
          obscureText: _obscurePassphrase,
          decoration: InputDecoration(
            labelText: l10n.decryptPassphraseLabel,
            hintText: l10n.decryptPassphraseHint,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassphrase ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassphrase = !_obscurePassphrase;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}
