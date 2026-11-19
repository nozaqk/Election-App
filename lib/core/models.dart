/// Data models mirroring the backend JSON API.
///
/// Parsing is deliberately defensive: ids, ballot numbers and levels may be
/// encoded as strings or numbers depending on the backend build, so every
/// scalar goes through [str]/[intOf] instead of a hard cast.

String str(dynamic v) => v == null ? '' : v.toString();

int intOf(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

bool boolOf(dynamic v) => v == true;

DateTime? dateOf(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString());

List<T> listOf<T>(dynamic v, T Function(Map<String, dynamic>) parse) {
  if (v is! List) return <T>[];
  return v
      .whereType<Map>()
      .map((e) => parse(e.cast<String, dynamic>()))
      .toList();
}

/// Signed-in student profile (`GET /auth/student/me`).
class Me {
  final String indexNumber;
  final String fullName;
  final String department;
  final String programme;
  final String level;
  final String? semester;
  final String officialLevel;

  const Me({
    required this.indexNumber,
    required this.fullName,
    required this.department,
    required this.programme,
    required this.level,
    required this.semester,
    required this.officialLevel,
  });

  factory Me.fromJson(Map<String, dynamic> json) => Me(
        indexNumber: str(json['indexNumber']),
        fullName: str(json['fullName']),
        department: str(json['department']),
        programme: str(json['programme']),
        level: str(json['level']),
        semester: json['semester'] == null ? null : str(json['semester']),
        officialLevel: str(json['officialLevel']),
      );
}

/// Headline/body pair the backend attaches to an election or the overview.
class UiText {
  final String state;
  final String headline;
  final String body;

  const UiText({required this.state, required this.headline, required this.body});

  factory UiText.fromJson(Map<String, dynamic> json) => UiText(
        state: str(json['state']),
        headline: str(json['headline']),
        body: str(json['body']),
      );
}

/// Election summary row (`GET /student/overview` → `elections[]`).
class ElectionSummary {
  final String id;
  final String title;
  final String description;
  final String status;
  final DateTime? startAt;
  final DateTime? endAt;
  final String startLabel;
  final String endLabel;
  final bool requirePresence;
  final bool hasVoted;
  final bool canVote;
  final UiText ui;

  const ElectionSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.startAt,
    required this.endAt,
    required this.startLabel,
    required this.endLabel,
    required this.requirePresence,
    required this.hasVoted,
    required this.canVote,
    required this.ui,
  });

  factory ElectionSummary.fromJson(Map<String, dynamic> json) => ElectionSummary(
        id: str(json['id']),
        title: str(json['title']),
        description: str(json['description']),
        status: str(json['status']),
        startAt: dateOf(json['startAt']),
        endAt: dateOf(json['endAt']),
        startLabel: str(json['startLabel']),
        endLabel: str(json['endLabel']),
        requirePresence: boolOf(json['requirePresence']),
        hasVoted: boolOf(json['hasVoted']),
        canVote: boolOf(json['canVote']),
        ui: json['ui'] is Map
            ? UiText.fromJson((json['ui'] as Map).cast<String, dynamic>())
            : const UiText(state: '', headline: '', body: ''),
      );
}

/// Overview feed (`GET /student/overview`).
class Overview {
  final DateTime? serverTime;
  final List<ElectionSummary> elections;
  final UiText? empty;

  const Overview({required this.serverTime, required this.elections, required this.empty});

  factory Overview.fromJson(Map<String, dynamic> json) => Overview(
        serverTime: dateOf(json['serverTime']),
        elections: listOf(json['elections'], ElectionSummary.fromJson),
        empty: json['empty'] is Map
            ? UiText.fromJson((json['empty'] as Map).cast<String, dynamic>())
            : null,
      );
}

/// A candidate on the ballot.
class Candidate {
  final String id;
  final String name;
  final String number;
  final String? photoUrl;
  final String manifesto;
  final String? department;
  final String? programme;

  const Candidate({
    required this.id,
    required this.name,
    required this.number,
    required this.photoUrl,
    required this.manifesto,
    required this.department,
    required this.programme,
  });

  factory Candidate.fromJson(Map<String, dynamic> json) => Candidate(
        id: str(json['id']),
        name: str(json['name']),
        number: str(json['number']),
        photoUrl: json['photoUrl'] == null ? null : str(json['photoUrl']),
        manifesto: str(json['manifesto']),
        department: json['department'] == null ? null : str(json['department']),
        programme: json['programme'] == null ? null : str(json['programme']),
      );
}

/// One office on the ballot.
class Position {
  final String id;
  final String title;
  final int maxSelections;
  final bool allowAbstain;
  final List<Candidate> candidates;

  const Position({
    required this.id,
    required this.title,
    required this.maxSelections,
    required this.allowAbstain,
    required this.candidates,
  });

  factory Position.fromJson(Map<String, dynamic> json) => Position(
        id: str(json['id']),
        title: str(json['title']),
        maxSelections: intOf(json['maxSelections']),
        allowAbstain: boolOf(json['allowAbstain']),
        candidates: listOf(json['candidates'], Candidate.fromJson),
      );
}

/// Election detail (`GET /student/elections/{id}`).
class ElectionDetail {
  final ElectionSummary summary;
  final List<Position> positions;
  final DateTime? serverTime;

