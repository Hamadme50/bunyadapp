import 'package:dio/dio.dart';

import '../global.dart';
import 'api_client.dart';
import 'models.dart';

/// Every call the app makes, typed. Screens talk to this and never to Dio.
class BunyadRepository {
  BunyadRepository(this.client);

  final ApiClient client;

  Map<String, dynamic> _obj(dynamic json) => (json as Map).cast<String, dynamic>();

  // ── auth ────────────────────────────────────────────────────────────────

  /// Signs in and keeps the long-lived token for every later call.
  Future<SessionView> signIn(String email, String password) async {
    final result = TokenView.fromJson(
      _obj(await client.post(Api.token, {'email': email.trim(), 'password': password})),
    );
    await client.setToken(result.token);
    return result.session;
  }

  /// The session behind the stored token, or a 401 if it is no longer good.
  Future<SessionView> me() async => SessionView.fromJson(_obj(await client.get(Api.me)));

  Future<void> signOut() async {
    try {
      await client.post(Api.logout, const {});
    } on ApiException {
      // Dropping the token locally matters more than the server acknowledging
      // it — a bearer token is stateless, so this call is only politeness.
    }
    await client.clearToken();
  }

  Future<SessionView> changePassword({String? currentPassword, required String newPassword}) async =>
      SessionView.fromJson(_obj(await client.post(Api.password, {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      })));

  // ── dashboard and projects ──────────────────────────────────────────────

  Future<DashboardView> dashboard() async =>
      DashboardView.fromJson(_obj(await client.get(Api.projects)));

  Future<ProjectView> project(String projectId) async =>
      ProjectView.fromJson(_obj(await client.get(Api.project(projectId))));

  Future<ProjectView> createProject({
    required String name,
    String? location,
    num? plotSize,
    String? plotSizeUnit,
    String? startedOn,
    String? currency,
    required List<String> stages,
  }) async =>
      ProjectView.fromJson(_obj(await client.post(Api.projects, {
        'name': name,
        'location': location,
        'plotSize': plotSize,
        'plotSizeUnit': plotSizeUnit,
        'startedOn': startedOn,
        'currency': currency,
        'stages': stages,
      })));

  Future<ProjectView> updateProject(
    String projectId, {
    required String name,
    String? location,
    num? plotSize,
    String? plotSizeUnit,
    required bool clearPlotSize,
    String? startedOn,
    String? currency,
  }) async =>
      ProjectView.fromJson(_obj(await client.patch(Api.project(projectId), {
        'name': name,
        'location': location,
        'plotSize': plotSize,
        'plotSizeUnit': plotSizeUnit,
        'clearPlotSize': clearPlotSize,
        'startedOn': startedOn,
        'currency': currency,
      })));

  Future<void> deleteProject(String projectId) => client.delete(Api.project(projectId));

  // ── sharing ─────────────────────────────────────────────────────────────

  /// [user] takes an email address or an existing user id.
  Future<ProjectView> addMember(String projectId, String user, AccessLevel access) async =>
      ProjectView.fromJson(_obj(await client.post(Api.members(projectId), {
        'user': user,
        'access': access.wire,
      })));

  Future<ProjectView> changeMemberAccess(
          String projectId, String userId, AccessLevel access) async =>
      ProjectView.fromJson(_obj(await client.patch(Api.member(projectId, userId), {
        'access': access.wire,
      })));

  Future<ProjectView> removeMember(String projectId, String userId) async =>
      ProjectView.fromJson(_obj(await client.delete(Api.member(projectId, userId))));

  Future<void> leaveProject(String projectId) => client.post(Api.leave(projectId), const {});

  Future<List<UserView>> searchUsers(String query) async {
    final result = await client.get(Api.userSearch(query));
    if (result is! List) return const [];
    return result.map((item) => UserView.fromJson(_obj(item))).toList();
  }

  // ── expense heads ───────────────────────────────────────────────────────

  Future<ProjectView> addHead(String projectId, String name, {HeadScope scope = HeadScope.all}) async =>
      ProjectView.fromJson(_obj(await client.post(Api.heads(projectId), {
        'name': name,
        'scope': scope.wire,
      })));

