import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'help_pages.dart';

/// Settings tab: notification preferences, monitoring/sync controls, device
/// information, static policy pages and disconnect.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // ------------------------------------------------------------------ actions
  static Future<void> _confirmLogout(BuildContext context, AppState appState) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout / Disconnect?'),
        content: const Text(
          'This removes the device credentials stored on this phone and stops SMS syncing. '
          'Payments already uploaded stay on the APS server. Ask your admin to revoke this device in the '
          'APS dashboard as well.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Disconnect', style: TextStyle(color: ApsColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) await appState.logout();
  }

  static void _openInfo(BuildContext context, String title, List<InfoSection> sections) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => InfoPage(title: title, sections: sections)),
    );
  }

  // ------------------------------------------------------------------- content
  static List<InfoSection> get _privacySections => const [
        InfoSection('What APS Reader reads', [
          'APS Reader reads only new incoming SMS messages from supported payment wallets (bKash, Nagad, Rocket and Upay) after you grant the SMS permission.',
          'Existing messages already in your inbox are not uploaded. The app looks for new payment messages only.',
        ]),
        InfoSection('What is never uploaded', [
          'One-time passwords (OTP) and PIN codes are never uploaded to the APS server.',
          'Messages that are not recognised as a supported wallet payment are ignored and never leave the device.',
        ]),
        InfoSection('How credentials are stored', [
          'Device credentials are stored in Android Keystore-backed encrypted storage on this phone.',
          'Non-secret settings and the local notification inbox are stored in normal app storage.',
        ]),
        InfoSection('How data travels', [
          'All requests to the APS server use HTTPS and are signed with this device\'s secret.',
          'The app never sends data over plain HTTP.',
        ]),
        InfoSection('Disconnecting', [
          'Logout / Disconnect clears the local credentials on this phone.',
          'The device entry can remain active on the APS server, so an administrator should also revoke this device in the APS dashboard.',
        ]),
      ];

  static List<InfoSection> get _helpSections => const [
        InfoSection('Pairing this device', [
          '1. Open the APS dashboard and create a device to get an 8-character pairing code.',
          '2. Enter the server URL and the pairing code on the pairing screen.',
          '3. Grant the SMS permission when Android asks, so payments can be detected.',
        ]),
        InfoSection('Battery and background monitoring', [
          'Android may stop background apps to save power. Set APS Reader to "Unrestricted" in battery settings so monitoring keeps running.',
          'On some phones you may also need to allow auto-start or exclude the app from battery optimisation in the manufacturer\'s settings.',
        ]),
        InfoSection('Force Stop', [
          'If you use Android\'s Force Stop on APS Reader, Android will not restart it automatically. Monitoring stays off until you open the app again.',
          'Android cannot guarantee background monitoring after Force Stop - this is a platform restriction, not an app setting.',
        ]),
        InfoSection('Offline behaviour', [
          'Payments detected while offline are queued on the phone and uploaded automatically when the connection returns.',
          'Queued payments are kept in encrypted storage on this device.',
        ]),
        InfoSection('Transactions and alerts', [
          'Payment alerts come from SMS detected on this phone.',
          'The transaction history and push delivery depend on APS server endpoints that may not be available yet; the app shows that clearly instead of inventing data.',
        ]),
      ];

  static List<InfoSection> get _aboutSections => [
        InfoSection('APS Reader', [
          '${ApsConfig.appName} - ${ApsConfig.description}.',
          'Version ${ApsConfig.appVersionFallback}',
        ]),
        InfoSection('Adverune Payment System', [
          ApsConfig.brandName,
          ApsConfig.tagline,
        ]),
        InfoSection('Server', [
          'Default server: ${ApsConfig.defaultBaseUrl}',
          'Checkout: ${ApsConfig.checkoutUrl}',
        ]),
      ];

  // --------------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    return Scaffold(
      backgroundColor: ApsColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            final prefs = appState.prefs;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              children: [
                const Text('Settings', style: ApsText.title),
                const SectionHeader('Notification Settings'),
                ApsCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(
                    children: [
                      _SwitchRow(
                        title: 'Push Notifications',
                        subtitle: 'Receive alerts from the APS server',
                        value: prefs.push,
                        onChanged: (v) => appState.updatePrefs(prefs.copyWith(push: v)),
                      ),
                      const Divider(height: 1),
                      _SwitchRow(
                        title: 'Payment Alerts',
                        subtitle: 'New payments detected on this phone',
                        value: prefs.paymentAlerts,
                        enabled: prefs.push,
                        onChanged: (v) => appState.updatePrefs(prefs.copyWith(paymentAlerts: v)),
                      ),
                      const Divider(height: 1),
                      _SwitchRow(
                        title: 'Verification Alerts',
                        subtitle: 'Verified, unmatched and duplicate results',
                        value: prefs.verificationAlerts,
                        enabled: prefs.push,
                        onChanged: (v) => appState.updatePrefs(prefs.copyWith(verificationAlerts: v)),
                      ),
                      const Divider(height: 1),
                      _SwitchRow(
                        title: 'Device Alerts',
                        subtitle: 'Reader and server connection changes',
                        value: prefs.deviceAlerts,
                        enabled: prefs.push,
                        onChanged: (v) => appState.updatePrefs(prefs.copyWith(deviceAlerts: v)),
                      ),
                      const Divider(height: 1),
                      _SwitchRow(
                        title: 'Sound',
                        value: prefs.sound,
                        enabled: prefs.push,
                        onChanged: (v) => appState.updatePrefs(prefs.copyWith(sound: v)),
                      ),
                      const Divider(height: 1),
                      _SwitchRow(
                        title: 'Vibration',
                        value: prefs.vibration,
                        enabled: prefs.push,
                        onChanged: (v) => appState.updatePrefs(prefs.copyWith(vibration: v)),
                      ),
                    ],
                  ),
                ),

                const SectionHeader('Monitoring'),
                ApsCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(
                    children: [
                      _SwitchRow(
                        title: 'Background Monitoring',
                        subtitle: 'Keep watching for payment SMS while closed',
                        value: prefs.backgroundMonitoring,
                        onChanged: (v) => appState.updatePrefs(prefs.copyWith(backgroundMonitoring: v)),
                      ),
                      const Divider(height: 1),
                      _SwitchRow(
                        title: 'Automatic Synchronization',
                        subtitle: 'Upload queued payments as soon as possible',
                        value: prefs.autoSync,
                        onChanged: (v) => appState.updatePrefs(prefs.copyWith(autoSync: v)),
                      ),
                      const Divider(height: 1),
                      _ActionRow(
                        title: 'Sync now',
                        subtitle: appState.health.pending == 0
                            ? 'Nothing waiting to upload'
                            : '${appState.health.pending} payment${appState.health.pending == 1 ? '' : 's'} waiting to upload',
                        trailing: TextButton(
                          onPressed: appState.refreshing ? null : () => appState.syncNow(),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          child: Text(appState.refreshing ? 'Syncing...' : 'Sync'),
                        ),
                      ),
                      const Divider(height: 1),
                      _ActionRow(
                        title: 'Battery Optimization',
                        subtitle: appState.batteryUnrestricted
                            ? 'Unrestricted - monitoring can run in the background'
                            : 'Set to Unrestricted so Android does not stop monitoring',
                        pill: StatusPill(
                          appState.batteryUnrestricted ? 'Unrestricted' : 'Optimized',
                          fg: appState.batteryUnrestricted ? ApsColors.success : ApsColors.warn,
                          bg: appState.batteryUnrestricted ? ApsColors.successBg : ApsColors.warnBg,
                        ),
                        trailing: TextButton(
                          onPressed: () => appState.bridge.openBatterySettings(),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          child: const Text('Open settings'),
                        ),
                      ),
                      const Divider(height: 1),
                      _ActionRow(
                        title: 'SMS Permission',
                        subtitle: 'Required to detect payment messages',
                        pill: StatusPill(
                          appState.smsPermission ? 'Allowed' : 'Not allowed',
                          fg: appState.smsPermission ? ApsColors.success : ApsColors.danger,
                          bg: appState.smsPermission ? ApsColors.successBg : ApsColors.dangerBg,
                        ),
                        trailing: appState.smsPermission
                            ? TextButton(
                                onPressed: () => openAppSettings(),
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                child: const Text('Open app settings'),
                              )
                            : TextButton(
                                onPressed: () => appState.requestSmsPermission(),
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                child: const Text('Allow'),
                              ),
                      ),
                    ],
                  ),
                ),

                const SectionHeader('Device Information'),
                ApsCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Column(
                    children: [
                      _InfoRow('Device Name', appState.deviceInfo.name),
                      const Divider(height: 1),
                      _InfoRow('Android Version', appState.deviceInfo.androidVersion.isEmpty ? 'Unknown' : appState.deviceInfo.androidVersion),
                      const Divider(height: 1),
                      _InfoRow('App Version', appState.deviceInfo.appVersion),
                      const Divider(height: 1),
                      _InfoRow('Device Connection', appState.serverReachable ? 'Connected' : 'Disconnected',
                          valueColor: appState.serverReachable ? ApsColors.success : ApsColors.danger),
                      const Divider(height: 1),
                      _InfoRow('Server', appState.config?.baseUrl ?? ApsConfig.defaultBaseUrl),
                      const Divider(height: 1),
                      _InfoRow('Device ID', appState.config == null ? 'Not paired' : '${appState.config!.deviceId}'),
                      const Divider(height: 1),
                      _InfoRow(
                        'Last Synchronization',
                        relative(appState.health.lastSyncOkAtMs == 0
                            ? null
                            : DateTime.fromMillisecondsSinceEpoch(appState.health.lastSyncOkAtMs)),
                      ),
                    ],
                  ),
                ),

                const SectionHeader('Other'),
                ApsCard(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Column(
                    children: [
                      _NavRow(
                        icon: Icons.shield_outlined,
                        title: 'Privacy & Security',
                        onTap: () => _openInfo(context, 'Privacy & Security', _privacySections),
                      ),
                      const Divider(height: 1),
                      _NavRow(
                        icon: Icons.help_outline_rounded,
                        title: 'Help & Support',
                        onTap: () => _openInfo(context, 'Help & Support', _helpSections),
                      ),
                      const Divider(height: 1),
                      _NavRow(
                        icon: Icons.info_outline_rounded,
                        title: 'About APS Reader',
                        onTap: () => _openInfo(context, 'About APS Reader', _aboutSections),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context, appState),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Logout / Disconnect'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ApsColors.danger,
                    side: const BorderSide(color: ApsColors.danger),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    '${ApsConfig.appName} - ${ApsConfig.tagline}',
                    style: ApsText.caption,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rows
// ---------------------------------------------------------------------------

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: enabled
                      ? ApsText.body
                      : ApsText.body.copyWith(color: ApsColors.muted),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle!, style: ApsText.caption),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.title, this.subtitle, this.pill, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? pill;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(title, style: ApsText.body)),
                    if (pill != null) ...[
                      const SizedBox(width: 8),
                      pill!,
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: ApsText.caption),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: ApsText.label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: ApsText.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? ApsColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: ApsColors.muted),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: ApsText.body)),
            const Icon(Icons.chevron_right_rounded, size: 20, color: ApsColors.muted),
          ],
        ),
      ),
    );
  }
}
