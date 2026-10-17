import 'package:flutter/material.dart';

class MenyaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final PreferredSizeWidget? bottom;

  const MenyaAppBar({super.key, required this.title, this.bottom});

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  void _showAccountMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _item(context, Icons.login, 'Sign in'),
            _item(context, Icons.dark_mode, 'Dark mode'),
            _item(context, Icons.language, 'Language'),
            _item(context, Icons.play_circle, 'Try demo'),
            _item(context, Icons.credit_card, 'Subscription'),
            _item(context, Icons.help_outline, 'Help'),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(content: Text('$label coming soon')));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      bottom: bottom,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Search coming soon')),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.account_circle),
          onPressed: () => _showAccountMenu(context),
        ),
      ],
    );
  }
}