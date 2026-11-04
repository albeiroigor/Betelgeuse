import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/device_flow.dart';
import '../../core/links.dart';
import '../../core/theme/theme_picker.dart';

class Login extends StatefulWidget {
  final Future<void> Function(String) onToken;
  final VoidCallback? onCancel;
  const Login({super.key, required this.onToken, this.onCancel});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  DeviceCode? code;
  String? error;
  int run = 0;

  @override
  void dispose() {
    run++;
    super.dispose();
  }

  Future<void> _start() async {
    final me = ++run;
    setState(() => error = null);
    try {
      final d = await startLogin();
      if (!mounted || run != me) return;
      setState(() => code = d);
      openGitHub(d.uri);
      final token = await waitForToken(d, () => run != me);
      if (!mounted || run != me) return;
      await widget.onToken(token);
    } catch (e) {
      if (mounted && run == me) {
        setState(() {
          error = '$e';
          code = null;
        });
      }
    }
  }

  void _cancel() => setState(() {
    run++;
    code = null;
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = code;

    final Widget body;
    if (clientId.isEmpty) {
      body = _missingClientId(cs);
    } else if (c == null) {
      body = _loginButton(cs);
    } else {
      body = _waitingCode(c, cs);
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (widget.onCancel != null)
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  tooltip: 'Volver',
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: widget.onCancel,
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Apariencia',
                icon: const Icon(Icons.palette_outlined, size: 20),
                onPressed: () => showThemePicker(context),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/icon/betelgeuse_square.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          semanticLabel: 'Betelgeuse',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Betelgeuse',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          letterSpacing: -.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tus GitHub Projects en un tablero simple.',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Conectar con GitHub',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Autoriza Betelgeuse para leer tus proyectos y tableros.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: cs.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            body,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _missingClientId(ColorScheme cs) => Text(
    'Falta el Client ID de tu OAuth App.\n\n'
    'Ejecuta la app con:\n--dart-define=BETELGEUSE_CLIENT_ID=tu_id',
    textAlign: TextAlign.center,
    style: TextStyle(color: cs.error, fontSize: 12.5, height: 1.5),
  );

  Widget _loginButton(ColorScheme cs) => Column(
    children: [
      SizedBox(
        width: double.infinity,
        height: 44,
        child: FilledButton(
          onPressed: _start,
          child: const Text('Continuar con GitHub'),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 12),
        Text(
          error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.error, fontSize: 12.5),
        ),
      ],
    ],
  );

  Widget _waitingCode(DeviceCode c, ColorScheme cs) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Copia este código en GitHub para autorizar la app:',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 12.5,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 12),
      Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: SelectableText(
          c.userCode,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 30,
            fontWeight: FontWeight.w600,
            letterSpacing: 4,
            color: cs.primary,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: c.userCode)),
              child: const Text('Copiar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: () => openGitHub(c.uri),
              child: const Text('Abrir GitHub'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
          ),
          const SizedBox(width: 8),
          Text(
            'Esperando autorización…',
            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
          ),
        ],
      ),
      const SizedBox(height: 4),
      TextButton(onPressed: _cancel, child: const Text('Cancelar')),
    ],
  );
}
