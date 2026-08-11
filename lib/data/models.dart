/// Dart twins of the server's `ApiResponses` records, one class per record and
/// in the same order, so the two sides can be read side by side.
///
/// Money arrives as a plain JSON number with the project's currency label
/// alongside it; formatting is this client's job, exactly as it is the web
/// app's.
library;

// ═══════════════════════════════════════════════════════════════════════════
//  Enums
// ═══════════════════════════════════════════════════════════════════════════

enum Role {
  admin,
  user;

  static Role parse(String? raw) => raw == 'ADMIN' ? Role.admin : Role.user;

  String get wire => this == Role.admin ? 'ADMIN' : 'USER';

  String get label => this == Role.admin ? 'Administrator' : 'User';
}

/// What a member may do on one project. Ordered weakest to strongest.
enum AccessLevel {
  viewer,
  editor,
  owner;

  static AccessLevel? parse(String? raw) => switch (raw) {
        'OWNER' => AccessLevel.owner,
        'EDITOR' => AccessLevel.editor,
        'VIEWER' => AccessLevel.viewer,
        _ => null,
      };

  String get wire => switch (this) {
        AccessLevel.owner => 'OWNER',
        AccessLevel.editor => 'EDITOR',
        AccessLevel.viewer => 'VIEWER',
      };

  bool get canEdit => this == AccessLevel.editor || this == AccessLevel.owner;

  bool get canAdminister => this == AccessLevel.owner;
}

enum StageStatus {
  notStarted,
  inProgress,
  complete;

  static StageStatus parse(String? raw) => switch (raw) {
        'IN_PROGRESS' => StageStatus.inProgress,
        'COMPLETE' => StageStatus.complete,
        _ => StageStatus.notStarted,
      };

  String get wire => switch (this) {
        StageStatus.notStarted => 'NOT_STARTED',
        StageStatus.inProgress => 'IN_PROGRESS',
        StageStatus.complete => 'COMPLETE',
      };

  String get label => switch (this) {
        StageStatus.notStarted => 'Not started',
        StageStatus.inProgress => 'In progress',
        StageStatus.complete => 'Complete',
      };
}

/// Decides which expense heads a stage suggests.
enum StageKind {
  plot,
  build;

  static StageKind parse(String? raw) => raw == 'PLOT' ? StageKind.plot : StageKind.build;

  String get wire => this == StageKind.plot ? 'PLOT' : 'BUILD';
}

enum WeightUnit {
  kg,
  ton;

  static WeightUnit? parse(String? raw) => switch (raw) {
        'KG' => WeightUnit.kg,
        'TON' => WeightUnit.ton,
        _ => null,
      };

  String get wire => this == WeightUnit.ton ? 'TON' : 'KG';

  String get label => this == WeightUnit.ton ? 'ton' : 'kg';
}

/// Where an expense head is offered.
enum HeadScope {
  build,
  plot,
  all;

  static HeadScope parse(String? raw) => switch (raw) {
        'PLOT' => HeadScope.plot,
        'BUILD' => HeadScope.build,
        _ => HeadScope.all,
      };

  String get wire => switch (this) {
        HeadScope.plot => 'PLOT',
        HeadScope.build => 'BUILD',
        HeadScope.all => 'ALL',
      };

  String get label => switch (this) {
        HeadScope.plot => 'Suggested on plot stages',
        HeadScope.build => 'Suggested on construction stages',
        HeadScope.all => 'Suggested everywhere',
      };
}

// ═══════════════════════════════════════════════════════════════════════════
//  Parsing helpers
// ═══════════════════════════════════════════════════════════════════════════

Map<String, dynamic> _map(dynamic json) => (json as Map).cast<String, dynamic>();

String _str(dynamic value) => value == null ? '' : '$value';

String? _strOrNull(dynamic value) {
  if (value == null) return null;
  final text = '$value';
  return text.isEmpty ? null : text;
}

num _num(dynamic value) {
  if (value is num) return value;
  return num.tryParse('$value') ?? 0;
}

num? _numOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse('$value');
}

int _int(dynamic value) => _num(value).toInt();

bool _bool(dynamic value) => value == true;

DateTime? _instant(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse('$value');
}

List<T> _list<T>(dynamic value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) return const [];
  return value.map((item) => parse(_map(item))).toList(growable: false);
}

List<String> _strings(dynamic value) {
  if (value is! List) return const [];
  return value.map((item) => '$item').toList(growable: false);
}

