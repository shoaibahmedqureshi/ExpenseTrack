enum OutreachChannel {
  tiktokInvite('tiktok_invite', 'TikTok One invite'),
  instagramDm('instagram_dm', 'Instagram DM'),
  youtubeEmail('youtube_email', 'YouTube business email'),
  email('email', 'Email'),
  other('other', 'Other');

  const OutreachChannel(this.key, this.label);
  final String key;
  final String label;

  static OutreachChannel parse(String? k) =>
      OutreachChannel.values.firstWhere((c) => c.key == k, orElse: () => OutreachChannel.other);

  /// Sensible default route for a platform. The official channels are manual, so this only
  /// pre-selects the field; a person still sends the message.
  static OutreachChannel forPlatform(String platform) => switch (platform) {
        'tiktok' => OutreachChannel.tiktokInvite,
        'instagram' => OutreachChannel.instagramDm,
        'youtube' => OutreachChannel.youtubeEmail,
        'email' => OutreachChannel.email,
        _ => OutreachChannel.other,
      };
}

enum TaskStatus {
  todo('todo'),
  sent('sent'),
  replied('replied'),
  declined('declined'),
  done('done'),
  snoozed('snoozed');

  const TaskStatus(this.key);
  final String key;
  static TaskStatus parse(String? k) => TaskStatus.values.firstWhere((s) => s.key == k, orElse: () => TaskStatus.todo);
}

enum TaskBucket { today, waiting, later, finished }

const followUpAfter = Duration(days: 5);

class OutreachTask {
  const OutreachTask({
    required this.id,
    required this.creatorName,
    required this.platform,
    required this.channel,
    required this.status,
    required this.dueAt,
    this.handle,
    this.profileUrl,
    this.niche,
    this.fitReason,
    this.evidence,
    this.draftMessage,
    this.followupAt,
    this.sentAt,
    this.notes,
    this.source = 'manual',
    this.applicationId,
  });

  final int id;
  final String creatorName;
  final String platform;
  final OutreachChannel channel;
  final TaskStatus status;
  final DateTime dueAt;
  final String? handle;
  final String? profileUrl;
  final String? niche;
  final String? fitReason;
  final String? evidence;
  final String? draftMessage;
  final DateTime? followupAt;
  final DateTime? sentAt;
  final String? notes;
  final String source;
  final int? applicationId;

  /// Where this task belongs in the queue right now.
  TaskBucket bucket(DateTime now) {
    switch (status) {
      case TaskStatus.replied:
      case TaskStatus.declined:
      case TaskStatus.done:
        return TaskBucket.finished;
      case TaskStatus.snoozed:
        return dueAt.isAfter(now) ? TaskBucket.later : TaskBucket.today;
      case TaskStatus.sent:
        final f = followupAt;
        return (f != null && !f.isAfter(now)) ? TaskBucket.today : TaskBucket.waiting;
      case TaskStatus.todo:
        return dueAt.isAfter(now) ? TaskBucket.later : TaskBucket.today;
    }
  }

  /// A sent task that is back in "today" because its follow-up date passed.
  bool needsFollowUp(DateTime now) =>
      status == TaskStatus.sent && followupAt != null && !followupAt!.isAfter(now);

  factory OutreachTask.fromJson(Map<String, dynamic> j) => OutreachTask(
        id: j['id'] as int,
        creatorName: j['creator_name'] as String,
        platform: j['platform'] as String,
        channel: OutreachChannel.parse(j['channel'] as String?),
        status: TaskStatus.parse(j['status'] as String?),
        dueAt: DateTime.parse(j['due_at'] as String).toLocal(),
        handle: j['handle'] as String?,
        profileUrl: j['profile_url'] as String?,
        niche: j['niche'] as String?,
        fitReason: j['fit_reason'] as String?,
        evidence: j['evidence'] as String?,
        draftMessage: j['draft_message'] as String?,
        followupAt: j['followup_at'] == null ? null : DateTime.parse(j['followup_at'] as String).toLocal(),
        sentAt: j['sent_at'] == null ? null : DateTime.parse(j['sent_at'] as String).toLocal(),
        notes: j['notes'] as String?,
        source: (j['source'] as String?) ?? 'manual',
        applicationId: j['application_id'] as int?,
      );
}

