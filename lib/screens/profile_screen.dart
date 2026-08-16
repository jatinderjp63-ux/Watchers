import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/settings_provider.dart';
import '../services/tab_navigation_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() {
    return _ProfileScreenState();
  }
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ScrollController _scrollController =
      ScrollController();

  @override
  void initState() {
    super.initState();

    TabNavigationService.profileTapSignal
        .addListener(_scrollToTop);
  }

  @override
  void dispose() {
    TabNavigationService.profileTapSignal
        .removeListener(_scrollToTop);

    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) {
      return;
    }

    if (_scrollController.offset <= 0) {
      return;
    }

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/profile/settings');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            const CircleAvatar(
              radius: 40,
              child: Icon(
                Icons.person,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'User',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Settings'),
            const SizedBox(height: 12),
            _buildTile(
              context,
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: settings.notificationsEnabled
                  ? 'Enabled'
                  : 'Disabled',
              onTap: () {
                final newValue =
                    !settings.notificationsEnabled;

                ref
                    .read(settingsProvider.notifier)
                    .setNotificationsEnabled(newValue);
              },
              trailing: Switch(
                value: settings.notificationsEnabled,
                onChanged: (value) {
                  ref
                      .read(settingsProvider.notifier)
                      .setNotificationsEnabled(value);
                },
              ),
            ),
            _buildTile(
              context,
              icon: Icons.brightness_6_outlined,
              title: 'Dark Mode',
              subtitle:
                  settings.themeMode == ThemeMode.dark
                      ? 'On'
                      : 'Off',
              onTap: () {
                final isNowDark =
                    settings.themeMode == ThemeMode.dark;

                ref
                    .read(settingsProvider.notifier)
                    .toggleDarkMode(!isNowDark);
              },
              trailing: Switch(
                value:
                    settings.themeMode == ThemeMode.dark,
                onChanged: (value) {
                  ref
                      .read(settingsProvider.notifier)
                      .toggleDarkMode(value);
                },
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Account'),
            const SizedBox(height: 12),
            _buildTile(
              context,
              icon: Icons.person_outline,
              title: 'Edit Profile',
              onTap: () {
                // Add profile editing navigation here.
              },
            ),
            _buildTile(
              context,
              icon: Icons.lock_outline,
              title: 'Privacy',
              onTap: () {
                // Add privacy navigation here.
              },
            ),
            _buildTile(
              context,
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () {
                // Add help navigation here.
              },
            ),
            const SizedBox(height: 24),
            _buildTile(
              context,
              icon: Icons.logout,
              title: 'Log Out',
              isDestructive: true,
              onTap: () {
                // Add logout confirmation here.
              },
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'App Version 1.0.0',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final tileColor = isDestructive
        ? Colors.red
        : colorScheme.onSurface;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          icon,
          color: tileColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: tileColor,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

class ThemeSwitch extends StatelessWidget {
  const ThemeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Theme Switch Placeholder',
      ),
    );
  }
}