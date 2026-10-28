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

  Widget _pill(String v, String label) {
    final selected = value == v;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(v),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accentBlue : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppTheme.accentBlue : Colors.grey.shade400,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 13,
              height: 1.15,
              color: selected ? Colors.white : Colors.black87,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _pill('cash', tr('pay_cash')),
        const SizedBox(width: 6),
        _pill('momo', tr('pay_momo')),
        if (allowCredit) ...[
          const SizedBox(width: 6),
          _pill('credit', tr('pay_credit')),
        ],
      ],
    );
  }
}