import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../screens/my_shop_screen.dart';
import '../screens/pro_screens.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

String _initial() {
  final n = AppSettings.instance.shopName.trim();
  return n.isEmpty ? 'M' : n[0].toUpperCase();
}

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

  void _showLanguageDialog(BuildContext accountContext) {
    showDialog(
      context: accountContext,
      builder: (dialogContext) => SimpleDialog(
        title: Text(tr('language')),
        children: [
          _langOption(
              dialogContext, accountContext, 'en', tr('language_english')),
          _langOption(
              dialogContext, accountContext, 'rw', tr('language_kinyarwanda')),
        ],
      ),
    );
  }

  Widget _langOption(BuildContext dialogContext, BuildContext accountContext,
      String code, String label) {
    final selected = AppSettings.instance.language == code;
    return ListTile(
      title: Text(label),
      trailing: selected ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: () async {
        await AppSettings.instance.setLanguage(code);
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        if (accountContext.mounted) Navigator.pop(accountContext);
      },
    );
  }

  Widget _row(
    IconData icon,
    String label, {
    String? sub,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 22),
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(label),
      subtitle: sub == null ? null : Text(sub),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _accountCardBody(
    BuildContext dc,
    NavigatorState nav,
    ScaffoldMessengerState messenger,
  ) {
    final s = AppSettings.instance;
    final isRw = s.language == 'rw';
    final hasName = s.shopName.trim().isNotEmpty;

    void soon(String label) {
      Navigator.pop(dc);
      messenger.showSnackBar(
        SnackBar(content: Text('$label - ${tr('coming_soon')}')),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 22),
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.primaryGreen,
            child: Text(
              _initial(),
              style: const TextStyle(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasName ? s.shopName : tr('tap_to_add_name'),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: hasName ? null : Colors.grey,
            ),
          ),
          if (s.shopPhone.trim().isNotEmpty)
            Text(s.shopPhone,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: s.proPreview
                  ? const Color(0xFFEAF3DE)
                  : const Color(0xFFE6F1FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              s.proPreview ? tr('pro_plan') : tr('free_plan'),
              style: TextStyle(
                fontSize: 12,
                color: s.proPreview
                    ? const Color(0xFF27500A)
                    : const Color(0xFF0C447C),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 22),
            ),
            onPressed: () {
              Navigator.pop(dc);
              nav.push(
                  MaterialPageRoute(builder: (_) => const MyShopScreen()));
            },
            child: Text(tr('manage_shop')),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          _row(
            Icons.language,
            tr('language'),
            sub: isRw ? tr('language_kinyarwanda') : tr('language_english'),
            onTap: () => _showLanguageDialog(dc),
          ),
          _row(
            Icons.workspace_premium,
            tr('subscription'),
            trailing: s.proPreview
                ? const Text('PRO',
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold))
                : null,
            onTap: () {
              Navigator.pop(dc);
              nav.push(MaterialPageRoute(
                  builder: (_) => const SubscriptionScreen()));
            },
          ),
          _row(Icons.cloud_upload, tr('backup'),
              onTap: () => soon(tr('backup'))),
          _row(Icons.help_outline, tr('help_feedback'),
              onTap: () => soon(tr('help_feedback'))),
          _row(Icons.shield_outlined, tr('privacy'),
              onTap: () => soon(tr('privacy'))),
          _row(Icons.logout, tr('sign_out'),
              onTap: () => soon(tr('sign_out'))),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showAccountMenu(BuildContext context) {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (dc) {
        final top = MediaQuery.of(dc).padding.top + 8;
        final maxH = MediaQuery.of(dc).size.height * 0.85;
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, top, 10, 10),
            child: Material(
              color: Colors.white,
              elevation: 6,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 340, maxHeight: maxH),
                child: ListenableBuilder(
                  listenable: AppSettings.instance,
                  builder: (_, __) => _accountCardBody(dc, nav, messenger),
                ),
              ),
            ),
          ),
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
            tooltip: tr('my_shop'),
            icon: ListenableBuilder(
              listenable: AppSettings.instance,
              builder: (_, __) => CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white,
                child: Text(
                  _initial(),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentBlue),
                ),
              ),
            ),
            onPressed: () => _showAccountMenu(context),
          ),
      ],
    );
  }
}