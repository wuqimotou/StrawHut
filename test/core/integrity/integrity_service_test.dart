import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/integrity/integrity_constants.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';

void main() {
  group('IntegrityService 单元测试', () {
    late IntegrityService integrityService;

    setUp(() {
      // 每个测试用例执行前初始化服务实例
      integrityService = IntegrityService();
    });

    group('computeHash - 相同输入产生相同哈希', () {
      test('TC-01: 相同字符串输入应产生完全相同的哈希值', () {
        // 准备测试数据
        const input = 'Hello, World!';

        // 第一次计算哈希
        final hash1 = integrityService.computeHash(input);

        // 第二次计算哈希
        final hash2 = integrityService.computeHash(input);

        // 验证：两次计算结果必须完全一致
        expect(hash1, equals(hash2), reason: '相同输入必须产生相同的哈希值（确定性）');
      });

      test('TC-02: 多次重复计算同一输入应保持一致', () {
        const input = 'StrawHat Test Data';

        // 连续计算5次
        final hashes =
            List.generate(5, (index) => integrityService.computeHash(input));

        // 验证：所有结果都与第一次相同
        for (var i = 1; i < hashes.length; i++) {
          expect(hashes[i], equals(hashes[0]), reason: '第${i + 1}次计算结果应与第1次一致');
        }
      });

      test('TC-03: JSON格式内容重复计算应产生相同哈希', () {
        // 模拟真实的.straw文件内容
        const jsonContent = '''
        {
          "version": "1.0",
          "encrypted_content": "base64encodeddata",
          "integrity": {
            "hash_algorithm": "SHA-256",
            "hash": "placeholder"
          }
        }
        ''';

        final hash1 = integrityService.computeHash(jsonContent);
        final hash2 = integrityService.computeHash(jsonContent);

        expect(hash1, equals(hash2), reason: 'JSON内容重复计算应产生相同哈希');
      });
    });

    group('computeHash - 微小改动导致不同哈希', () {
      test('TC-04: 单个字符差异应产生完全不同的哈希值', () {
        const original = 'Hello, World!';
        const modified = 'Hello, World?'; // 仅最后一个字符不同

        final hashOriginal = integrityService.computeHash(original);
        final hashModified = integrityService.computeHash(modified);

        expect(hashOriginal, isNot(equals(hashModified)),
            reason: '单个字符改变应导致哈希值不同（雪崩效应）',);
      });

      test('TC-05: 大小写差异应产生不同哈希值', () {
        const lowercase = 'password123';
        const uppercase = 'PASSWORD123';

        final hashLower = integrityService.computeHash(lowercase);
        final hashUpper = integrityService.computeHash(uppercase);

        expect(hashLower, isNot(equals(hashUpper)), reason: '大小写改变应导致哈希值不同');
      });

      test('TC-06: 添加空格应产生不同哈希值', () {
        const original = 'test data';
        const withSpace = 'test data '; // 末尾多一个空格

        final hashOriginal = integrityService.computeHash(original);
        final hashWithSpace = integrityService.computeHash(withSpace);

        expect(hashOriginal, isNot(equals(hashWithSpace)),
            reason: '添加空格应导致哈希值不同',);
      });

      test('TC-07: JSON内容微小修改应产生不同哈希值', () {
        const originalJson = '{"key": "value", "number": 123}';
        const modifiedJson = '{"key": "value", "number": 124}'; // 仅数字+1

        final hashOriginal = integrityService.computeHash(originalJson);
        final hashModified = integrityService.computeHash(modifiedJson);

        expect(hashOriginal, isNot(equals(hashModified)),
            reason: 'JSON中微小数值变化应导致哈希值不同',);
      });

      test('TC-08: 空字符串与单个空格应产生不同哈希值', () {
        const emptyString = '';
        const spaceString = ' ';

        final hashEmpty = integrityService.computeHash(emptyString);
        final hashSpace = integrityService.computeHash(spaceString);

        expect(hashEmpty, isNot(equals(hashSpace)), reason: '空字符串与空格应产生不同哈希');
      });
    });

    group('computeHash - 哈希格式验证', () {
      test('TC-09: 哈希值格式应为 "sha256:{十六进制}"', () {
        const input = 'test content';
        final hash = integrityService.computeHash(input);

        // 验证以 "sha256:" 开头
        expect(hash.startsWith('sha256:'), isTrue,
            reason: '哈希值应以 "sha256:" 开头',);

        // 验证冒号后是十六进制字符
        final hexPart = hash.substring(7); // 去掉 "sha256:" 前缀
        expect(RegExp(r'^[0-9a-f]+$').hasMatch(hexPart), isTrue,
            reason: '哈希值应为小写十六进制字符串',);
      });

      test('TC-10: SHA-256 哈希的十六进制部分长度应为64个字符', () {
        const input = 'test content';
        final hash = integrityService.computeHash(input);

        final hexPart = hash.substring(7);
        expect(hexPart.length, equals(64),
            reason: 'SHA-256 哈希转换为十六进制后应为64个字符（32字节）',);
      });

      test('TC-11: 验证常量 IntegrityConstants.hashAlgorithm 的值', () {
        expect(IntegrityConstants.hashAlgorithm, equals('SHA-256'),
            reason: '哈希算法常量应为 "SHA-256"',);
      });

      test('TC-12: 验证常量 IntegrityConstants.hashLengthBytes 的值', () {
        expect(IntegrityConstants.hashLengthBytes, equals(32),
            reason: 'SHA-256 哈希长度应为32字节',);
      });
    });

    group('computeHash - 边界条件测试', () {
      test('TC-13: 空字符串应能正常计算哈希', () {
        const emptyInput = '';
        final hash = integrityService.computeHash(emptyInput);

        expect(hash, isNotNull, reason: '空字符串哈希不应为null');
        expect(hash.startsWith('sha256:'), isTrue, reason: '空字符串哈希格式应正确');
        expect(hash.substring(7).length, equals(64), reason: '空字符串哈希长度应正确');
      });

      test('TC-14: 超长字符串应能正常计算哈希', () {
        // 生成10000个字符的字符串
        final longInput = 'A' * 10000;
        final hash = integrityService.computeHash(longInput);

        expect(hash, isNotNull, reason: '长字符串哈希不应为null');
        expect(hash.startsWith('sha256:'), isTrue, reason: '长字符串哈希格式应正确');
      });

      test('TC-15: 包含特殊字符的字符串应能正常计算哈希', () {
        const specialChars = '!@#\$%^&*()_+-=[]{}|;:\'",.<>?/~`';
        final hash = integrityService.computeHash(specialChars);

        expect(hash, isNotNull, reason: '特殊字符哈希不应为null');
        expect(hash.startsWith('sha256:'), isTrue, reason: '特殊字符哈希格式应正确');
      });

      test('TC-16: 包含Unicode/中文字符的字符串应能正常计算哈希', () {
        const unicodeInput = '测试中文内容 🎩 草帽海贼团';
        final hash = integrityService.computeHash(unicodeInput);

        expect(hash, isNotNull, reason: 'Unicode内容哈希不应为null');
        expect(hash.startsWith('sha256:'), isTrue, reason: 'Unicode内容哈希格式应正确');
      });

      test('TC-17: 包含换行符的字符串应能正常计算哈希', () {
        const multilineInput = 'line1\nline2\nline3\r\nline4';
        final hash = integrityService.computeHash(multilineInput);

        expect(hash, isNotNull, reason: '多行内容哈希不应为null');
        expect(hash.startsWith('sha256:'), isTrue, reason: '多行内容哈希格式应正确');
      });

      test('TC-18: 不同长度字符串的哈希值应互不相同', () {
        final hash1 = integrityService.computeHash('a');
        final hash2 = integrityService.computeHash('aa');
        final hash3 = integrityService.computeHash('aaa');

        expect(hash1, isNot(equals(hash2)), reason: '不同长度哈希应不同');
        expect(hash2, isNot(equals(hash3)), reason: '不同长度哈希应不同');
        expect(hash1, isNot(equals(hash3)), reason: '不同长度哈希应不同');
      });
    });

    group('verifyIntegrity - 验证逻辑正确性', () {
      test('TC-19: 匹配的哈希应返回 true', () {
        const content = 'This is test content for verification';
        final hash = integrityService.computeHash(content);

        final result = integrityService.verifyIntegrity(
          content: content,
          expectedHash: hash,
        );

        expect(result, isTrue, reason: '哈希匹配时应返回true，表示文件完整');
      });

      test('TC-20: 不匹配的哈希应返回 false', () {
        const content = 'Original content';
        const wrongHash =
            'sha256:0000000000000000000000000000000000000000000000000000000000000000';

        final result = integrityService.verifyIntegrity(
          content: content,
          expectedHash: wrongHash,
        );

        expect(result, isFalse, reason: '哈希不匹配时应返回false，表示文件可能被篡改');
      });

      test('TC-21: 内容被修改后验证应返回 false', () {
        const originalContent = 'Original data for integrity check';
        const tamperedContent = 'Original data for integrity check!'; // 添加感叹号

        final originalHash = integrityService.computeHash(originalContent);

        // 使用被修改的内容和原始哈希进行验证
        final result = integrityService.verifyIntegrity(
          content: tamperedContent,
          expectedHash: originalHash,
        );

        expect(result, isFalse, reason: '内容被篡改后验证应失败');
      });

      test('TC-22: JSON内容完整性验证 - 正常情况', () {
        const jsonContent = '''
        {
          "data": "test",
          "timestamp": 1234567890
        }
        ''';
        final hash = integrityService.computeHash(jsonContent);

        final result = integrityService.verifyIntegrity(
          content: jsonContent,
          expectedHash: hash,
        );

        expect(result, isTrue, reason: '未修改的JSON内容验证应通过');
      });

      test('TC-23: JSON内容被篡改后验证应失败', () {
        const originalJson = '{"secret": "password123"}';
        const tamperedJson = '{"secret": "hacked!"}';

        final originalHash = integrityService.computeHash(originalJson);

        final result = integrityService.verifyIntegrity(
          content: tamperedJson,
          expectedHash: originalHash,
        );

        expect(result, isFalse, reason: '被篡改的JSON内容验证应失败');
      });

      test('TC-24: 空字符串的完整性验证', () {
        const emptyContent = '';
        final hash = integrityService.computeHash(emptyContent);

        final result = integrityService.verifyIntegrity(
          content: emptyContent,
          expectedHash: hash,
        );

        expect(result, isTrue, reason: '空字符串验证应通过（匹配自身哈希）');
      });

      test('TC-25: 格式错误但内容相同的哈希应返回 false', () {
        const content = 'test content';
        final correctHash = integrityService.computeHash(content);
        // 去掉 "sha256:" 前缀
        final wrongFormatHash = correctHash.substring(7);

        final result = integrityService.verifyIntegrity(
          content: content,
          expectedHash: wrongFormatHash,
        );

        expect(result, isFalse, reason: '即使十六进制部分相同，但缺少前缀也应验证失败（字符串不匹配）');
      });

      test('TC-26: 验证空内容的错误哈希', () {
        const emptyContent = '';
        const randomHash =
            'sha256:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';

        final result = integrityService.verifyIntegrity(
          content: emptyContent,
          expectedHash: randomHash,
        );

        expect(result, isFalse, reason: '空内容的哈希与随机哈希不匹配，应返回false');
      });
    });

    group('verifyIntegrity - 边界情况', () {
      test('TC-27: 仅改变expectedHash中的一个字符应验证失败', () {
        const content = 'important data';
        final correctHash = integrityService.computeHash(content);

        // 修改哈希值的最后一个字符
        final tamperedHash = correctHash.substring(0, correctHash.length - 1) +
            (correctHash.endsWith('a') ? 'b' : 'a');

        final result = integrityService.verifyIntegrity(
          content: content,
          expectedHash: tamperedHash,
        );

        expect(result, isFalse, reason: '哈希值仅改变一个字符也应验证失败');
      });

      test('TC-28: 使用不同算法前缀的哈希应验证失败', () {
        const content = 'test data';
        final correctHash = integrityService.computeHash(content);
        // 将前缀改为 "md5:"
        final wrongPrefixHash = correctHash.replaceFirst('sha256:', 'md5:');

        final result = integrityService.verifyIntegrity(
          content: content,
          expectedHash: wrongPrefixHash,
        );

        expect(result, isFalse, reason: '算法前缀不同应验证失败');
      });
    });

    group('computeHashFromBytes - 相同输入产生相同哈希', () {
      test('TC-29: 相同字节数组应产生完全相同的哈希值', () {
        final input = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

        final hash1 = integrityService.computeHashFromBytes(input);
        final hash2 = integrityService.computeHashFromBytes(input);

        expect(hash1, equals(hash2), reason: '相同字节数组必须产生相同的哈希值（确定性）');
      });

      test('TC-30: 多次重复计算同一字节数组应保持一致', () {
        final input = Uint8List.fromList(List.generate(32, (i) => i));

        final hashes = List.generate(
            5, (index) => integrityService.computeHashFromBytes(input),);

        for (var i = 1; i < hashes.length; i++) {
          expect(hashes[i], equals(hashes[0]), reason: '第${i + 1}次计算结果应与第1次一致');
        }
      });

      test('TC-31: 大型字节数组重复计算应产生相同哈希', () {
        // 模拟 1MB 的二进制数据
        final input =
            Uint8List.fromList(List.generate(1048576, (i) => i % 256));

        final hash1 = integrityService.computeHashFromBytes(input);
        final hash2 = integrityService.computeHashFromBytes(input);

        expect(hash1, equals(hash2), reason: '大型字节数组重复计算应产生相同哈希');
      });
    });

    group('computeHashFromBytes - 微小改动导致不同哈希', () {
      test('TC-32: 单个字节差异应产生完全不同的哈希值', () {
        final original = Uint8List.fromList([1, 2, 3, 4, 5]);
        final modified = Uint8List.fromList([1, 2, 3, 4, 6]); // 仅最后一个字节不同

        final hashOriginal = integrityService.computeHashFromBytes(original);
        final hashModified = integrityService.computeHashFromBytes(modified);

        expect(hashOriginal, isNot(equals(hashModified)),
            reason: '单个字节改变应导致哈希值不同（雪崩效应）',);
      });

      test('TC-33: 不同长度的字节数组应产生不同哈希值', () {
        final short = Uint8List.fromList([1, 2, 3]);
        final long = Uint8List.fromList([1, 2, 3, 4]);

        final hashShort = integrityService.computeHashFromBytes(short);
        final hashLong = integrityService.computeHashFromBytes(long);

        expect(hashShort, isNot(equals(hashLong)), reason: '不同长度的字节数组应产生不同哈希值');
      });

      test('TC-34: 添加一个零字节应产生不同哈希值', () {
        final original = Uint8List.fromList([0xFF, 0xAB, 0xCD]);
        final withZero = Uint8List.fromList([0xFF, 0xAB, 0xCD, 0x00]);

        final hashOriginal = integrityService.computeHashFromBytes(original);
        final hashWithZero = integrityService.computeHashFromBytes(withZero);

        expect(hashOriginal, isNot(equals(hashWithZero)),
            reason: '添加零字节应导致哈希值不同',);
      });
    });

    group('computeHashFromBytes - 哈希格式验证', () {
      test('TC-35: 哈希值格式应为 "sha256:{十六进制}"', () {
        final input = Uint8List.fromList([0x01, 0x02, 0x03]);
        final hash = integrityService.computeHashFromBytes(input);

        // 验证以 "sha256:" 开头
        expect(hash.startsWith('sha256:'), isTrue,
            reason: '哈希值应以 "sha256:" 开头',);

        // 验证冒号后是十六进制字符
        final hexPart = hash.substring(7);
        expect(RegExp(r'^[0-9a-f]+$').hasMatch(hexPart), isTrue,
            reason: '哈希值应为小写十六进制字符串',);
      });

      test('TC-36: SHA-256 哈希的十六进制部分长度应为64个字符', () {
        final input = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
        final hash = integrityService.computeHashFromBytes(input);

        final hexPart = hash.substring(7);
        expect(hexPart.length, equals(64),
            reason: 'SHA-256 哈希转换为十六进制后应为64个字符（32字节）',);
      });
    });

    group('computeHashFromBytes - 边界条件测试', () {
      test('TC-37: 空字节数组应能正常计算哈希', () {
        final emptyBytes = Uint8List(0);
        final hash = integrityService.computeHashFromBytes(emptyBytes);

        expect(hash, isNotNull, reason: '空字节数组哈希不应为null');
        expect(hash.startsWith('sha256:'), isTrue, reason: '空字节数组哈希格式应正确');
        expect(hash.substring(7).length, equals(64), reason: '空字节数组哈希长度应正确');
      });

      test('TC-38: 单字节应能正常计算哈希', () {
        final singleByte = Uint8List.fromList([0x42]);
        final hash = integrityService.computeHashFromBytes(singleByte);

        expect(hash, isNotNull, reason: '单字节哈希不应为null');
        expect(hash.startsWith('sha256:'), isTrue, reason: '单字节哈希格式应正确');
        expect(hash.substring(7).length, equals(64), reason: '单字节哈希长度应正确');
      });

      test('TC-39: 超长字节数组应能正常计算哈希', () {
        // 生成 10000 字节的数据
        final longBytes = Uint8List.fromList(
          List.generate(10000, (index) => index % 256),
        );
        final hash = integrityService.computeHashFromBytes(longBytes);

        expect(hash, isNotNull, reason: '长字节数组哈希不应为null');
        expect(hash.startsWith('sha256:'), isTrue, reason: '长字节数组哈希格式应正确');
        expect(hash.substring(7).length, equals(64), reason: '长字节数组哈希长度应正确');
      });

      test('TC-40: 包含全零字节的数组应能正常计算哈希', () {
        final zeroBytes = Uint8List(64);
        final hash = integrityService.computeHashFromBytes(zeroBytes);

        expect(hash, isNotNull, reason: '全零字节哈希不应为null');
        expect(hash.startsWith('sha256:'), isTrue, reason: '全零字节哈希格式应正确');
      });

      test('TC-41: 包含全 0xFF 字节的数组应能正常计算哈希', () {
        final ffBytes = Uint8List.fromList(List.generate(32, (_) => 0xFF));
        final hash = integrityService.computeHashFromBytes(ffBytes);

        expect(hash, isNotNull, reason: '全FF字节哈希不应为null');
        expect(hash.startsWith('sha256:'), isTrue, reason: '全FF字节哈希格式应正确');
      });
    });

    group('computeHashFromBytes - 与 computeHash 一致性验证', () {
      test('TC-42: UTF-8 字符串的字节哈希应与 computeHash 结果一致', () {
        const testString = 'Hello, StrawHut!';
        final utf8Bytes = Uint8List.fromList(utf8.encode(testString));

        final hashFromString = integrityService.computeHash(testString);
        final hashFromBytes = integrityService.computeHashFromBytes(utf8Bytes);

        expect(hashFromBytes, equals(hashFromString),
            reason: 'UTF-8 字符串的字节哈希应与 computeHash 结果一致',);
      });

      test('TC-43: 中文内容的字节哈希应与 computeHash 结果一致', () {
        const testString = '测试中文内容 草帽海贼团';
        final utf8Bytes = Uint8List.fromList(utf8.encode(testString));

        final hashFromString = integrityService.computeHash(testString);
        final hashFromBytes = integrityService.computeHashFromBytes(utf8Bytes);

        expect(hashFromBytes, equals(hashFromString),
            reason: '中文内容的字节哈希应与 computeHash 结果一致',);
      });

      test('TC-44: 空字符串与空字节数组的哈希应一致', () {
        const emptyString = '';
        final emptyBytes = Uint8List(0);

        final hashFromString = integrityService.computeHash(emptyString);
        final hashFromBytes = integrityService.computeHashFromBytes(emptyBytes);

        expect(hashFromBytes, equals(hashFromString),
            reason: '空字符串与空字节数组的哈希应一致',);
      });

      test('TC-45: JSON 内容的字节哈希应与 computeHash 结果一致', () {
        const jsonContent = '{"key": "value", "number": 42}';
        final utf8Bytes = Uint8List.fromList(utf8.encode(jsonContent));

        final hashFromString = integrityService.computeHash(jsonContent);
        final hashFromBytes = integrityService.computeHashFromBytes(utf8Bytes);

        expect(hashFromBytes, equals(hashFromString),
            reason: 'JSON 内容的字节哈希应与 computeHash 结果一致',);
      });
    });
  });
}
