import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';

/// 口令强度评估服务
///
/// 提供口令（passphrase）安全强度评估功能。
/// 根据口令的长度、字符组成和常见弱模式，
/// 将口令分为四个强度等级：[PassphraseStrength.veryWeak]、
/// [PassphraseStrength.weak]、[PassphraseStrength.medium]、
/// [PassphraseStrength.strong]。
///
/// 评估规则（按优先级从高到低）：
/// 1. **veryWeak**：长度 < 8，或为空/仅空白字符，
///    或包含 6+ 连续相同字符，或包含连续数字序列（如 "123456"、"654321"）
/// 2. **strong**：长度 >= 16 且满足 3 个以上字符类别
///    （大写字母、小写字母、数字、特殊字符）
/// 3. **medium**：长度 >= 12 且同时包含字母和数字
/// 4. **weak**：长度 >= 8 但不满足上述条件
///
/// 使用示例：
/// ```dart
/// final strength = PassphraseStrengthService.evaluate('MyP@ssw0rd2024!');
/// // strength == PassphraseStrength.strong
/// ```
class PassphraseStrengthService {
  /// 评估口令强度
  ///
  /// 参数：
  /// - [passphrase]: 待评估的口令字符串
  ///
  /// 返回：
  /// - [PassphraseStrength] 枚举值，表示口令的安全强度等级
  static PassphraseStrength evaluate(String passphrase) {
    // 检查空或仅空白字符
    if (passphrase.trim().isEmpty) {
      return PassphraseStrength.veryWeak;
    }

    // 检查长度不足
    if (passphrase.length < PASSPHRASE_MIN_LENGTH) {
      return PassphraseStrength.veryWeak;
    }

    // 检查连续相同字符（6+ 个）
    if (_hasConsecutiveSameChars(passphrase, MAX_CONSECUTIVE_SAME_CHAR)) {
      return PassphraseStrength.veryWeak;
    }

    // 检查连续数字序列（如 "123456" 或 "654321"）
    if (_hasConsecutiveDigitSequence(passphrase)) {
      return PassphraseStrength.veryWeak;
    }

    // 计算字符类别数量
    final categoryCount = _countCharacterCategories(passphrase);

    // 检查强口令：长度 >= 16 且满足 3+ 字符类别
    if (passphrase.length >= 16 && categoryCount >= 3) {
      return PassphraseStrength.strong;
    }

    // 检查中等口令：长度 >= 12 且同时包含字母和数字
    final hasLetter = _hasLetter(passphrase);
    final hasDigit = _hasDigit(passphrase);
    if (passphrase.length >= 12 && hasLetter && hasDigit) {
      return PassphraseStrength.medium;
    }

    // 其余情况为弱口令
    return PassphraseStrength.weak;
  }

  /// 检查是否包含连续相同字符
  ///
  /// 当口令中出现 [minCount] 个及以上连续相同字符时返回 true。
  /// 例如："aaaaaa" 或 "111111"。
  static bool _hasConsecutiveSameChars(String passphrase, int minCount) {
    if (passphrase.length < minCount) return false;

    int consecutiveCount = 1;
    for (int i = 1; i < passphrase.length; i++) {
      if (passphrase[i] == passphrase[i - 1]) {
        consecutiveCount++;
        if (consecutiveCount >= minCount) {
          return true;
        }
      } else {
        consecutiveCount = 1;
      }
    }
    return false;
  }

  /// 检查是否包含连续数字序列
  ///
  /// 检测口令中是否包含 6 位及以上的连续递增或递减数字序列。
  /// 例如："123456"、"654321"、"012345"。
  static bool _hasConsecutiveDigitSequence(String passphrase) {
    // 提取所有数字子串
    final digitRuns = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < passphrase.length; i++) {
      if (passphrase[i].contains(RegExp(r'\d'))) {
        buffer.write(passphrase[i]);
      } else {
        if (buffer.isNotEmpty) {
          digitRuns.add(buffer.toString());
          buffer.clear();
        }
      }
    }
    if (buffer.isNotEmpty) {
      digitRuns.add(buffer.toString());
    }

    // 检查每个数字子串是否包含 6+ 位连续序列
    const int sequenceLength = 6;
    for (final run in digitRuns) {
      if (run.length < sequenceLength) continue;

      for (int start = 0; start <= run.length - sequenceLength; start++) {
        bool ascending = true;
        bool descending = true;

        for (int i = start + 1; i < start + sequenceLength; i++) {
          final prev = run.codeUnitAt(i - 1);
          final curr = run.codeUnitAt(i);

          if (curr != prev + 1) ascending = false;
          if (curr != prev - 1) descending = false;

          if (!ascending && !descending) break;
        }

        if (ascending || descending) return true;
      }
    }

    return false;
  }

  /// 计算口令中包含的字符类别数量
  ///
  /// 字符类别包括：
  /// - 大写字母 (A-Z)
  /// - 小写字母 (a-z)
  /// - 数字 (0-9)
  /// - 特殊字符（非字母数字）
  static int _countCharacterCategories(String passphrase) {
    int count = 0;
    if (_hasUppercase(passphrase)) count++;
    if (_hasLowercase(passphrase)) count++;
    if (_hasDigit(passphrase)) count++;
    if (_hasSpecialChar(passphrase)) count++;
    return count;
  }

  /// 检查是否包含大写字母
  static bool _hasUppercase(String passphrase) {
    return passphrase.contains(RegExp(r'[A-Z]'));
  }

  /// 检查是否包含小写字母
  static bool _hasLowercase(String passphrase) {
    return passphrase.contains(RegExp(r'[a-z]'));
  }

  /// 检查是否包含数字
  static bool _hasDigit(String passphrase) {
    return passphrase.contains(RegExp(r'\d'));
  }

  /// 检查是否包含字母
  static bool _hasLetter(String passphrase) {
    return passphrase.contains(RegExp(r'[a-zA-Z]'));
  }

  /// 检查是否包含特殊字符
  static bool _hasSpecialChar(String passphrase) {
    return passphrase.contains(RegExp(r'[^a-zA-Z0-9]'));
  }
}
