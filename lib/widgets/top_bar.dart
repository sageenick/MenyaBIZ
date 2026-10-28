import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../screens/pro_screens.dart';
import '../services/settings_service.dart';

class MenyaAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final PreferredSizeWidget? bottom;
  final ValueChanged<String>? onSearchChanged;

  const MenyaAppBar({
    super.key,
    required this.title,
    this.bottom,
    this.onSearchChanged,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  State<MenyaAppBar> createState() => _MenyaAppBarState();
}

class _MenyaAppBarState extends State<MenyaAppBar> {
  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _searchController.clear();
      widget.onSearchChanged?.call('');
    }
  }

  void _showLanguageDialog(BuildContext sheetContext) {
    showDialog(
      context: sheetContext,
      builder: (dialogContext) => SimpleDialog(
        title: Text(tr('language')),
        children: [
          _langOption(
              dialogContext, sheetContext, 'en', tr('language_english')),
          _langOption(
              dialogContext, sheetContext, 'rw', tr('language_kinyarwanda')),
        ],
      ),
    );
  }

  Widget _langOption(BuildContext dialogContext, BuildContext sheetContext,
      String code, String label) {
    final selected = AppSettings.instance.language == code;
    return ListTile(
      title: Text(label),
      trailing: selected ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: () async {
        await AppSettings.instance.setLanguage(code);
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        if (sheetContext.mounted) Navigator.pop(sheetContext);
      },
    );
  }

  void _showAccountMenu(BuildContext context) {
    final nav = Navigator.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: AppSettings.instance,
        builder: (_, _) {
          final s = AppSettings.instance;
          final isRw = s.language == 'rw';
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(tr('language')),
                    subtitle: Text(isRw
                        ? tr('language_kinyarwanda')
                        : tr('language_english')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showLanguageDialog(sheetContext),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.receipt_long),
                    title: Text(tr('vat_toggle')),
                    value: s.vatEnabled,
                    onChanged: (v) => s.setVatEnabled(v),
                  ),
                  const Divider(),
                  _item(sheetContext, Icons.login, tr('sign_in')),
                  _item(sheetContext, Icons.dark_mode, tr('dark_mode')),
                  _item(sheetContext, Icons.play_circle, tr('try_demo')),
                  ListTile(
                    leading: const Icon(Icons.credit_card),
                    title: Text(tr('subscription')),
                    trailing: s.proPreview
                        ? const Text('PRO',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold))
                        : null,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      nav.push(MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen()));
                    },
                  ),
                  _item(sheetContext, Icons.help_outline, tr('help')),
                ],
              ),
            ),
          );
        },
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
        messenger.showSnackBar(
          SnackBar(content: Text('$label - ${tr('coming_soon')}')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: _searching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              cursorColor: Colors.white,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                hintText: tr('search_hint'),
                hintStyle: const TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
              onChanged: widget.onSearchChanged,
            )
          : Text(widget.title),
      bottom: widget.bottom,
      actions: [
        if (widget.onSearchChanged != null)
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        if (!_searching)
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => _showAccountMenu(context),
          ),
      ],
    );
  }
}