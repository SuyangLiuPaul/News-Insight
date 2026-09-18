import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:news_insight/models/app_settings.dart';
import 'package:news_insight/pages/feed_page.dart';
import 'package:news_insight/theme/app_theme.dart';
import 'package:news_insight/theme/ui_strings.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: const YahwehsWorldApp(),
    ),
  );
}

class YahwehsWorldApp extends StatefulWidget {
  const YahwehsWorldApp({super.key});

  @override
  State<YahwehsWorldApp> createState() => _YahwehsWorldAppState();
}

class _YahwehsWorldAppState extends State<YahwehsWorldApp> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    context.read<AppSettings>().load().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    if (!_ready) {
      return MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return MaterialApp(
      title: uiStrings['appName']?[settings.locale] ?? 'News Insight',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: const FeedPage(),
    );
  }
}