  const ElectionDetail({
    required this.summary,
    required this.positions,
    required this.serverTime,
  });

  String get id => summary.id;
  String get title => summary.title;
  String get description => summary.description;
  String get status => summary.status;
  DateTime? get startAt => summary.startAt;
  DateTime? get endAt => summary.endAt;
  String get startLabel => summary.startLabel;
  String get endLabel => summary.endLabel;
  bool get requirePresence => summary.requirePresence;
  bool get hasVoted => summary.hasVoted;
  bool get canVote => summary.canVote;
  UiText get ui => summary.ui;

  factory ElectionDetail.fromJson(Map<String, dynamic> json) => ElectionDetail(
        summary: ElectionSummary.fromJson(json),
        positions: listOf(json['positions'], Position.fromJson),
        serverTime: dateOf(json['serverTime']),
      );
}

/// Presence authorisation (`POST /student/elections/{id}/presence`).
class PresenceGrant {
  final String authorization;
  final DateTime? expiresAt;

  const PresenceGrant({required this.authorization, required this.expiresAt});

  factory PresenceGrant.fromJson(Map<String, dynamic> json) => PresenceGrant(
        authorization: str(json['authorization']),
        expiresAt: dateOf(json['expiresAt']),
      );
}

/// One candidate's result line.
class CandidateResult {
  final String candidateId;
  final String name;
  final String number;
  final String? photoUrl;
  final int votes;
  final bool winner;
  final bool tied;

  const CandidateResult({
    required this.candidateId,
    required this.name,
    required this.number,
    required this.photoUrl,
    required this.votes,
    required this.winner,
    required this.tied,
  });

  factory CandidateResult.fromJson(Map<String, dynamic> json) => CandidateResult(
        candidateId: str(json['candidateId']),
        name: str(json['name']),
        number: str(json['number']),
        photoUrl: json['photoUrl'] == null ? null : str(json['photoUrl']),
        votes: intOf(json['votes']),
        winner: boolOf(json['winner']),
        tied: boolOf(json['tied']),
      );
}

/// Results for one position.
class PositionResult {
  final String positionId;
  final String title;
  final int seats;
  final int abstained;
  final int totalVotes;
  final bool tie;
  final bool runoffRequired;
  final List<CandidateResult> candidates;

  const PositionResult({
    required this.positionId,
    required this.title,
    required this.seats,
    required this.abstained,
    required this.totalVotes,
    required this.tie,
    required this.runoffRequired,
    required this.candidates,
  });

  factory PositionResult.fromJson(Map<String, dynamic> json) => PositionResult(
        positionId: str(json['positionId']),
        title: str(json['title']),
        seats: intOf(json['seats']),
        abstained: intOf(json['abstained']),
        totalVotes: intOf(json['totalVotes']),
        tie: boolOf(json['tie']),
        runoffRequired: boolOf(json['runoffRequired']),
        candidates: listOf(json['candidates'], CandidateResult.fromJson),
      );
}

/// Published results (`GET /student/elections/{id}/results`).
class Results {
  final String publishedLabel;
  final dynamic turnout;
  final List<PositionResult> results;

  const Results({
    required this.publishedLabel,
    required this.turnout,
    required this.results,
  });

  factory Results.fromJson(Map<String, dynamic> json) => Results(
        publishedLabel: str(json['publishedLabel']),
        turnout: json['turnout'],
        results: listOf(json['results'], PositionResult.fromJson),
      );

  /// Human-readable turnout line, tolerant of the backend's exact shape.
  String get turnoutLabel {
    final t = turnout;
    if (t is Map) {
      final m = t.cast<String, dynamic>();
      final cast = m['votes'] ?? m['cast'] ?? m['count'];
      final total = m['eligible'] ?? m['registered'] ?? m['total'];
      if (cast != null && total != null) return '$cast of $total voted';
      if (cast != null) return '$cast votes cast';
      return m.values.map(str).join(' · ');
    }
    if (t is num) return '${(t * 100).toStringAsFixed(0)}% turnout';
    return str(t);
  }
}

/// Election statuses the backend can report.
class ElectionStatus {
  static const String active = 'ACTIVE';
  static const String paused = 'PAUSED';
  static const String scheduled = 'SCHEDULED';
  static const String ended = 'ENDED';
  static const String counting = 'COUNTING';
  static const String verified = 'VERIFIED';
  static const String finalized = 'FINALIZED';
  static const String published = 'PUBLISHED';
  static const String deactivated = 'DEACTIVATED';
}

/// Sort rank used to surface the most actionable elections first.
int statusRank(String status) {
  switch (status) {
    case ElectionStatus.active:
      return 0;
    case ElectionStatus.paused:
      return 1;
    case ElectionStatus.scheduled:
      return 2;
    case ElectionStatus.ended:
    case ElectionStatus.counting:
    case ElectionStatus.verified:
    case ElectionStatus.finalized:
      return 3;
    case ElectionStatus.published:
      return 4;
    case ElectionStatus.deactivated:
      return 5;
    default:
      return 9;
  }
}

/// Returns [items] sorted by election importance (most urgent first).
List<ElectionSummary> byImportance(List<ElectionSummary> items) {
  final sorted = items.toList()
    ..sort((a, b) => statusRank(a.status).compareTo(statusRank(b.status)));
  return sorted;
}
