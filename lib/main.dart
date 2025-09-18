import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/app_router.dart';

void main() {
  runApp(const ProviderScope(child: AnatolianCoinsApp()));
}

class AnatolianCoinsApp extends ConsumerWidget {
  const AnatolianCoinsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Anatolian Coins',
      theme: ThemeData(
        colorSchemeSeed: Colors.brown,
        useMaterial3: true,
      ),
      routerConfig: appRouter(ref),
    );
  }
}
