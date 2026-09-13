import 'package:flutter/material.dart';

import '../theme.dart';
import '../services/i18n.dart';

/// Picker for the app language — English + the 22 official Indian languages.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Localized((context) => Scaffold(
          appBar: AppBar(
              title:
                  Text(t('Language'), style: serif(size: 17, color: AppColors.green))),
          body: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: kLanguages.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.line),
            itemBuilder: (_, i) {
              final l = kLanguages[i];
              final selected = l.code == appLocale.lang.code;
              return ListTile(
                title: Text(l.native,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: Text(l.name,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                trailing: selected
                    ? const Icon(Icons.check_circle, color: AppColors.green)
                    : null,
                onTap: () async {
                  await appLocale.setLanguage(l);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${l.name} • ${l.native}'),
                      duration: const Duration(milliseconds: 900)));
                },
              );
            },
          ),
        ));
  }
}
