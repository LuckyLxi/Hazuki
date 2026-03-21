part of '../main.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: const Text('关于'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 48),
          const Center(
            child: FlutterLogo(
              size: 80,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Hazuki',
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '版本 1.0.0',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.outline,
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'JMComic第三方',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 48),
          const Divider(indent: 32, endIndent: 32),
          ListTile(
            leading: const Icon(Icons.code_outlined),
            title: const Text('项目地址'),
            subtitle: const Text('GitHub (https://github.com/LuckyLxi/Hazuki)'),
            onTap: () async {
              final url = Uri.parse('https://github.com/LuckyLxi/Hazuki');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('无法打开链接')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('反馈问题'),
            subtitle: const Text('如果在阅读中遇到任何问题，欢迎反馈'),
            onTap: () async {
              final url = Uri.parse('https://github.com/LuckyLxi/Hazuki/issues');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('无法打开反馈链接')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('开源协议'),
            subtitle: const Text('GPL-3.0 License'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('本项目采用 GPL-3.0 开源协议')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('鸣谢'),
            subtitle: const Text('启发本项目开发的优秀作品'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('致谢'),
                  content: const Text(
                    '本项目的开发参考并感谢以下开源项目：\n\n'
                    '• Venera: 登录逻辑实现参考\n'
                    '• Animeko: 界面布局设计参考',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('第三方库许可'),
            subtitle: const Text('查看本应用使用的开源库'),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'Hazuki',
                applicationVersion: '1.0.0',
                applicationIcon: const Padding(
                  padding: EdgeInsets.all(12),
                  child: FlutterLogo(size: 48),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '© 2026 Hazuki Project',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
