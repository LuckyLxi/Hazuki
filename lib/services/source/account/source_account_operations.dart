import '../models/source_task.dart';
import '../models/source_contract_models.dart';
import 'account_session_capability.dart';
import 'source_daily_check_in_capability.dart';
import 'source_login_interaction.dart';

/// Account and check-in operations consumed by account-facing gateways.
class SourceAccountOperations implements SourceInteractiveAccountGateway {
  const SourceAccountOperations({
    required SourceAccountSessionCapability accountSession,
    required SourceDailyCheckInCapability dailyCheckIn,
  }) : _accountSession = accountSession,
       _dailyCheckIn = dailyCheckIn;

  final SourceAccountSessionCapability _accountSession;
  final SourceDailyCheckInCapability _dailyCheckIn;

  @override
  void cancelPendingLogin() =>
      _accountSession.interactive?.cancelPendingLogin();

  @override
  Future<List<SourceLoginMethod>> loadLoginMethods({
    SourceTaskOrigin? taskOrigin,
  }) =>
      _accountSession.interactive?.loadLoginMethods(taskOrigin: taskOrigin) ??
      Future.value(const []);
  @override
  Future<void> loginInteractive({
    required String account,
    required String password,
    required String method,
    required SourceLoginPresenter present,
    required SourceLoginCancellation cancellation,
    SourceTaskOrigin? taskOrigin,
  }) => _accountSession.interactive!.loginInteractive(
    account: account,
    password: password,
    method: method,
    present: present,
    cancellation: cancellation,
    taskOrigin: taskOrigin,
  );

  bool get isLogged => _accountSession.isLogged;
  String? get currentAccount => _accountSession.currentAccount;
  String? get cachedAvatarUrl => _accountSession.cachedAvatarUrl;

  bool isLoggedForSource(String sourceKey) =>
      _accountSession.isLoggedForSource(sourceKey);

  String? currentAccountForSource(String sourceKey) =>
      _accountSession.currentAccountForSource(sourceKey);

  Future<void> login({
    required String account,
    required String password,
    SourceTaskOrigin? taskOrigin,
  }) => _accountSession.login(
    account: account,
    password: password,
    taskOrigin: taskOrigin,
  );

  Future<void> logout({SourceTaskOrigin? taskOrigin}) =>
      _accountSession.logout(taskOrigin: taskOrigin);

  Future<String?> loadCurrentAvatarUrl({SourceTaskOrigin? taskOrigin}) =>
      _accountSession.loadCurrentAvatarUrl(taskOrigin: taskOrigin);

  Future<bool> isDailyCheckInCompletedToday({SourceTaskOrigin? taskOrigin}) =>
      _dailyCheckIn.isCompletedToday(taskOrigin: taskOrigin);

  Future<DailyCheckInResult> performDailyCheckIn({
    SourceTaskOrigin? taskOrigin,
  }) => _dailyCheckIn.perform(taskOrigin: taskOrigin);
}