/// Sorts a queue: today first (oldest due first), then waiting by follow-up date, later, then finished (newest first).
List<OutreachTask> sortQueue(Iterable<OutreachTask> tasks, DateTime now) {
  final list = tasks.toList();
  int rank(TaskBucket b) => switch (b) {
        TaskBucket.today => 0,
        TaskBucket.waiting => 1,
        TaskBucket.later => 2,
        TaskBucket.finished => 3,
      };
  list.sort((a, b) {
    final ba = a.bucket(now), bb = b.bucket(now);
    if (ba != bb) return rank(ba).compareTo(rank(bb));
    if (ba == TaskBucket.finished) return b.dueAt.compareTo(a.dueAt);
    final fa = (ba == TaskBucket.waiting ? a.followupAt : a.dueAt) ?? a.dueAt;
    final fb = (bb == TaskBucket.waiting ? b.followupAt : b.dueAt) ?? b.dueAt;
    return fa.compareTo(fb);
  });
  return list;
}

enum ApplicationStatus {
  pendingConfirmation('pending_confirmation', 'Awaiting email confirmation'),
  confirmed('confirmed', 'Ready to review'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  onboarded('onboarded', 'Onboarded');

  const ApplicationStatus(this.key, this.label);
  final String key;
  final String label;
  static ApplicationStatus parse(String? k) =>
      ApplicationStatus.values.firstWhere((s) => s.key == k, orElse: () => ApplicationStatus.pendingConfirmation);
}

const audienceBandLabels = {
  'under_1k': 'Under 1K',
  '1k_10k': '1K to 10K',
  '10k_50k': '10K to 50K',
  '50k_250k': '50K to 250K',
  'over_250k': 'Over 250K',
};

const platformLabels = {
  'tiktok': 'TikTok',
  'youtube': 'YouTube',
  'instagram': 'Instagram',
  'x': 'X',
  'email': 'Email',
  'other': 'Other',
};

class CreatorApplication {
  const CreatorApplication({
    required this.id,
    required this.name,
    required this.email,
    required this.platform,
    required this.handle,
    required this.audienceBand,
    required this.niche,
    required this.status,
    required this.createdAt,
    this.profileUrl,
    this.about,
    this.country,
    this.adminNotes,
  });

  final int id;
  final String name;
  final String email;
  final String platform;
  final String handle;
  final String audienceBand;
  final String niche;
  final ApplicationStatus status;
  final DateTime createdAt;
  final String? profileUrl;
  final String? about;
  final String? country;
  final String? adminNotes;

  bool get awaitingDecision => status == ApplicationStatus.confirmed;

  factory CreatorApplication.fromJson(Map<String, dynamic> j) => CreatorApplication(
        id: j['id'] as int,
        name: j['name'] as String,
        email: j['email'] as String,
        platform: j['platform'] as String,
        handle: j['handle'] as String,
        audienceBand: j['audience_band'] as String,
        niche: j['niche'] as String,
        status: ApplicationStatus.parse(j['status'] as String?),
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        profileUrl: j['profile_url'] as String?,
        about: j['about'] as String?,
        country: j['country'] as String?,
        adminNotes: j['admin_notes'] as String?,
      );
}

/// The welcome note pre-filled when an application is approved. The code is a placeholder on purpose:
/// store offers are created by hand, so nothing is promised before the code exists.
String welcomeDraft(String name) {
  final first = name.trim().split(RegExp(r'\s+')).first;
  return 'Hi $first,\n\nWelcome to the Outlay Creator Program, we\'re glad to have you.\n\n'
      'Your personal code is [YOUR CODE]. Share it with your audience for their discount, and you earn a revenue share on subscribers who join with it.\n\n'
      'If you have any questions, just reply to this message.\n\nThe Outlay team';
}
