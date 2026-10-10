import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/growth/domain/growth_models.dart';

OutreachTask t({
  int id = 1,
  TaskStatus status = TaskStatus.todo,
  DateTime? due,
  DateTime? follow,
  String platform = 'tiktok',
}) =>
    OutreachTask(
      id: id,
      creatorName: 'C$id',
      platform: platform,
      channel: OutreachChannel.forPlatform(platform),
      status: status,
      dueAt: due ?? DateTime(2026, 10, 1),
      followupAt: follow,
    );

void main() {
  final now = DateTime(2026, 10, 10, 12);

  group('bucket', () {
    test('todo is today once due, later before then', () {
      expect(t(due: DateTime(2026, 10, 10, 9)).bucket(now), TaskBucket.today);
      expect(t(due: DateTime(2026, 10, 10, 12)).bucket(now), TaskBucket.today);
      expect(t(due: DateTime(2026, 10, 12)).bucket(now), TaskBucket.later);
    });
    test('sent waits until the follow-up date, then returns to today', () {
      expect(
          t(status: TaskStatus.sent, follow: DateTime(2026, 10, 15))
              .bucket(now),
          TaskBucket.waiting);
      final due = t(status: TaskStatus.sent, follow: DateTime(2026, 10, 9));
      expect(due.bucket(now), TaskBucket.today);
      expect(due.needsFollowUp(now), isTrue);
    });
    test('sent with no follow-up date stays waiting', () {
      expect(t(status: TaskStatus.sent).bucket(now), TaskBucket.waiting);
    });
    test('snoozed hides until its new due date', () {
      expect(
          t(status: TaskStatus.snoozed, due: DateTime(2026, 10, 14))
              .bucket(now),
          TaskBucket.later);
      expect(
          t(status: TaskStatus.snoozed, due: DateTime(2026, 10, 9)).bucket(now),
          TaskBucket.today);
    });
    test('replied / declined / done are finished', () {
      for (final s in [
        TaskStatus.replied,
        TaskStatus.declined,
        TaskStatus.done
      ]) {
        expect(t(status: s).bucket(now), TaskBucket.finished);
      }
    });
  });

  test('sortQueue: today, waiting, later, finished; today oldest-due first',
      () {
    final sorted = sortQueue([
      t(id: 1, status: TaskStatus.done),
      t(id: 2, due: DateTime(2026, 10, 20)),
      t(id: 3, status: TaskStatus.sent, follow: DateTime(2026, 10, 16)),
      t(id: 4, due: DateTime(2026, 10, 9)),
      t(id: 5, due: DateTime(2026, 10, 2)),
      t(id: 6, status: TaskStatus.sent, follow: DateTime(2026, 10, 12)),
    ], now);
    expect(sorted.map((x) => x.id), [5, 4, 6, 3, 2, 1]);
  });

  test('default channel by platform', () {
    expect(OutreachChannel.forPlatform('tiktok'), OutreachChannel.tiktokInvite);
    expect(
        OutreachChannel.forPlatform('instagram'), OutreachChannel.instagramDm);
    expect(
        OutreachChannel.forPlatform('youtube'), OutreachChannel.youtubeEmail);
    expect(OutreachChannel.forPlatform('x'), OutreachChannel.other);
  });

  test('parsers fall back safely on unknown values', () {
    expect(TaskStatus.parse('???'), TaskStatus.todo);
    expect(OutreachChannel.parse(null), OutreachChannel.other);
    expect(ApplicationStatus.parse('weird'),
        ApplicationStatus.pendingConfirmation);
  });

  test('fromJson reads a database row', () {
    final x = OutreachTask.fromJson({
      'id': 7,
      'creator_name': 'Sara',
      'platform': 'youtube',
      'channel': 'youtube_email',
      'status': 'sent',
      'due_at': '2026-10-01T00:00:00Z',
      'followup_at': '2026-10-06T00:00:00Z',
      'sent_at': '2026-10-01T10:00:00Z',
      'source': 'application',
      'application_id': 3,
    });
    expect(x.channel, OutreachChannel.youtubeEmail);
    expect(x.applicationId, 3);
    expect(x.bucket(DateTime.utc(2026, 10, 10)), TaskBucket.today);
  });

  test(
      'welcome draft greets by first name and never promises a code that does not exist yet',
      () {
    final d = welcomeDraft('  Sara Khan ');
    expect(d, startsWith('Hi Sara,'));
    expect(d, contains('[YOUR CODE]'));
  });
}
