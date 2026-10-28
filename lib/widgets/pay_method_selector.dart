import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';

class PayMethodSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool allowCredit;

  const PayMethodSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowCredit = true,
  });

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(fontSize: 13);
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          foregroundColor: Colors.black87,
          backgroundColor: Colors.white,
          selectedForegroundColor: Colors.white,
          selectedBackgroundColor: AppTheme.accentBlue,
        ),
        segments: [
          ButtonSegment(
            value: 'cash',
            label: Text(tr('pay_cash'), style: small, maxLines: 1),
          ),
          ButtonSegment(
            value: 'momo',
            label: Text(tr('pay_momo'), style: small, maxLines: 1),
          ),
          if (allowCredit)
            ButtonSegment(
              value: 'credit',
              label: Text(tr('pay_credit'), style: small, maxLines: 1),
            ),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}