import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/library_controller.dart';
import 'controllers/theme_controller.dart';
import 'screens/feed_screen.dart';
import 'screens/setup_screen.dart';

class LangTokApp extends StatelessWidget {
  const LangTokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryController()..initialize()),
        ChangeNotifierProvider(create: (_) => ThemeController()..initialize()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
            title: 'LangTok',
            debugShowCheckedModeBanner: false,
            theme: themeController.themeData,
            home: const _RootRouter(),
          );
        },
      ),
    );
  }
}

/// Switches between the setup flow and the main feed based on whether a
/// study folder has been selected and successfully scanned.
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();

    switch (library.status) {
      case LibraryStatus.uninitialized:
      case LibraryStatus.loading:
        return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      case LibraryStatus.needsFolder:
      case LibraryStatus.error:
        return const SetupScreen();
      case LibraryStatus.ready:
        return const FeedScreen();
    }
  }
}
