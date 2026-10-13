import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'src/kitchen.dart';
import 'src/ui/kitchen_screen.dart';
import 'src/ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Full screen, screen always on: this is a wall-mounted kitchen display.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  WakelockPlus.enable();
  final kitchen = await Kitchen.open();
  runApp(KitchenApp(kitchen: kitchen));
}

class KitchenApp extends StatelessWidget {
  const KitchenApp({super.key, required this.kitchen});
  final Kitchen kitchen;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Køkkenskærm',
      debugShowCheckedModeBanner: false,
      theme: K.theme(),
      home: KitchenScreen(kitchen: kitchen),
    );
  }
}
