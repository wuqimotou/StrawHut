// 临时脚本：提交并推送修复
import 'dart:io';

Future<int> _run(String executable, List<String> args) async {
  stdout.writeln('\n>>> $executable ${args.join(' ')}\n');
  final p = await Process.start(executable, args, runInShell: true);
  p.stdout.transform(SystemEncoding().decoder).listen(stdout.write);
  p.stderr.transform(SystemEncoding().decoder).listen(stderr.write);
  final code = await p.exitCode;
  return code;
}

Future<void> main() async {
  await _run('git', ['add', '-A']);
  await _run('git', ['status']);
  await _run('git', ['commit', '-m', 'fix: restore file_picker 11.x API in quill_toolbar after rebase, remove temp scripts']);
  await _run('git', ['push']);
  stdout.writeln('\n========== 完成 ==========');
}
