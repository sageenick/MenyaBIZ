import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../widgets/top_bar.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MenyaAppBar(title: tr('learn')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (var i = 1; i <= 5; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                leading: const Icon(Icons.lightbulb_outline,
                    color: AppTheme.primaryGreen),
                title: Text(tr('lesson${i}_t'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(tr('lesson${i}_b'))],
              ),
            ),
        ],
      ),
    );
  }
}