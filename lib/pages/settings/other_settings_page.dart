part of '../../main.dart';

class OtherSettingsPage extends StatefulWidget {
  const OtherSettingsPage({super.key});

  @override
  State<OtherSettingsPage> createState() => _OtherSettingsPageState();
}

class _OtherSettingsPageState extends State<OtherSettingsPage> {
  bool _autoCheckInEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _autoCheckInEnabled = prefs.getBool(_autoCheckInEnabledKey) ?? false;
      _loading = false;
    });
  }

  Future<void> _toggleAutoCheckIn(bool value) async {
    setState(() => _autoCheckInEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoCheckInEnabledKey, value);
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.otherTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.event_available_outlined),
                  title: Text(strings.otherAutoCheckInTitle),
                  subtitle: Text(strings.otherAutoCheckInSubtitle),
                  value: _autoCheckInEnabled,
                  onChanged: _toggleAutoCheckIn,
                ),
              ],
            ),
    );
  }
}
