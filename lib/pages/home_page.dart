part of '../main.dart';

class HazukiHomePage extends StatefulWidget {
  const HazukiHomePage({
    super.key,
    this.initialTabIndex = 0,
    required this.appearanceSettings,
    required this.onAppearanceChanged,
    required this.locale,
    required this.onLocaleChanged,
    this.refreshTick = 0,
  });

  final int initialTabIndex;
  final AppearanceSettingsData appearanceSettings;
  final Future<void> Function(AppearanceSettingsData next) onAppearanceChanged;
  final Locale? locale;
  final Future<void> Function(Locale? locale) onLocaleChanged;
  final int refreshTick;

  @override
  State<HazukiHomePage> createState() => _HazukiHomePageState();
}

class _HazukiHomePageState extends State<HazukiHomePage> {
  static const _firstUseDateKey = 'app_first_use_date';
  static const _mediaChannel = MethodChannel('hazuki.comics/media');

  late int _currentIndex;
  String _username = '';
  String? _avatarUrl;
  String _firstUseText = '';
  int _authVersion = 0;
  DateTime? _lastBackPressedAt;
  double _discoverSearchMorphProgress = 0;
  bool _autoCheckInEnabled = false;
  bool _didAttemptStartupCheckIn = false;
  bool _checkInBusy = false;
  bool _checkedInToday = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<_FavoritePageState> _favoritePageKey =
      GlobalKey<_FavoritePageState>();
  FavoriteAppBarActionsState _favoriteAppBarActions =
      const FavoriteAppBarActionsState(
        showSort: false,
        showCreateFolder: false,
        currentSortOrder: 'mr',
      );

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex.clamp(0, 1);
    unawaited(_syncUserProfile());
    unawaited(_loadFirstUseText());
    unawaited(_loadOtherSettings());
    if (HazukiSourceService.instance.isLogged) {
      unawaited(HazukiSourceService.instance.warmUpFavoritesDebugInfo());
    }
  }

  @override
  void didUpdateWidget(covariant HazukiHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLocaleCode = oldWidget.locale?.languageCode;
    final newLocaleCode = widget.locale?.languageCode;
    if (oldLocaleCode != newLocaleCode) {
      unawaited(_loadFirstUseText());
      unawaited(_syncUserProfile());
    }
    if (oldWidget.refreshTick != widget.refreshTick) {
      unawaited(_syncUserProfile());
      unawaited(_loadOtherSettings());
    }
  }

  Future<void> _syncUserProfile() async {
    if (!HazukiSourceService.instance.isInitialized) {
      if (!mounted) {
        return;
      }
      setState(() {
        _username = l10n(context).homeGuestUser;
        _avatarUrl = null;
      });
      return;
    }

    if (!mounted) {
      return;
    }
    final strings = l10n(context);
    final username =
        HazukiSourceService.instance.currentAccount ?? strings.homeGuestUser;
    String? avatar;
    if (HazukiSourceService.instance.isLogged) {
      try {
        avatar = await HazukiSourceService.instance.loadCurrentAvatarUrl();
      } catch (_) {
        avatar = null;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _username = username;
      _avatarUrl = avatar;
    });
    unawaited(_refreshCheckInState());
  }

  Future<void> _loadFirstUseText() async {
    final prefs = await SharedPreferences.getInstance();
    var firstUseRaw = prefs.getString(_firstUseDateKey);

    if (firstUseRaw == null || firstUseRaw.isEmpty) {
      firstUseRaw = DateTime.now().toIso8601String();
      await prefs.setString(_firstUseDateKey, firstUseRaw);
    }

    if (!mounted) {
      return;
    }
    final strings = l10n(context);
    final firstUse = DateTime.tryParse(firstUseRaw)?.toLocal();
    final text = firstUse == null
        ? strings.homeFirstUseUnknown
        : strings.homeFirstUseFormatted(
            '${firstUse.year}-${firstUse.month.toString().padLeft(2, '0')}-${firstUse.day.toString().padLeft(2, '0')}',
          );
    setState(() {
      _firstUseText = text;
    });
  }

  Future<void> _loadOtherSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_autoCheckInEnabledKey) ?? false;
    if (!mounted) {
      return;
    }
    setState(() {
      _autoCheckInEnabled = enabled;
    });
    if (enabled) {
      unawaited(_maybeAutoCheckInOnStartup());
    }
  }

  Future<void> _refreshCheckInState() async {
    if (!HazukiSourceService.instance.isLogged) {
      if (!mounted) {
        return;
      }
      setState(() {
        _checkedInToday = false;
      });
      return;
    }

    try {
      final checked = await HazukiSourceService.instance
          .isDailyCheckInCompletedToday();
      if (!mounted) {
        return;
      }
      setState(() {
        _checkedInToday = checked;
      });
    } catch (_) {}
  }

  Future<void> _maybeAutoCheckInOnStartup() async {
    if (_didAttemptStartupCheckIn) {
      return;
    }
    _didAttemptStartupCheckIn = true;

    try {
      await HazukiSourceService.instance.ensureInitialized();
    } catch (_) {
      return;
    }

    if (!mounted ||
        !_autoCheckInEnabled ||
        !HazukiSourceService.instance.isLogged ||
        _checkInBusy) {
      return;
    }

    await _performCheckIn(triggeredAutomatically: true);
  }

  Future<void> _performCheckIn({required bool triggeredAutomatically}) async {
    if (_checkInBusy) {
      return;
    }

    setState(() => _checkInBusy = true);
    try {
      final result = await HazukiSourceService.instance.performDailyCheckIn();
      if (!mounted) {
        return;
      }
      if (result.isSuccess || result.isAlreadyCheckedIn) {
        setState(() {
          _checkedInToday = true;
        });
      }
      final promptMessage = result.isSuccess
          ? l10n(context).homeCheckInSuccess
          : result.isAlreadyCheckedIn
          ? l10n(context).homeCheckInAlreadyDone
          : (result.message?.trim().isNotEmpty ?? false)
          ? result.message!.trim()
          : l10n(context).homeCheckInAlreadyDone;
      unawaited(showHazukiPrompt(context, promptMessage));
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).homeCheckInFailed('$e'),
          isError: true,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _checkInBusy = false);
      }
    }
  }

  Future<T?> _showAnimatedDialog<T>({
    required Widget child,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: l10n(context).dialogBarrierLabel,
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (buildContext, animation, secondaryAnimation) {
        return SafeArea(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Center(
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ),
        );
      },
      transitionBuilder:
          (buildContext, animation, secondaryAnimation, dialogChild) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
                child: dialogChild,
              ),
            );
          },
    );
  }

  Future<bool> _showLogoutConfirmDialog() async {
    final strings = l10n(context);
    final result = await _showAnimatedDialog<bool>(
      child: AlertDialog(
        title: Text(strings.homeLogoutTitle),
        content: Text(strings.homeLogoutContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.homeLogoutTitle),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showLoginDialog() async {
    final accountController = TextEditingController();
    final passwordController = TextEditingController();
    var loading = false;
    var showProfileCard = false;
    var passwordVisible = false;
    String? errorText;
    var profileUsername = _username;
    var profileAvatarUrl = (_avatarUrl ?? '').trim();

    final strings = l10n(context);

    await _showAnimatedDialog<void>(
      barrierDismissible: true,
      child: StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Dialog(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            // AnimatedSize 让弹窗在登录表单↔头像卡片之间平滑伸缩
            child: AnimatedSize(
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: <Widget>[
                      ...previousChildren,
                      // ignore: use_null_aware_elements
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: showProfileCard
                    // 登录成功后：与点击头像完全相同的卡片内容，无额外标题
                    ? Container(
                        key: const ValueKey('profile-card'),
                        width: 320,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildProfileCardContent(
                              avatarUrl: profileAvatarUrl,
                              username: profileUsername,
                              firstUseText: _firstUseText,
                              onLogoutTap: () {
                                Navigator.pop(dialogContext);
                                unawaited(_logout());
                              },
                            ),
                          ],
                        ),
                      )
                    // 登录前：账号密码表单
                    : Container(
                        key: const ValueKey('login-form'),
                        width: 320,
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              strings.homeLoginTitle,
                              style: Theme.of(
                                dialogContext,
                              ).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: accountController,
                              enabled: !loading,
                              decoration: InputDecoration(
                                labelText: strings.homeLoginAccountLabel,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: passwordController,
                              enabled: !loading,
                              obscureText: !passwordVisible,
                              decoration: InputDecoration(
                                labelText: strings.homeLoginPasswordLabel,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  tooltip: passwordVisible
                                      ? strings.homeLoginHidePassword
                                      : strings.homeLoginShowPassword,
                                  onPressed: loading
                                      ? null
                                      : () {
                                          setDialogState(() {
                                            passwordVisible = !passwordVisible;
                                          });
                                        },
                                  icon: Icon(
                                    passwordVisible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                            ),
                            if (errorText != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                errorText!,
                                style: TextStyle(
                                  color: Theme.of(
                                    dialogContext,
                                  ).colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: loading
                                      ? null
                                      : () => Navigator.pop(dialogContext),
                                  child: Text(strings.commonCancel),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: loading
                                      ? null
                                      : () async {
                                          final account = accountController.text
                                              .trim();
                                          final password =
                                              passwordController.text;
                                          if (account.isEmpty ||
                                              password.isEmpty) {
                                            setDialogState(() {
                                              errorText =
                                                  strings.homeLoginEmptyError;
                                            });
                                            return;
                                          }

                                          setDialogState(() {
                                            loading = true;
                                            errorText = null;
                                          });

                                          try {
                                            await HazukiSourceService.instance
                                                .login(
                                                  account: account,
                                                  password: password,
                                                );

                                            if (!mounted ||
                                                !dialogContext.mounted) {
                                              return;
                                            }

                                            setState(() => _authVersion++);
                                            await _syncUserProfile();
                                            await _refreshCheckInState();

                                            // 加载头像 URL 用于卡片展示
                                            var avatar = '';
                                            try {
                                              avatar =
                                                  (await HazukiSourceService
                                                          .instance
                                                          .loadCurrentAvatarUrl())
                                                      ?.trim() ??
                                                  '';
                                            } catch (_) {}

                                            if (!dialogContext.mounted) return;

                                            // 在弹窗内部伸缩过渡到头像卡片
                                            setDialogState(() {
                                              loading = false;
                                              showProfileCard = true;
                                              profileUsername =
                                                  HazukiSourceService
                                                      .instance
                                                      .currentAccount ??
                                                  _username;
                                              profileAvatarUrl = avatar;
                                            });

                                            if (!mounted) {
                                              return;
                                            }
                                            unawaited(
                                              showHazukiPrompt(
                                                context,
                                                strings.homeLoginSuccess,
                                              ),
                                            );
                                          } catch (e) {
                                            setDialogState(() {
                                              loading = false;
                                              errorText = e.toString();
                                            });
                                          }
                                        },
                                  child: loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(strings.homeLoginTitle),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
    accountController.dispose();
    passwordController.dispose();
  }

  Future<void> _logout() async {
    if (!HazukiSourceService.instance.isLogged) {
      return;
    }

    final confirmed = await _showLogoutConfirmDialog();
    if (!confirmed) {
      return;
    }

    await HazukiSourceService.instance.logout();
    if (!mounted) return;
    setState(() {
      _authVersion++;
      _checkedInToday = false;
    });
    unawaited(_syncUserProfile());
    unawaited(showHazukiPrompt(context, l10n(context).homeLoggedOut));
  }

  Future<bool> _showSaveAvatarConfirmDialog() async {
    final strings = l10n(context);
    final result = await _showAnimatedDialog<bool>(
      child: AlertDialog(
        title: Text(strings.homeSaveAvatarTitle),
        content: Text(strings.homeSaveAvatarContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.commonSave),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _saveAvatarToDownloads(String imageUrl) async {
    final normalized = imageUrl.trim();
    if (normalized.isEmpty) {
      return;
    }

    final strings = l10n(context);
    try {
      final bytes = await HazukiSourceService.instance.downloadImageBytes(
        normalized,
      );
      final directory = Directory('/storage/emulated/0/Pictures/Hazuki');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final file = File(
        '${directory.path}/hazuki_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes, flush: true);
      await _mediaChannel.invokeMethod<bool>('scanFile', {'path': file.path});
      if (!mounted) {
        return;
      }
      unawaited(showHazukiPrompt(context, strings.homeAvatarSaved(file.path)));
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          strings.homeAvatarSaveFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Widget _buildProfileCardContent({
    Key? key,
    required String avatarUrl,
    required String username,
    required String firstUseText,
    required VoidCallback onLogoutTap,
  }) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onLongPress: () async {
            unawaited(HapticFeedback.mediumImpact());
            final shouldSave = await _showSaveAvatarConfirmDialog();
            if (shouldSave) {
              unawaited(_saveAvatarToDownloads(avatarUrl));
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: HazukiCachedImage(
              url: avatarUrl,
              width: 220,
              height: 220,
              fit: BoxFit.cover,
              error: Container(
                width: 220,
                height: 220,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.person, size: 72),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(username, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(firstUseText, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(l10n(context).homeLogoutTitle),
          onTap: onLogoutTap,
        ),
      ],
    );
  }

  Future<void> _showAvatarCard() async {
    final avatarUrl = (_avatarUrl ?? '').trim();

    await _showAnimatedDialog<void>(
      child: AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        content: _buildProfileCardContent(
          avatarUrl: avatarUrl,
          username: _username,
          firstUseText: _firstUseText,
          onLogoutTap: () {
            Navigator.pop(context);
            unawaited(_logout());
          },
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final scaffoldState = _scaffoldKey.currentState;
    if (scaffoldState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      return false;
    }

    final now = DateTime.now();
    final last = _lastBackPressedAt;
    if (last == null || now.difference(last) > const Duration(seconds: 2)) {
      _lastBackPressedAt = now;
      if (mounted) {
        unawaited(
          showHazukiPrompt(context, l10n(context).homePressBackAgainToExit),
        );
      }
      return false;
    }
    return true;
  }

  void _handleDiscoverSearchMorphProgressChanged(double progress) {
    final next = progress.clamp(0.0, 1.0);
    if ((next - _discoverSearchMorphProgress).abs() < 0.001) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _discoverSearchMorphProgress = next;
    });
  }

  void _openSearchFromAppBar() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SearchPage()));
  }

  Widget _buildDiscoverAppBarSearchAction() {
    final showCollapsedSearch =
        _currentIndex == 0 && _discoverSearchMorphProgress >= 0.96;
    return HeroMode(
      enabled: showCollapsedSearch,
      child: Hero(
        tag: _discoverSearchHeroTag,
        child: ClipRect(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: showCollapsedSearch ? 180 : 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedSlide(
                offset: showCollapsedSearch
                    ? Offset.zero
                    : const Offset(-0.08, 0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedScale(
                  scale: showCollapsedSearch ? 1 : 0.94,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: showCollapsedSearch ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: IgnorePointer(
                      ignoring: !showCollapsedSearch,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _openSearchFromAppBar,
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                size: 18,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n(context).homeSearchHint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleFavoriteAppBarActionsChanged(FavoriteAppBarActionsState state) {
    if (state == _favoriteAppBarActions || !mounted) {
      return;
    }
    setState(() {
      _favoriteAppBarActions = state;
    });
  }

  Future<void> _onFavoriteSortSelected(String order) async {
    await _favoritePageKey.currentState?._changeSortOrder(order);
  }

  Future<void> _onFavoriteCreateFolderPressed() async {
    await _favoritePageKey.currentState?._createFolder();
  }

  @override
  Widget build(BuildContext context) {
    final isLogged = HazukiSourceService.instance.isLogged;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(
          _onWillPop().then((shouldPop) {
            if (shouldPop && context.mounted) {
              Navigator.of(context).pop();
            }
          }),
        );
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: hazukiFrostedAppBar(
          context: context,
          title: const Text('Hazuki'),
          actions: [
            if (_currentIndex == 1 && _favoriteAppBarActions.showSort)
              PopupMenuButton<String>(
                tooltip: l10n(context).homeSortTooltip,
                initialValue: _favoriteAppBarActions.currentSortOrder,
                onSelected: _onFavoriteSortSelected,
                itemBuilder: (context) => [
                  CheckedPopupMenuItem<String>(
                    value: 'mr',
                    checked: _favoriteAppBarActions.currentSortOrder == 'mr',
                    child: Text(l10n(context).homeFavoriteSortByFavoriteTime),
                  ),
                  CheckedPopupMenuItem<String>(
                    value: 'mp',
                    checked: _favoriteAppBarActions.currentSortOrder == 'mp',
                    child: Text(l10n(context).homeFavoriteSortByUpdateTime),
                  ),
                ],
                icon: const Icon(Icons.sort_rounded),
              ),
            if (_currentIndex == 1 && _favoriteAppBarActions.showCreateFolder)
              IconButton(
                tooltip: l10n(context).homeCreateFavoriteFolder,
                onPressed: _onFavoriteCreateFolderPressed,
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
            _buildDiscoverAppBarSearchAction(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: _currentIndex == 0 && _discoverSearchMorphProgress >= 0.96
                  ? 12
                  : 0,
            ),
          ],
        ),
        drawer: Drawer(
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                InkWell(
                  onTap:
                      HazukiSourceService
                              .instance
                              .sourceMeta
                              ?.supportsAccount ==
                          true
                      ? () {
                          if (isLogged) {
                            _showAvatarCard();
                          } else {
                            _showLoginDialog();
                          }
                        }
                      : null,
                  borderRadius: BorderRadius.circular(40),
                  child: (!isLogged && (_avatarUrl ?? '').trim().isEmpty)
                      ? const CircleAvatar(
                          radius: 36,
                          backgroundImage: AssetImage(
                            'assets/avatars/20260307_220809.jpg',
                          ),
                        )
                      : HazukiCachedCircleAvatar(
                          radius: 36,
                          url: _avatarUrl ?? '',
                          fallbackIcon: const Icon(Icons.person, size: 36),
                          ignoreNoImageMode: true,
                        ),
                ),
                const SizedBox(height: 12),
                Text(_username, style: Theme.of(context).textTheme.titleMedium),
                if (isLogged && !_autoCheckInEnabled) ...[
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1).animate(
                          animation,
                        ),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: FilledButton.icon(
                      key: ValueKey(
                        'checkin-${_checkInBusy ? 'busy' : _checkedInToday ? 'done' : 'idle'}',
                      ),
                      onPressed: (_checkInBusy || _checkedInToday)
                          ? null
                          : () => _performCheckIn(
                              triggeredAutomatically: false,
                            ),
                      icon: _checkInBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _checkedInToday
                                  ? Icons.check_circle_outline
                                  : Icons.event_available_outlined,
                            ),
                      label: Text(
                        _checkInBusy
                            ? l10n(context).homeCheckInInProgress
                            : _checkedInToday
                            ? l10n(context).homeCheckInDone
                            : l10n(context).homeCheckInAction,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: Text(l10n(context).homeMenuHistory),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const HistoryPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(l10n(context).homeMenuCategories),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TagCategoryPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.leaderboard_outlined),
                  title: Text(l10n(context).homeMenuRanking),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RankingPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: Text(l10n(context).homeMenuDownloads),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DownloadsPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(l10n(context).settingsTitle),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SettingsPage(
                          appearanceSettings: widget.appearanceSettings,
                          onAppearanceChanged: widget.onAppearanceChanged,
                          locale: widget.locale,
                          onLocaleChanged: widget.onLocaleChanged,
                        ),
                      ),
                    );
                    if (!mounted) {
                      return;
                    }
                    await _loadOtherSettings();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.alt_route_outlined),
                  title: Text(l10n(context).homeMenuLines),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LineSettingsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: HeroMode(
                enabled: _currentIndex == 0,
                child: IgnorePointer(
                  ignoring: _currentIndex != 0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    offset: _currentIndex == 0
                        ? Offset.zero
                        : const Offset(-0.04, 0),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      opacity: _currentIndex == 0 ? 1 : 0,
                      child: DiscoverPage(
                        onSearchMorphProgressChanged:
                            _handleDiscoverSearchMorphProgressChanged,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: HeroMode(
                enabled: _currentIndex == 1,
                child: IgnorePointer(
                  ignoring: _currentIndex != 1,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    offset: _currentIndex == 1
                        ? Offset.zero
                        : const Offset(0.04, 0),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      opacity: _currentIndex == 1 ? 1 : 0,
                      child: FavoritePage(
                        key: _favoritePageKey,
                        authVersion: _authVersion,
                        onAppBarActionsChanged:
                            _handleFavoriteAppBarActionsChanged,
                        onRequestLogin: _showLoginDialog,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            if (_currentIndex != index) {
              unawaited(HapticFeedback.lightImpact());
            }
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.explore_outlined),
              selectedIcon: const Icon(Icons.explore),
              label: l10n(context).homeTabDiscover,
            ),
            NavigationDestination(
              icon: const Icon(Icons.favorite_border),
              selectedIcon: const Icon(Icons.favorite),
              label: l10n(context).homeTabFavorite,
            ),
          ],
        ),
      ),
    );
  }
}

String _comicCoverHeroTag(ExploreComic comic, {String? salt}) {
  final key = comic.id.isEmpty ? comic.title : comic.id;
  if (salt == null || salt.isEmpty) {
    return 'comic-cover-$key';
  }
  return 'comic-cover-$key-$salt';
}
