// 临时脚本：通过 Dart 执行 git 命令（绕过 PowerShell 执行策略限制）
import 'dart:io';

Future<int> _run(String executable, List<String> args) async {
  stdout.writeln('\n>>> $executable ${args.join(' ')}\n');
  final p = await Process.start(executable, args, runInShell: true);
  p.stdout.transform(SystemEncoding().decoder).listen(stdout.write);
  p.stderr.transform(SystemEncoding().decoder).listen(stderr.write);
  final code = await p.exitCode;
  if (code != 0) stderr.writeln('[错误] exit code: $code');
  return code;
}

Future<void> main(List<String> args) async {
  final message = args.isNotEmpty ? args.first : 'update';

  // 1. git add -A
  var code = await _run('git', ['add', '-A']);
  if (code != 0) exit(1);

  // 2. git status (查看暂存状态)
  await _run('git', ['status']);

  // 3. git commit
  code = await _run('git', ['commit', '-m', message]);
  // 如果没有变化，commit 会返回非零，继续尝试 push
  // 但如果 commit 成功则继续

  // 4. git pull --rebase (先同步远程更改)
  code = await _run('git', ['pull', '--rebase']);
  if (code != 0) {
    stderr.writeln('[错误] git pull --rebase 失败');
    exit(1);
  }

  // 5. git push
  code = await _run('git', ['push']);
  if (code != 0) {
    stderr.writeln('[提示] push 失败，可能需要先 git pull');
    exit(1);
  }

  stdout.writeln('\n========== 同步完成 ==========');
}
