import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'src/kitchen.dart';
import 'src/ui/kitchen_screen.dart';
import 'src/ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Full screen, screen always on: this is a wall-mounted kitchen display.
  // Neither may hold up the first frame.
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky).catchError((_) {}));
  unawaited(WakelockPlus.enable().catchError((_) {}));
  runApp(const KitchenApp());
}

class KitchenApp extends StatefulWidget {
  const KitchenApp({super.key});

  @override
  State<KitchenApp> createState() => _KitchenAppState();
}

class _KitchenAppState extends State<KitchenApp> {
  Kitchen? _kitchen;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      final k = await Kitchen.open().timeout(const Duration(seconds: 15));
      if (mounted) setState(() => _kitchen = k);
    } catch (e, st) {
      debugPrint('Start fejlede: $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = _kitchen;
    return MaterialApp(
      title: 'Køkkenskærm',
      debugShowCheckedModeBanner: false,
      theme: K.theme(),
      home: k != null ? KitchenScreen(kitchen: k) : _Starting(error: _error, onRetry: _start),
    );
  }
}

/// Shown while the app opens its storage and the printer port, or if that fails.
class _Starting extends StatelessWidget {
  const _Starting({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/ct-mark.png', height: 110, semanticLabel: 'CT Consult'),
            const SizedBox(height: 32),
            if (error == null) ...[
              const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: K.accent)),
              const SizedBox(height: 16),
              const Text('Starter køkkenskærmen…', style: TextStyle(fontSize: 20, color: K.muted)),
            ] else ...[
              const Icon(Icons.error_outline, color: K.bad, size: 48),
              const SizedBox(height: 12),
              const Text('Køkkenskærmen kunne ikke starte', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: K.white)),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: K.muted)),
              const SizedBox(height: 24),
              FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Prøv igen')),
            ],
          ]),
        ),
      ),
    );
  }
}
