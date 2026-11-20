import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';

/// Device pairing screen. Shown whenever no device credentials are stored.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _server;
  final TextEditingController _code = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: ApsConfig.defaultBaseUrl);
  }

  @override
  void dispose() {
    _server.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final app = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await app.pair(
      baseUrl: _server.text.trim(),
      code: _code.text.trim().toUpperCase(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error == null) _code.clear();
    });
  }

  String _connectionLabel(AppState app) {
    if (_busy) return 'Connecting…';
    return switch (app.session) {
      SessionState.loggedIn => 'Connected',
      SessionState.loading => 'Checking…',
      SessionState.loggedOut => 'Not connected',
    };
  }

  String _deviceLabel(AppState app) {
    final info = app.deviceInfo;
    final parts = <String>[
      if (info.name.trim().isNotEmpty) info.name.trim(),
      if (info.androidVersion.trim().isNotEmpty) info.androidVersion.trim(),
      'v${info.appVersion}',
    ];
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      backgroundColor: ApsColors.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight > 38 ? constraints.maxHeight - 38 : 0,
                  maxWidth: 460,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _brand(),
                    const SizedBox(height: 18),
                    _pairingCard(app),
                    const SizedBox(height: 14),
                    _statusBlock(app),
                    const SizedBox(height: 18),
                    const Text(
                      ApsConfig.tagline,
                      textAlign: TextAlign.center,
                      style: ApsText.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            color: ApsColors.infoBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/images/aps_lockup.png',
                width: 200,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          ApsConfig.brandName,
          textAlign: TextAlign.center,
          style: ApsText.title,
        ),
        const SizedBox(height: 4),
        const Text(
          ApsConfig.description,
          textAlign: TextAlign.center,
          style: ApsText.label,
        ),
      ],
    );
  }

  Widget _pairingCard(AppState app) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ApsColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ApsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Pair this device', style: ApsText.section),
          const SizedBox(height: 4),
          const Text(
            'Enter the pairing code from your APS dashboard to link this phone.',
            style: ApsText.label,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _server,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Server',
              hintText: 'https://aps.adverune.store',
              prefixIcon: Icon(Icons.language_rounded),
            ),
            onSubmitted: (_) => _codeFocus.requestFocus(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            focusNode: _codeFocus,
            enabled: !_busy,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            maxLength: 8,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
              color: ApsColors.ink,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              _UpperCaseFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: 'Device Pairing Code',
              hintText: 'ABCD2345',
              counterText: '',
              prefixIcon: Icon(Icons.key_rounded),
            ),
            onSubmitted: (_) => _connect(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _errorBox(_error!),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _connect,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Connect Device'),
          ),
          const SizedBox(height: 10),
          Text(
            'Pairing links this phone as an SMS reader for your merchant account.',
            textAlign: TextAlign.center,
            style: ApsText.caption.copyWith(color: ApsColors.muted),
          ),
          if (app.revoked == true) ...[
            const SizedBox(height: 10),
            Text(
              'The previous device credential is no longer valid. Pair again with a fresh code.',
              textAlign: TextAlign.center,
              style: ApsText.caption.copyWith(color: ApsColors.danger),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ApsColors.dangerBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: ApsColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: ApsColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBlock(AppState app) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: ApsColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ApsColors.border),
      ),
      child: Column(
        children: [
          _statusRow(
            icon: Icons.link_rounded,
            label: 'Connection status',
            value: _connectionLabel(app),
            valueColor: app.session == SessionState.loggedIn ? ApsColors.success : ApsColors.muted,
          ),
          const Divider(height: 1),
          _statusRow(
            icon: Icons.cloud_rounded,
            label: 'Server status',
            value: app.online ? 'Internet available' : 'No internet',
            valueColor: app.online ? ApsColors.success : ApsColors.warn,
          ),
          const Divider(height: 1),
          _statusRow(
            icon: Icons.smartphone_rounded,
            label: 'Device info',
            value: _deviceLabel(app),
            valueColor: ApsColors.ink,
          ),
        ],
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ApsColors.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: ApsText.label)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps the pairing code visually uppercase while the user types.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.toUpperCase();
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
