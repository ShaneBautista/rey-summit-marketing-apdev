import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'pages/welcome_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

/// Flutter's default ScrollBehavior draws a thick, always-visible desktop
/// scrollbar on web/desktop builds — that's the wide bar you get in a
/// browser preview instead of the thin fading indicator mobile users
/// expect. Overriding it here makes every scrollable in the app behave
/// like a normal mobile scroll view regardless of platform, and lets
/// mouse-drag scroll like a touch drag (handy when testing on web).
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    // Returning the child un-wrapped removes the persistent desktop-style
    // scrollbar track entirely — scrolling still works, it just isn't
    // drawn as a big visible bar.
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(),
      home: const WelcomePage(),
    );
  }
}
