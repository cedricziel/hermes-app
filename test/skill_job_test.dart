import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/skill_job.dart';

void main() {
  /// Runs a job whose polls answer from [answers] in order (an exception is
  /// thrown, null is an unknown job), with no real waiting.
  Future<SkillJob> run(
    List<Object?> answers, {
    StartedJob started = const StartedJob(name: 'job', pid: 1),
    Object? startError,
    int maxPolls = 50,
    int maxReadFailures = 3,
  }) async {
    var i = 0;
    final job = SkillJob(
      title: 'Installing x',
      start: () async {
        if (startError != null) throw startError;
        return started;
      },
      status: (name) async {
        final answer = answers[i < answers.length ? i++ : answers.length - 1];
        if (answer is Exception) throw answer;
        return answer as JobStatus?;
      },
      wait: (_) async {},
      maxPolls: maxPolls,
      maxReadFailures: maxReadFailures,
    );
    await job.run();
    return job;
  }

  JobStatus running([List<String> lines = const []]) =>
      JobStatus(running: true, pid: 1, lines: lines);
  JobStatus exited(int code, {int pid = 1}) =>
      JobStatus(running: false, exitCode: code, pid: pid, lines: ['done']);

  test('exit code 0 is success and keeps the log tail', () async {
    final job = await run([
      running(['a']),
      exited(0),
    ]);

    expect(job.state, JobState.succeeded);
    expect(job.lines, ['done']);
  });

  test('another exit code is a failure', () async {
    expect((await run([exited(2)])).state, JobState.failed);
  });

  test('a job that ends with no exit code is unknown, never success', () async {
    final job = await run([const JobStatus(running: false, pid: 1)]);

    expect(job.state, JobState.unknown);
  });

  test('an unknown job (404) is unknown', () async {
    expect((await run([null])).state, JobState.unknown);
  });

  test('repeated read failures are unknown, one is forgiven', () async {
    expect(
      (await run([DioException(requestOptions: RequestOptions()), exited(0)]))
          .state,
      JobState.succeeded,
    );
    expect(
      (await run([DioException(requestOptions: RequestOptions())])).state,
      JobState.unknown,
    );
  });

  test(
    'a status for another pid is an older job and is not believed',
    () async {
      final job = await run([
        exited(0, pid: 99),
        exited(0, pid: 99),
        exited(1),
      ]);

      expect(job.state, JobState.failed);
    },
  );

  test('gives up after the poll cap', () async {
    expect((await run([running()], maxPolls: 5)).state, JobState.unknown);
  });

  test('a job that cannot start fails with the server\'s reason', () async {
    final job = await run([], startError: const SkillsRejected('Nope'));

    expect(job.state, JobState.failed);
    expect(job.error, 'Nope');
  });

  test('any other start failure fails with a generic reason', () async {
    final job = await run([], startError: StateError('x'));

    expect(job.state, JobState.failed);
    expect(job.error, isNotEmpty);
  });

  test('listeners hear the job change', () async {
    var heard = 0;
    final job = SkillJob(
      title: 't',
      start: () async => const StartedJob(name: 'j', pid: 1),
      status: (_) async => exited(0),
      wait: (_) async {},
    )..addListener(() => heard++);

    await job.run();

    expect(heard, greaterThanOrEqualTo(2));
  });
}
