// 临时脚本：同步更改到 GitHub
import 'dart:io';

Future<int> _run(String executable, List<String> args) async {
  stdout.writeln('\n>>> $executable ${args.join(' ')}\n');
  final p = await Process.start(executable, args, runInShell: true);
  p.stdout.transform(SystemEncoding().decoder).listen(stdout.write);
  p.stderr.transform(SystemEncoding().decoder).listen(stderr.write);
  return p.exitCode;
}

Future<void> main() async {
  // 1. 查看当前状态
  await _run('git', ['status']);

  // 2. 添加所有更改
  await _run('git', ['add', '-A']);

  // 3. 检查是否有待提交的更改
  final statusResult = await Process.run(
    'git',
    ['status', '--porcelain'],
    runInShell: true,
  );
  final hasChanges = (statusResult.stdout as String).trim().isNotEmpty;

  if (hasChanges) {
    // 4. 提交更改
    await _run('git', [
      'commit',
      '-m',
      'chore: sync local changes to GitHub',
    ]);
  } else {
    stdout.writeln('\n没有待提交的本地更改');
  }

  // 5. 拉取远程更改并 rebase
  await _run('git', ['pull', '--rebase']);

  // 6. 推送到远程
  await _run('git', ['push']);

  stdout.writeln('\n========== 同步完成 ==========');
}