// ═══════════════════════════════════════════════════════════════════════════
//  Views
// ═══════════════════════════════════════════════════════════════════════════

class UserView {
  const UserView({
    required this.id,
    required this.name,
    required this.email,
    required this.initials,
    required this.role,
    required this.active,
    required this.mustChangePassword,
    this.createdAt,
    this.lastLoginAt,
  });

  final String id;
  final String name;
  final String email;
  final String initials;
  final Role role;
  final bool active;
  final bool mustChangePassword;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  bool get isAdmin => role == Role.admin;

  factory UserView.fromJson(Map<String, dynamic> json) => UserView(
        id: _str(json['id']),
        name: _str(json['name']),
        email: _str(json['email']),
        initials: _str(json['initials']),
        role: Role.parse(json['role'] as String?),
        // The server omits false booleans (non_null inclusion keeps nulls out,
        // but an absent flag still has to read as false, not true).
        active: json['active'] == null ? true : _bool(json['active']),
        mustChangePassword: _bool(json['mustChangePassword']),
        createdAt: _instant(json['createdAt']),
        lastLoginAt: _instant(json['lastLoginAt']),
      );
}

/// The signed-in user plus whether they still need to set a password.
class SessionView {
  const SessionView({required this.user, required this.mustChangePassword});

  final UserView user;
  final bool mustChangePassword;

  factory SessionView.fromJson(Map<String, dynamic> json) => SessionView(
        user: UserView.fromJson(_map(json['user'])),
        mustChangePassword: _bool(json['mustChangePassword']),
      );
}

/// What `POST /api/auth/token` hands back: the bearer token this app keeps.
class TokenView {
  const TokenView({
    required this.token,
    required this.expiresAt,
    required this.user,
    required this.mustChangePassword,
  });

  final String token;
  final DateTime? expiresAt;
  final UserView user;
  final bool mustChangePassword;

  SessionView get session => SessionView(user: user, mustChangePassword: mustChangePassword);

  factory TokenView.fromJson(Map<String, dynamic> json) => TokenView(
        token: _str(json['token']),
        expiresAt: _instant(json['expiresAt']),
        user: UserView.fromJson(_map(json['user'])),
        mustChangePassword: _bool(json['mustChangePassword']),
      );
}

class MemberView {
  const MemberView({
    required this.userId,
    required this.name,
    required this.email,
    required this.initials,
    required this.access,
    required this.accessLabel,
    required this.owner,
  });

  final String userId;
  final String name;
  final String email;
  final String initials;
  final AccessLevel? access;
  final String accessLabel;
  final bool owner;

  factory MemberView.fromJson(Map<String, dynamic> json) => MemberView(
        userId: _str(json['userId']),
        name: _str(json['name']),
        email: _str(json['email']),
        initials: _str(json['initials']),
        access: AccessLevel.parse(json['access'] as String?),
        accessLabel: _str(json['accessLabel']),
        owner: _bool(json['owner']),
      );
}

class HeadView {
  const HeadView({
    required this.id,
    required this.name,
    required this.scope,
    required this.builtIn,
    required this.inUse,
  });

  final String id;
  final String name;
  final HeadScope scope;
  final bool builtIn;

  /// Heads with expenses filed under them cannot be removed.
  final bool inUse;

  factory HeadView.fromJson(Map<String, dynamic> json) => HeadView(
        id: _str(json['id']),
        name: _str(json['name']),
        scope: HeadScope.parse(json['scope'] as String?),
        builtIn: _bool(json['builtIn']),
        inUse: _bool(json['inUse']),
      );
}

class FileView {
  const FileView({
    required this.id,
    required this.filename,
    required this.contentType,
    required this.size,
    required this.width,
    required this.height,
    this.uploadedByName,
    this.uploadedAt,
  });

  final String id;
  final String filename;
  final String contentType;
  final int size;
  final int width;
  final int height;
  final String? uploadedByName;
  final DateTime? uploadedAt;

  factory FileView.fromJson(Map<String, dynamic> json) => FileView(
        id: _str(json['id']),
        filename: _str(json['filename']),
        contentType: _str(json['contentType']),
        size: _int(json['size']),
        width: _int(json['width']),
        height: _int(json['height']),
        uploadedByName: _strOrNull(json['uploadedByName']),
        uploadedAt: _instant(json['uploadedAt']),
      );
}

