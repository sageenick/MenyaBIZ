import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class MyShopScreen extends StatefulWidget {
  const MyShopScreen({super.key});

  @override
  State<MyShopScreen> createState() => _MyShopScreenState();
}

class _MyShopScreenState extends State<MyShopScreen> {
  late final TextEditingController _nameC;
  late final TextEditingController _phoneC;
  late final TextEditingController _addrC;

  @override
  void initState() {
    super.initState();
    final s = AppSettings.instance;
    _nameC = TextEditingController(text: s.shopName);
    _phoneC = TextEditingController(text: s.shopPhone);
    _addrC = TextEditingController(text: s.shopAddress);
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _addrC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await AppSettings.instance.setShop(
      name: _nameC.text.trim(),
      phone: _phoneC.text.trim(),
      address: _addrC.text.trim(),
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(tr('shop_saved'))));
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameC.text.trim();
    final initial = name.isEmpty ? 'M' : name[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text(tr('my_shop'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: AppTheme.primaryGreen,
              child: Text(
                initial,
                style: const TextStyle(
                    fontSize: 30,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameC,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: tr('shop_name'),
              filled: true,
              fillColor: Colors.white,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneC,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: tr('shop_phone'),
              filled: true,
              fillColor: Colors.white,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addrC,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: tr('shop_address'),
              filled: true,
              fillColor: Colors.white,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: AppSettings.instance,
            builder: (context, _) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SwitchListTile(
                title: Text(tr('vat_toggle')),
                subtitle: Text(tr('shop_vat_hint'),
                    style: const TextStyle(fontSize: 12)),
                value: AppSettings.instance.vatEnabled,
                onChanged: (v) => AppSettings.instance.setVatEnabled(v),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(tr('save')),
            ),
          ),
        ],
      ),
    );
  }
}