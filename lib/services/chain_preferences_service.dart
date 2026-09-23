import 'package:shared_preferences/shared_preferences.dart';

/// Which grocery chains a user has opted OUT of comparing against (e.g.
/// someone who never shops at Meny doesn't want it cluttering search
/// results). Stored locally per-device via `shared_preferences`, not
/// Firestore — this is a lightweight display preference, not data that
/// needs to sync across devices or survive a browser's site data being
/// cleared, and keeping it local means it works the same for an anonymous
/// guest as for a signed-in user.
///
/// Stores EXCLUDED chains (opt-out), not an allow-list — so a user who's
/// never touched this setting sees every chain, same as before this
/// feature existed, rather than nothing until they explicitly pick some.
class ChainPreferencesService {
  static const _prefsKey = 'excludedStoreNames';

  Future<Set<String>> getExcludedStoreNames() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_prefsKey) ?? const []).toSet();
  }

  Future<void> setExcludedStoreNames(Set<String> excluded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, excluded.toList());
  }
}
