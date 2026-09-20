import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/country_preference.dart';

/// App-bar country switcher.
///
/// Lives in `shared/` because every feature screen carries one: the selected
/// market changes what the classifier assumes, how a local number is parsed,
/// which regions the map shows and which help desks are listed, so switching
/// it has to be reachable wherever the user happens to be. It writes to
/// [CountryPreference], which every screen listens to, so one change
/// propagates everywhere rather than only to the tab that made it.
class CountryMenuButton extends StatelessWidget {
  const CountryMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: CountryPreference.codeNotifier,
      builder: (BuildContext context, String code, _) {
        return PopupMenuButton<String>(
          tooltip: 'Change country',
          onSelected: CountryPreference.set,
          itemBuilder: (BuildContext context) => CountryRegistry.all
              .map(
                (CountryProfile c) => PopupMenuItem<String>(
                  value: c.code,
                  child: Row(
                    children: <Widget>[
                      if (c.code == code)
                        const Icon(Icons.check, size: 16)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      Text(c.name),
                    ],
                  ),
                ),
              )
              .toList(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(code, style: Theme.of(context).textTheme.labelLarge),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        );
      },
    );
  }
}