/// One dot on the dashboard's stage strip.
class StageDot {
  const StageDot({required this.name, required this.status});

  final String name;
  final StageStatus status;

  factory StageDot.fromJson(Map<String, dynamic> json) => StageDot(
        name: _str(json['name']),
        status: StageStatus.parse(json['status'] as String?),
      );
}

class ProjectCard {
  const ProjectCard({
    required this.id,
    required this.name,
    this.location,
    required this.currency,
    this.plotSizeLabel,
    this.access,
    required this.accessLabel,
    required this.owner,
    required this.oversight,
    required this.total,
    required this.expenseCount,
    required this.stageCount,
    required this.completedStages,
    this.currentStageName,
    required this.dots,
    required this.memberCount,
    this.updatedAt,
    this.ownerName,
  });

  final String id;
  final String name;
  final String? location;
  final String currency;

  /// Rendered tag, e.g. "3.5 Marla"; null when no size is set.
  final String? plotSizeLabel;

  final AccessLevel? access;
  final String accessLabel;
  final bool owner;

  /// Visible to this user only because they administer the installation.
  final bool oversight;

  final num total;
  final int expenseCount;
  final int stageCount;
  final int completedStages;
  final String? currentStageName;
  final List<StageDot> dots;
  final int memberCount;
  final DateTime? updatedAt;
  final String? ownerName;

  factory ProjectCard.fromJson(Map<String, dynamic> json) => ProjectCard(
        id: _str(json['id']),
        name: _str(json['name']),
        location: _strOrNull(json['location']),
        currency: _strOrNull(json['currency']) ?? 'Rs',
        plotSizeLabel: _strOrNull(json['plotSizeLabel']),
        access: AccessLevel.parse(json['access'] as String?),
        accessLabel: _str(json['accessLabel']),
        owner: _bool(json['owner']),
        oversight: _bool(json['oversight']),
        total: _num(json['total']),
        expenseCount: _int(json['expenseCount']),
        stageCount: _int(json['stageCount']),
        completedStages: _int(json['completedStages']),
        currentStageName: _strOrNull(json['currentStageName']),
        dots: _list(json['dots'], StageDot.fromJson),
        memberCount: _int(json['memberCount']),
        updatedAt: _instant(json['updatedAt']),
        ownerName: _strOrNull(json['ownerName']),
      );
}

class DashboardTotals {
  const DashboardTotals({
    required this.portfolioTotal,
    required this.projectCount,
    required this.stagesInProgress,
    required this.expenseCount,
  });

  final num portfolioTotal;
  final int projectCount;
  final int stagesInProgress;
  final int expenseCount;

  factory DashboardTotals.fromJson(Map<String, dynamic> json) => DashboardTotals(
        portfolioTotal: _num(json['portfolioTotal']),
        projectCount: _int(json['projectCount']),
        stagesInProgress: _int(json['stagesInProgress']),
        expenseCount: _int(json['expenseCount']),
      );
}

class DashboardView {
  const DashboardView({required this.user, required this.totals, required this.projects});

  final UserView user;
  final DashboardTotals totals;
  final List<ProjectCard> projects;

  /// True when this reader is an administrator seeing the whole installation.
  bool get overseeing => projects.any((project) => project.oversight);

  /// One label only fits a total when every project counts in the same money.
  String? get sharedCurrency {
    final currencies = projects.map((p) => p.currency).toSet();
    return currencies.length == 1 ? currencies.first : null;
  }

  factory DashboardView.fromJson(Map<String, dynamic> json) => DashboardView(
        user: UserView.fromJson(_map(json['user'])),
        totals: DashboardTotals.fromJson(_map(json['totals'])),
        projects: _list(json['projects'], ProjectCard.fromJson),
      );
}

class StageCard {
  const StageCard({
    required this.id,
    required this.name,
    required this.position,
    required this.kind,
    required this.status,
    required this.statusLabel,
    this.startedOn,
    this.completedOn,
    this.plannedNote,
    required this.total,
    required this.expenseCount,
    required this.sharePercent,
  });

  final String id;
  final String name;
  final int position;
  final StageKind kind;
  final StageStatus status;
  final String statusLabel;
  final String? startedOn;
  final String? completedOn;
  final String? plannedNote;
  final num total;
  final int expenseCount;
  final int sharePercent;

