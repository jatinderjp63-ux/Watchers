import 'package:flutter/material.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  child: Icon(Icons.person, size: 38),
                ),
                SizedBox(height: 14),
                Text(
                  'Watchers',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'yourmail@example.com',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _InfoTile(
            icon: Icons.person_outline,
            title: 'Username',
            subtitle: 'Watchers',
          ),
          _InfoTile(
            icon: Icons.email_outlined,
            title: 'E-mail',
            subtitle: 'yourmail@example.com',
          ),
          _InfoTile(
            icon: Icons.backup_outlined,
            title: 'Backup status',
            subtitle: 'Local only',
          ),
          _InfoTile(
            icon: Icons.calendar_today_outlined,
            title: 'Joined',
            subtitle: 'August 2026',
          ),
          const SizedBox(height: 18),
          _ActionTile(
            icon: Icons.download_outlined,
            title: 'Export data',
            onTap: () {},
          ),
          _ActionTile(
            icon: Icons.upload_file_outlined,
            title: 'Import data',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}