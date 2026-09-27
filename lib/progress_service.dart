import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProgressService {
  static FirebaseFirestore get _db  => FirebaseFirestore.instance;
  static String?           get _uid => FirebaseAuth.instance.currentUser?.uid;

  static Future<void> saveSession({
    required String company,
    required String jobTitle,
    required List<Map<String, dynamic>> results,
    required Map<String, dynamic>? aiFeedback,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    // Answers that couldn't be scored are left out of the average.
    final confs    = results
      .where((r) => r['scored'] != false)
      .map((r) => (r['confidence'] as num).toDouble()).toList();
    final avgConf  = confs.isEmpty ? 0.0
      : confs.reduce((a, b) => a + b) / confs.length;
    final fillers  = results.fold<int>(0,
      (s, r) => s + (r['fillerWords'] as List).length);
    final words    = results.fold<int>(0,
      (s, r) => s + (r['wordCount'] as int));
    final wps      = results.fold<double>(0.0,
      (s, r) => s + (r['wordsPerSecond'] as num).toDouble()) / results.length;

    await _db.collection('users').doc(uid)
      .collection('sessions').add({
        'timestamp':         FieldValue.serverTimestamp(),
        'company':           company,
        'jobTitle':          jobTitle,
        'overallConfidence': avgConf,
        'totalFillers':      fillers,
        'totalWords':        words,
        'avgWordsPerSecond': wps,
        'questionCount':     results.length,
        'topStrength':       aiFeedback?['topStrength']    ?? '',
        'topImprovement':    aiFeedback?['topImprovement'] ?? '',
        'questions': results.map((r) => {
          'q':           r['question'],
          'confidence':  r['scored'] == false ? null : r['confidence'],
          'scored':      r['scored'] != false,
          'fillers':     (r['fillerWords'] as List).length,
          'words':       r['wordCount'],
          'sentiment':   r['sentiment'],
        }).toList(),
      });
  }

  static Future<List<Map<String, dynamic>>> getSessions({int limit = 30}) async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap = await _db.collection('users').doc(uid)
        .collection('sessions')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) { return []; }
  }

  static Future<Map<String, dynamic>> getStats() async {
    final sessions = await getSessions(limit: 30);
    if (sessions.isEmpty) {
      return {'total': 0, 'avgConf': 0.0, 'best': 0.0, 'trend': <double>[]};
    }
    final confs  = sessions
      .map((s) => (s['overallConfidence'] as num).toDouble())
      .toList();
    final avg    = confs.reduce((a, b) => a + b) / confs.length;
    final best   = confs.reduce((a, b) => a > b ? a : b);
    final trend  = confs.reversed.take(10).toList();
    final fillers= sessions
      .map((s) => (s['totalFillers'] as num).toInt())
      .toList();
    final avgF   = fillers.isEmpty ? 0.0
      : fillers.reduce((a, b) => a + b) / fillers.length;
    return {
      'total':   sessions.length,
      'avgConf': avg,
      'best':    best,
      'trend':   trend,
      'avgFillers': avgF,
      'sessions': sessions.take(5).toList(),
    };
  }
}
