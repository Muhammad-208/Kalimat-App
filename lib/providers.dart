import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'data/db/database.dart';
import 'data/repositories/dictionary_repository.dart';
import 'data/auth/auth_service.dart';
import 'data/sync/sync_service.dart';
import 'data/models/root.dart';
import 'data/models/word.dart';
import 'data/models/furuq.dart';
import 'data/models/source_info.dart';

final dbProvider = Provider<KalimatDb>((_) => KalimatDb.instance);

final repositoryProvider = Provider<DictionaryRepository>(
  (ref) => DictionaryRepository(ref.watch(dbProvider)),
);

/// SharedPreferences instance — overridden in main() after it loads.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('override sharedPrefsProvider in main()'),
);

/// True once Firebase.initializeApp() succeeds — overridden in main().
/// False means the project isn't configured yet; the app runs offline-only.
final firebaseReadyProvider = Provider<bool>((_) => false);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(firebaseReadyProvider)),
);

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(ref.watch(firebaseReadyProvider)),
);

/// Current auth state (null when signed out or Firebase not configured).
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// Light/dark toggle (screen 4 is the night-reading variant).
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);

// ── Per-user source visibility (offline, local) ───────────
/// The set of source NAMES the user has chosen to hide from results.
/// Empty = show everything (the default). Persisted in SharedPreferences.
class HiddenSourcesNotifier extends StateNotifier<Set<String>> {
  HiddenSourcesNotifier(this._prefs)
      : super((_prefs.getStringList(_key) ?? const []).toSet());

  static const _key = 'hidden_sources';
  final SharedPreferences _prefs;

  bool isHidden(String source) => state.contains(source);

  void toggle(String source) {
    final next = {...state};
    next.contains(source) ? next.remove(source) : next.add(source);
    state = next;
    _prefs.setStringList(_key, next.toList());
  }

  void showAll() {
    state = {};
    _prefs.setStringList(_key, const []);
  }

  /// Replace the whole set (used when applying a pulled remote value).
  void setAll(Set<String> value) {
    state = {...value};
    _prefs.setStringList(_key, value.toList());
  }
}

final hiddenSourcesProvider =
    StateNotifierProvider<HiddenSourcesNotifier, Set<String>>(
  (ref) => HiddenSourcesNotifier(ref.watch(sharedPrefsProvider)),
);

/// All sources that actually have entries (for the settings list).
final availableSourcesProvider = FutureProvider<List<SourceInfo>>(
  (ref) => ref.watch(repositoryProvider).availableSources(),
);

// ── Home ──────────────────────────────────────────────────
final suggestedRootsProvider = FutureProvider<List<Root>>(
  (ref) => ref.watch(repositoryProvider).suggestedRoots(),
);
final topRootsProvider = FutureProvider<List<Root>>(
  (ref) => ref.watch(repositoryProvider).mostFrequentRoots(),
);

// ── Word result (keyed by the typed query / root) ─────────
class RootResult {
  final Root root;
  final List<LexiconEntry> lexicon;
  final List<WordOccurrence> sampleVerses;
  final Furuq? furuq; // verified only
  const RootResult(this.root, this.lexicon, this.sampleVerses, this.furuq);
}

final rootResultProvider =
    FutureProvider.family<RootResult?, String>((ref, query) async {
  final repo = ref.watch(repositoryProvider);
  final root = await repo.resolveRoot(query);
  if (root == null) return null;
  final results = await Future.wait([
    repo.lexiconFor(root.id),
    repo.occurrences(root.id, limit: 2),
    repo.verifiedFuruqFor(root.root),
  ]);
  return RootResult(
    root,
    results[0] as List<LexiconEntry>,
    results[1] as List<WordOccurrence>,
    results[2] as Furuq?,
  );
});

// ── Comparison (keyed by "rootA|rootB") ───────────────────
final comparisonProvider = FutureProvider.family<Furuq?, String>((ref, key) async {
  final parts = key.split('|');
  return ref.watch(repositoryProvider).verifiedFuruqPair(parts.first, parts.last);
});

// ── All occurrences grouped by surah (keyed by rootId) ────
class VerseListData {
  final Root root;
  final List<SurahGroup> groups;
  const VerseListData(this.root, this.groups);
  int get total => groups.fold(0, (s, g) => s + g.items.length);
  int get surahCount => groups.length;
}

final verseListProvider =
    FutureProvider.family<VerseListData?, int>((ref, rootId) async {
  final repo = ref.watch(repositoryProvider);
  final root = await repo.rootById(rootId);
  if (root == null) return null;
  final groups = await repo.occurrencesBySurah(rootId);
  return VerseListData(root, groups);
});