  factory StageCard.fromJson(Map<String, dynamic> json) => StageCard(
        id: _str(json['id']),
        name: _str(json['name']),
        position: _int(json['position']),
        kind: StageKind.parse(json['kind'] as String?),
        status: StageStatus.parse(json['status'] as String?),
        statusLabel: _strOrNull(json['statusLabel']) ??
            StageStatus.parse(json['status'] as String?).label,
        startedOn: _strOrNull(json['startedOn']),
        completedOn: _strOrNull(json['completedOn']),
        plannedNote: _strOrNull(json['plannedNote']),
        total: _num(json['total']),
        expenseCount: _int(json['expenseCount']),
        sharePercent: _int(json['sharePercent']),
      );
}

/// One row of "Where the money went".
class MaterialRow {
  const MaterialRow({
    required this.head,
    required this.total,
    required this.count,
    this.weightKg,
    this.quantitySummary,
    required this.sharePercent,
  });

  final String head;
  final num total;
  final int count;
  final num? weightKg;

  /// Per-unit sums joined together: "250 bags · 18 trolleys".
  final String? quantitySummary;
  final int sharePercent;

  factory MaterialRow.fromJson(Map<String, dynamic> json) => MaterialRow(
        head: _str(json['head']),
        total: _num(json['total']),
        count: _int(json['count']),
        weightKg: _numOrNull(json['weightKg']),
        quantitySummary: _strOrNull(json['quantitySummary']),
        sharePercent: _int(json['sharePercent']),
      );
}

class ProjectView {
  const ProjectView({
    required this.id,
    required this.name,
    this.location,
    required this.currency,
    this.plotSize,
    this.plotSizeUnit,
    this.plotSizeLabel,
    this.startedOn,
    this.createdAt,
    this.updatedAt,
    this.access,
    required this.accessLabel,
    required this.canEdit,
    required this.canAdminister,
    required this.oversight,
    required this.total,
    required this.expenseCount,
    required this.stages,
    required this.members,
    required this.heads,
    required this.materials,
    this.currentStageId,
  });

  final String id;
  final String name;
  final String? location;
  final String currency;

  /// Raw value and unit for the edit form …
  final num? plotSize;
  final String? plotSizeUnit;

  /// … and the rendered tag for display, e.g. "3.5 Marla".
  final String? plotSizeLabel;

  final String? startedOn;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final AccessLevel? access;
  final String accessLabel;
  final bool canEdit;
  final bool canAdminister;

  /// Read-only because the reader administers Bunyad, not because they were
  /// given viewer access.
  final bool oversight;

  final num total;
  final int expenseCount;
  final List<StageCard> stages;
  final List<MemberView> members;
  final List<HeadView> heads;
  final List<MaterialRow> materials;
  final String? currentStageId;

  factory ProjectView.fromJson(Map<String, dynamic> json) => ProjectView(
        id: _str(json['id']),
        name: _str(json['name']),
        location: _strOrNull(json['location']),
        currency: _strOrNull(json['currency']) ?? 'Rs',
        plotSize: _numOrNull(json['plotSize']),
        plotSizeUnit: _strOrNull(json['plotSizeUnit']),
        plotSizeLabel: _strOrNull(json['plotSizeLabel']),
        startedOn: _strOrNull(json['startedOn']),
        createdAt: _instant(json['createdAt']),
        updatedAt: _instant(json['updatedAt']),
        access: AccessLevel.parse(json['access'] as String?),
        accessLabel: _str(json['accessLabel']),
        canEdit: _bool(json['canEdit']),
        canAdminister: _bool(json['canAdminister']),
        oversight: _bool(json['oversight']),
        total: _num(json['total']),
        expenseCount: _int(json['expenseCount']),
        stages: _list(json['stages'], StageCard.fromJson),
        members: _list(json['members'], MemberView.fromJson),
        heads: _list(json['heads'], HeadView.fromJson),
        materials: _list(json['materials'], MaterialRow.fromJson),
        currentStageId: _strOrNull(json['currentStageId']),
      );
}

class ExpenseView {
  const ExpenseView({
    required this.id,
    required this.stageId,
    required this.projectId,
    required this.name,
    required this.head,
    this.quantity,
    this.quantityUnit,
    this.quantityLabel,
    this.weight,
    this.weightUnit,
    this.weightLabel,
    this.vendorName,
    this.vendorContact,
    required this.amount,
    this.expenseDate,
    this.notes,
    required this.files,
    this.createdByUserId,
    this.createdByName,
    this.createdByInitials,
    this.createdAt,
    this.updatedByName,
    this.updatedAt,
    required this.canEdit,
  });

