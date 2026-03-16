import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';

void main() {
  runApp(const AtomicFlutterDevToolsApp());
}

class AtomicFlutterDevToolsApp extends StatelessWidget {
  const AtomicFlutterDevToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(
      child: AtomicFlutterApp(),
    );
  }
}
