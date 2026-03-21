part of '../main.dart';

class HazukiHomePage extends StatefulWidget {
  const HazukiHomePage({
    super.key,
    this.initialTabIndex = 0,
    required this.appearanceSettings,
    required this.onAppearanceChanged,
  });

  final int initialTabIndex;
  final AppearanceSettingsData appearanceSettings;
  final Future<void> Function(AppearanceSettingsData next) onAppearanceChanged;

  @override
  State<HazukiHomePage> createState() => _HazukiHomePageState();
}

class _HazukiHomePageState extends State<HazukiHomePage> {
  static const _firstUseDateKey = 'app_first_use_date';
  static const _mediaChannel = MethodChannel('hazuki.comics/media');

  late int _currentIndex;
  String _username = '未登录';
  String? _avatarUrl;
  String _firstUseText = '首次使用时间加载中...';
  int _authVersion = 0;
  DateTime? _lastBackPressedAt;
  double _discoverSearchMorphProgress = 0;
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
    if (HazukiSourceService.instance.isLogged) {
      unawaited(HazukiSourceService.instance.warmUpFavoritesDebugInfo());
    }
  }

  Future<void> _syncUserProfile() async {
    try {
      await HazukiSourceService.instance.ensureInitialized();
    } catch (_) {}

    final username = HazukiSourceService.instance.currentAccount ?? '未登录';
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
  }

  Future<void> _loadFirstUseText() async {
    final prefs = await SharedPreferences.getInstance();
    var firstUseRaw = prefs.getString(_firstUseDateKey);

    if (firstUseRaw == null || firstUseRaw.isEmpty) {
      firstUseRaw = DateTime.now().toIso8601String();
      await prefs.setString(_firstUseDateKey, firstUseRaw);
    }

    final firstUse = DateTime.tryParse(firstUseRaw)?.toLocal();
    final text = firstUse == null
        ? '首次使用本应用'
        : "${firstUse.year}-${firstUse.month.toString().padLeft(2, '0')}-${firstUse.day.toString().padLeft(2, '0')} 首次使用";
    if (!mounted) {
      return;
    }
    setState(() {
      _firstUseText = text;
    });
  }

  Future<T?> _showAnimatedDialog<T>({
    required Widget child,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: '对话框',
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
    final result = await _showAnimatedDialog<bool>(
      child: AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出登录'),
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
                              '登录',
                              style: Theme.of(
                                dialogContext,
                              ).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: accountController,
                              enabled: !loading,
                              decoration: const InputDecoration(
                                labelText: '账号',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: passwordController,
                              enabled: !loading,
                              obscureText: !passwordVisible,
                              decoration: InputDecoration(
                                labelText: '密码',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  tooltip: passwordVisible ? '隐藏密码' : '显示密码',
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
                                  child: const Text('取消'),
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
                                              errorText = '账号和密码不能为空';
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
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('登录成功'),
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
                                      : const Text('登录'),
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
    });
    unawaited(_syncUserProfile());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已退出登录')));
  }

  Future<bool> _showSaveAvatarConfirmDialog() async {
    final result = await _showAnimatedDialog<bool>(
      child: AlertDialog(
        title: const Text('保存头像'),
        content: const Text('将当前头像保存到相册吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('头像已保存到 ${file.path}')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('头像保存失败：$e')));
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
          title: const Text('退出登录'),
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
    final now = DateTime.now();
    final last = _lastBackPressedAt;
    if (last == null || now.difference(last) > const Duration(seconds: 2)) {
      _lastBackPressedAt = now;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('再按一次返回退出')));
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
                                  '搜索漫画',
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
        appBar: hazukiFrostedAppBar(
          context: context,
          title: const Text('Hazuki'),
          actions: [
            if (_currentIndex == 1 && _favoriteAppBarActions.showSort)
              PopupMenuButton<String>(
                tooltip: '排序',
                initialValue: _favoriteAppBarActions.currentSortOrder,
                onSelected: _onFavoriteSortSelected,
                itemBuilder: (context) => [
                  CheckedPopupMenuItem<String>(
                    value: 'mr',
                    checked: _favoriteAppBarActions.currentSortOrder == 'mr',
                    child: const Text('收藏时间'),
                  ),
                  CheckedPopupMenuItem<String>(
                    value: 'mp',
                    checked: _favoriteAppBarActions.currentSortOrder == 'mp',
                    child: const Text('更新时间'),
                  ),
                ],
                icon: const Icon(Icons.sort_rounded),
              ),
            if (_currentIndex == 1 && _favoriteAppBarActions.showCreateFolder)
              IconButton(
                tooltip: '新建收藏夹',
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
                const SizedBox(height: 16),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: const Text('历史记录'),
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
                  title: const Text('标签分类'),
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
                  title: const Text('排行榜'),
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
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('设置'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SettingsPage(
                          appearanceSettings: widget.appearanceSettings,
                          onAppearanceChanged: widget.onAppearanceChanged,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.alt_route_outlined),
                  title: const Text('线路'),
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
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: '发现',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: '收藏',
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