  final String id;
  final String stageId;
  final String projectId;
  final String name;
  final String head;

  final num? quantity;
  final String? quantityUnit;

  /// "84 bags", already grouped by the server.
  final String? quantityLabel;

  final num? weight;
  final WeightUnit? weightUnit;
  final String? weightLabel;

  final String? vendorName;
  final String? vendorContact;

  final num amount;
  final String? expenseDate;
  final String? notes;
  final List<FileView> files;

  final String? createdByUserId;
  final String? createdByName;
  final String? createdByInitials;
  final DateTime? createdAt;
  final String? updatedByName;
  final DateTime? updatedAt;

  final bool canEdit;

  factory ExpenseView.fromJson(Map<String, dynamic> json) => ExpenseView(
        id: _str(json['id']),
        stageId: _str(json['stageId']),
        projectId: _str(json['projectId']),
        name: _str(json['name']),
        head: _str(json['head']),
        quantity: _numOrNull(json['quantity']),
        quantityUnit: _strOrNull(json['quantityUnit']),
        quantityLabel: _strOrNull(json['quantityLabel']),
        weight: _numOrNull(json['weight']),
        weightUnit: WeightUnit.parse(json['weightUnit'] as String?),
        weightLabel: _strOrNull(json['weightLabel']),
        vendorName: _strOrNull(json['vendorName']),
        vendorContact: _strOrNull(json['vendorContact']),
        amount: _num(json['amount']),
        expenseDate: _strOrNull(json['expenseDate']),
        notes: _strOrNull(json['notes']),
        files: _list(json['files'], FileView.fromJson),
        createdByUserId: _strOrNull(json['createdByUserId']),
        createdByName: _strOrNull(json['createdByName']),
        createdByInitials: _strOrNull(json['createdByInitials']),
        createdAt: _instant(json['createdAt']),
        updatedByName: _strOrNull(json['updatedByName']),
        updatedAt: _instant(json['updatedAt']),
        canEdit: _bool(json['canEdit']),
      );
}

class StageView {
  const StageView({
    required this.projectId,
    required this.projectName,
    required this.currency,
    this.access,
    required this.canEdit,
    required this.oversight,
    required this.stage,
    required this.suggestions,
    required this.expenses,
    required this.totalExpenseCount,
    required this.hasMore,
  });

  final String projectId;
  final String projectName;
  final String currency;
  final AccessLevel? access;
  final bool canEdit;
  final bool oversight;
  final StageCard stage;

  /// Head names this stage offers, decided by its kind.
  final List<String> suggestions;

  final List<ExpenseView> expenses;
  final int totalExpenseCount;
  final bool hasMore;

  /// The same view with a longer timeline, for "load older expenses".
  StageView withExpenses(List<ExpenseView> all, bool more) => StageView(
        projectId: projectId,
        projectName: projectName,
        currency: currency,
        access: access,
        canEdit: canEdit,
        oversight: oversight,
        stage: stage,
        suggestions: suggestions,
        expenses: all,
        totalExpenseCount: totalExpenseCount,
        hasMore: more,
      );

  factory StageView.fromJson(Map<String, dynamic> json) => StageView(
        projectId: _str(json['projectId']),
        projectName: _str(json['projectName']),
        currency: _strOrNull(json['currency']) ?? 'Rs',
        access: AccessLevel.parse(json['access'] as String?),
        canEdit: _bool(json['canEdit']),
        oversight: _bool(json['oversight']),
        stage: StageCard.fromJson(_map(json['stage'])),
        suggestions: _strings(json['suggestions']),
        expenses: _list(json['expenses'], ExpenseView.fromJson),
        totalExpenseCount: _int(json['totalExpenseCount']),
        hasMore: _bool(json['hasMore']),
      );
}

/// What the People screen gets back when it issues or resets an account: the
/// password, shown exactly once.
class IssuedCredential {
  const IssuedCredential({this.user, required this.password, required this.generated});

  final UserView? user;
  final String password;
  final bool generated;

  factory IssuedCredential.fromJson(Map<String, dynamic> json) => IssuedCredential(
        user: json['user'] == null ? null : UserView.fromJson(_map(json['user'])),
        password: _str(json['password']),
        generated: _bool(json['generated']),
      );
}
