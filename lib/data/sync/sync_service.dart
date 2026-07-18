import 'package:cloud_firestore/cloud_firestore.dart';

/// Syncs only lightweight USER STATE (not the dictionary) so the app stays
/// fully usable offline. v1 payload: the set of hidden source names. Extend the
/// map with theme, bookmarks, recent searches as those features grow.
class SyncService {
  SyncService(this.ready);
  final bool ready;

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  Future<void> push({
    required String uid,
    required Set<String> hiddenSources,
  }) async {
    if (!ready) return;
    await _users.doc(uid).set({
      'hiddenSources': hiddenSources.toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Returns the remote hidden-sources set, or null if the user has no doc yet.
  Future<Set<String>?> pullHiddenSources(String uid) async {
    if (!ready) return null;
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    final list = (doc.data()?['hiddenSources'] as List?)?.cast<String>();
    return list?.toSet();
  }
}