  Future<ProjectView> deleteHead(String projectId, String headId) async =>
      ProjectView.fromJson(_obj(await client.delete(Api.head(projectId, headId))));

  // ── stages ──────────────────────────────────────────────────────────────

  Future<StageView> stage(String projectId, String stageId,
      {int offset = 0, int limit = kPageSize}) async {
    final path = '${Api.stage(projectId, stageId)}?offset=$offset&limit=$limit';
    return StageView.fromJson(_obj(await client.get(path)));
  }

  Future<ProjectView> createStage(
    String projectId, {
    required String name,
    required StageKind kind,
    required StageStatus status,
    String? plannedNote,
  }) async =>
      ProjectView.fromJson(_obj(await client.post(Api.stages(projectId), {
        'name': name,
        'kind': kind.wire,
        'status': status.wire,
        'plannedNote': plannedNote,
      })));

  Future<ProjectView> updateStage(
    String projectId,
    String stageId, {
    required String name,
    required StageKind kind,
    required StageStatus status,
    String? startedOn,
    String? completedOn,
    String? plannedNote,
  }) async =>
      ProjectView.fromJson(_obj(await client.patch(Api.stage(projectId, stageId), {
        'name': name,
        'kind': kind.wire,
        'status': status.wire,
        'startedOn': startedOn,
        'completedOn': completedOn,
        'plannedNote': plannedNote,
        // An emptied date box means "clear it", not "leave it alone".
        'clearStartedOn': startedOn == null,
        'clearCompletedOn': completedOn == null,
      })));

  Future<ProjectView> deleteStage(String projectId, String stageId) async =>
      ProjectView.fromJson(_obj(await client.delete(Api.stage(projectId, stageId))));

  Future<ProjectView> reorderStages(String projectId, List<String> ids) async =>
      ProjectView.fromJson(_obj(await client.put(Api.stageOrder(projectId), {'ids': ids})));

  // ── expenses ────────────────────────────────────────────────────────────

  Future<ExpenseView> createExpense(
          String projectId, String stageId, Map<String, dynamic> payload) async =>
      ExpenseView.fromJson(_obj(await client.post(Api.expenses(projectId, stageId), payload)));

  Future<ExpenseView> updateExpense(String expenseId, Map<String, dynamic> payload) async =>
      ExpenseView.fromJson(_obj(await client.patch(Api.expense(expenseId), payload)));

  Future<void> deleteExpense(String expenseId) => client.delete(Api.expense(expenseId));

  Future<ExpenseView> moveExpense(String expenseId, String stageId) async =>
      ExpenseView.fromJson(
          _obj(await client.post(Api.moveExpense(expenseId), {'stageId': stageId})));

  // ── files ───────────────────────────────────────────────────────────────

  Future<FileView> uploadPhoto({
    required String filePath,
    required String filename,
    required String projectId,
    CancelToken? cancelToken,
  }) async =>
      FileView.fromJson(_obj(await client.uploadFile(
        filePath: filePath,
        filename: filename,
        projectId: projectId,
        cancelToken: cancelToken,
      )));

  // ── people ──────────────────────────────────────────────────────────────

  Future<List<UserView>> users() async {
    final result = await client.get(Api.adminUsers);
    if (result is! List) return const [];
    return result.map((item) => UserView.fromJson(_obj(item))).toList();
  }

  /// The password comes back once and is never retrievable again.
  Future<IssuedCredential> createUser({
    required String name,
    required String email,
    String? password,
    required Role role,
  }) async =>
      IssuedCredential.fromJson(_obj(await client.post(Api.adminUsers, {
        'name': name,
        'email': email,
        'password': password,
        'role': role.wire,
      })));

  Future<UserView> updateUser(String id,
          {required String name, required Role role, required bool active}) async =>
      UserView.fromJson(_obj(await client.patch(Api.adminUser(id), {
        'name': name,
        'role': role.wire,
        'active': active,
      })));

  Future<IssuedCredential> resetPassword(String id) async => IssuedCredential.fromJson(
      _obj(await client.post(Api.adminUserPassword(id), const {})));

  Future<void> deleteUser(String id) => client.delete(Api.adminUser(id));
}
