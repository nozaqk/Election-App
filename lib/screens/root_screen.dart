import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/models.dart';
import '../core/native_bridge.dart';
import '../core/session.dart';
import '../core/theme.dart';
import 'auth_screen.dart';
import 'election_screen.dart';
import 'elections_screen.dart';
import 'home_screen.dart';
import 'news_screen.dart';
import 'settings_screen.dart';

/// Root shell: auth gate, four-tab navigation, Bluetooth badge and the
/// background notification poller lifecycle.
///
/// Election detail is pushed as a separate route so the bottom navigation
/// (and its easy escape from a half-finished ballot) disappears while the
/// student is voting.
class RootScreen extends StatefulWidget {
  final SessionStore session;
  final ApiClient api;
  final String? initialToken;

  const RootScreen({
    super.key,
    required this.session,
    required this.api,
    required this.initialToken,
  });

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  final NativeBridge _bridge = NativeBridge();

  String? _token;
  int _tab = 0;
  BluetoothStatus? _bt;
  Timer? _btTimer;

  static const List<String> _titles = ['Home', 'News', 'Elections', 'Settings'];

  @override
  void initState() {
    super.initState();
    _token = widget.initialToken;
    widget.api.token = _token;
    widget.api.onUnauthorized = _handleUnauthorized;
    if (_token != null) {
      _startNotifications();
      _refreshBluetooth();
      _btTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshBluetooth());
    }
  }

  @override
  void dispose() {
    _btTimer?.cancel();
    super.dispose();
  }

  void _startNotifications() {
    final token = _token;
    if (token == null) return;
    _bridge.notifyStart(token, AppConfig.apiBase);
  }

  Future<void> _refreshBluetooth() async {
    try {
      final status = await _bridge.bluetoothStatus();
      if (mounted) setState(() => _bt = status);
    } on NativeException {
      // Best-effort: unsupported platforms simply show no badge state.
    }
  }

  Future<void> _handleLogin(String token) async {
    await widget.session.saveToken(token);
    if (!mounted) return;
    setState(() {
      _token = token;
      _tab = 0;
    });
    widget.api.token = token;
    _startNotifications();
    _refreshBluetooth();
    _btTimer ??= Timer.periodic(const Duration(seconds: 10), (_) => _refreshBluetooth());
  }

  Future<void> _handleSignOut() async {
    await widget.session.clear();
    await _bridge.notifyStop();
    if (!mounted) return;
    setState(() {
      _token = null;
      _tab = 0;
      _bt = null;
    });
    widget.api.token = null;
  }

  void _handleUnauthorized() {
    // The API client already cleared its token on HTTP 401.
    _handleSignOut();
  }

  void _openElection(ElectionSummary election) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ElectionScreen(api: widget.api, election: election),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_token == null) {
      return AuthScreen(api: widget.api, onAuthenticated: _handleLogin);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          _BluetoothBadge(status: _bt, onTap: () => _bridge.openSettings()),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(api: widget.api, onOpenElection: _openElection),
          NewsScreen(api: widget.api, onOpenElection: _openElection),
          ElectionsScreen(api: widget.api, onOpenElection: _openElection),
          SettingsScreen(api: widget.api, onSignOut: _handleSignOut),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (index) => setState(() => _tab = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.newspaper_outlined), label: 'News'),
          BottomNavigationBarItem(icon: Icon(Icons.how_to_vote_outlined), label: 'Elections'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

/// Bluetooth state badge shown in the app bar.
class _BluetoothBadge extends StatelessWidget {
  final BluetoothStatus? status;
  final VoidCallback onTap;

  const _BluetoothBadge({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final state = status?.state ?? 'on';
    final color = switch (state) {
      'off' => AppColors.btOff,
      'node' => AppColors.btNode,
      _ => AppColors.btOn,
    };
    final label = switch (state) {
      'off' => 'Off',
      'node' => 'Node',
      _ => 'On',
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
