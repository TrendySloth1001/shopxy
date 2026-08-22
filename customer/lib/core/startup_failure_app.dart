import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shown when `main()` throws before `runApp` — otherwise the launch window
/// stays on screen forever with no message.
///
/// Depends on nothing but Flutter (hardcoded colours, no providers/theme):
/// the thing that failed may well be one of those.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({super.key, required this.error, this.stack});

  final Object error;
  final StackTrace? stack;

  static const _canvas = Color(0xFF0B141A);
  static const _surface = Color(0xFF1F2C34);
  static const _ink = Color(0xFFE9EDEF);
  static const _muted = Color(0xFF8696A0);
  static const _accent = Color(0xFF00A884);

  String get _details => stack == null ? '$error' : '$error\n\n$stack';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: _canvas,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: _accent, size: 40),
                  const SizedBox(height: 16),
                  const Text(
                    "Shopxy couldn't start",
                    style: TextStyle(
                      color: _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Something failed while the app was setting itself up. '
                    'Reopening may fix it — if it keeps happening, send the '
                    'details below to support.',
                    style: TextStyle(color: _muted, fontSize: 14, height: 1.45),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _details,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.4,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: _details)),
                      style: TextButton.styleFrom(foregroundColor: _accent),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy details'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
