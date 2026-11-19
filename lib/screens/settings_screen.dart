import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/models.dart';
import '../core/native_bridge.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Settings tab: profile, Bluetooth, and sign out.
class SettingsScreen extends StatefulWidget {
  final ApiClient api;
  final VoidCallback onSignOut;

  const SettingsScreen({super.key, required this.api, required this.onSignOut});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NativeBridge _bridge = NativeBridge();

  Me? _me;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  BluetoothStatus? _bt;

  final _nameCtrl = TextEditingController();
  final _levelCtrl = TextEditingController();
  final _semesterCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _loadBluetooth();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _levelCtrl.dispose();
    _semesterCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await widget.api.getJson('/auth/student/me');
      if (!mounted) return;
      final me = Me.fromJson(res);
      setState(() {
        _me = me;
        _error = null;
        _loading = false;
        _nameCtrl.text = me.fullName;
        _levelCtrl.text = me.level;
        _semesterCtrl.text = me.semester ?? '';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _loadBluetooth() async {
    try {
      final status = await _bridge.bluetoothStatus();
      if (mounted) setState(() => _bt = status);
    } on NativeException {
      // Bluetooth status is best-effort on unsupported platforms.
    }
  }

  Future<void> _saveProfile() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final res = await widget.api.patchJson('/auth/student/profile', {
        'fullName': _nameCtrl.text.trim(),
        'level': _levelCtrl.text.trim(),
        'semester': _semesterCtrl.text.trim(),
      });
      if (!mounted) return;
      setState(() => _me = Me.fromJson(res));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final me = _me;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    ErrorBanner(_error!, onRetry: _load),
                    const SizedBox(height: 12),
                  ],
                  if (me != null) ...[
                    AppCard(
                      child: Row(
                        children: [
                          Avatar(name: me.fullName, radius: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  me.fullName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text('Index № ${me.indexNumber}', style: TextStyle(color: muted)),
                                Text(
                                  '${me.department} · ${me.programme}',
                                  style: TextStyle(color: muted),
                                ),
                                Text(
                                  'Level ${me.level}${me.semester != null && me.semester!.isNotEmpty ? ' · Semester ${me.semester}' : ''}',
                                  style: TextStyle(color: muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SectionTitle('Edit profile'),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _levelCtrl,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              labelText: 'Level',
                              prefixIcon: Icon(Icons.school_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _semesterCtrl,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              labelText: 'Semester',
                              prefixIcon: Icon(Icons.calendar_month_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _saving ? null : _saveProfile,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Save changes'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SectionTitle('Bluetooth'),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _bt?.on == true ? Icons.bluetooth : Icons.bluetooth_disabled,
                              color: _bt?.on == true ? AppColors.green2 : AppColors.btOff,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _bt == null
                                    ? 'Checking Bluetooth…'
                                    : _bt!.state == 'off'
                                        ? 'Bluetooth is off'
                                        : _bt!.state == 'node'
                                            ? 'Polling node in range'
                                            : 'Bluetooth is on',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            TextButton(onPressed: _loadBluetooth, child: const Text('Refresh')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await _bridge.enableBluetooth();
                                  await _loadBluetooth();
                                },
                                icon: const Icon(Icons.bluetooth),
                                label: const Text('Turn on'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _bridge.openSettings(),
                                icon: const Icon(Icons.settings_outlined),
                                label: const Text('App settings'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SectionTitle('Account'),
                  OutlinedButton.icon(
                    onPressed: widget.onSignOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${AppConfig.appName} · v1.0.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
