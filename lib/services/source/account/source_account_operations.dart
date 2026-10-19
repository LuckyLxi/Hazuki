import '../models/source_contract_models.dart';
import 'account_session_capability.dart';
import 'source_daily_check_in_capability.dart';
import 'source_login_interaction.dart';

/// Account and check-in operations consumed by account-facing gateways.
abstract interface class SourceAccountOperations {
  bool get isLogged;
  String? get currentAccount;
  String? get cachedAvatarUrl;

  bool isLoggedForSource(String sourceKey);
  String? currentAccountForSource(String sourceKey);
  Future<void> login({required String account, required String password});
  Future<void> logout();
  Future<String?> loadCurrentAvatarUrl();
  Future<bool> isDailyCheckInCompletedToday();
  Future<DailyCheckInResult> performDailyCheckIn();
}

class SourceAccountOperationService
    implements SourceAccountOperations, SourceInteractiveAccountGateway {
  const SourceAccountOperationService({
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
  Future<List<SourceLoginMethod>> loadLoginMethods() =>
      _accountSession.interactive?.loadLoginMethods() ?? Future.value(const []);
  @override
  Future<void> loginInteractive({
    required String account,
    required String password,
    required String method,
    required SourceLoginPresenter present,
    required SourceLoginCancellation cancellation,
  }) => _accountSession.interactive!.loginInteractive(
    account: account,
    password: password,
    method: method,
    present: present,
    cancellation: cancellation,
  );

  @override
  bool get isLogged => _accountSession.isLogged;
  @override
  String? get currentAccount => _accountSession.currentAccount;
  @override
  String? get cachedAvatarUrl => _accountSession.cachedAvatarUrl;

  @override
  bool isLoggedForSource(String sourceKey) =>
      _accountSession.isLoggedForSource(sourceKey);

  @override
  String? currentAccountForSource(String sourceKey) =>
      _accountSession.currentAccountForSource(sourceKey);

  @override
  Future<void> login({required String account, required String password}) =>
      _accountSession.login(account: account, password: password);

  @override
  Future<void> logout() => _accountSession.logout();

  @override
  Future<String?> loadCurrentAvatarUrl() =>
      _accountSession.loadCurrentAvatarUrl();

  @override
  Future<bool> isDailyCheckInCompletedToday() =>
      _dailyCheckIn.isCompletedToday();

  @override
  Future<DailyCheckInResult> performDailyCheckIn() => _dailyCheckIn.perform();
}
