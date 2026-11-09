import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ProcessOutput {
  const ProcessOutput(this.exitCode, this.stdout, this.stderr);

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get succeeded => exitCode == 0;
}

class ProcessRunner {
  const ProcessRunner();

  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
    const decoder = Utf8Decoder(allowMalformed: true);
    final stdout = process.stdout.transform(decoder).join();
    final stderr = process.stderr.transform(decoder).join();
    await process.stdin.close();

    final int exitCode;
    try {
      exitCode = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
      throw ProcessException(
        executable,
        arguments,
        'Tempo limite de ${timeout.inSeconds}s excedido',
      );
    }
    return ProcessOutput(exitCode, await stdout, await stderr);
  }

  Future<bool> tryRun(String executable, List<String> arguments) async {
    try {
      final result = await run(
        executable,
        arguments,
        timeout: const Duration(seconds: 15),
      );
      return result.succeeded;
    } on ProcessException {
      return false;
    }
  }

  Future<void> startDetached(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.detached,
    );
  }
}
