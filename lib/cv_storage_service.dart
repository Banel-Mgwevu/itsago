import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'ats_scoring_service.dart';

// ─────────────────────────────────────────────────────────────
//  CVStorageService — POPIA Compliant
//
//  Data processing basis: Legitimate interest + explicit consent
//  Purpose: ATS CV optimisation and retrieval by the data subject
//  Retention: 30 days from creation (configurable)
//  Third-party processors: Anthropic (Claude API) — transient only
//  Subject rights: access, download, delete (see methods below)
//  Responsible party: ITSAGO (Pty) Ltd
// ─────────────────────────────────────────────────────────────

class CVStorageService {

  static const _retentionDays      = 30;
  static const _consentKey         = 'cv_storage_consent_v1';
  static const _consentTimestampKey= 'cv_storage_consent_ts';

  static FirebaseFirestore get _db  => FirebaseFirestore.instance;
  static FirebaseStorage   get _st  => FirebaseStorage.instance;
  static String?           get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Consent management ───────────────────────────────────────

  static Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  }

  /// Records explicit POPIA consent with timestamp for audit trail.
  static Future<void> recordConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, true);
    await prefs.setString(_consentTimestampKey,
      DateTime.now().toIso8601String());
    // Also record in Firestore for server-side audit
    final uid = _uid;
    if (uid != null) {
      await _db.collection('users').doc(uid)
        .set({'cvStorageConsent': true,
              'cvStorageConsentTimestamp': FieldValue.serverTimestamp(),
              'cvStorageConsentVersion': 'v1'},
          SetOptions(merge: true));
    }
  }

  /// Revokes consent and triggers deletion of all CV data.
  static Future<void> revokeConsent() async {
    await deleteAllCVs();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, false);
    final uid = _uid;
    if (uid != null) {
      await _db.collection('users').doc(uid)
        .set({'cvStorageConsent': false,
              'cvStorageConsentRevokedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
    }
  }

  // ── Save CV record ───────────────────────────────────────────

  static Future<String?> saveCVRecord({
    required String       company,
    required String       jobTitle,
    required ATSScore     beforeScore,
    required ATSScore     afterScore,
    required Uint8List?   originalPdfBytes,
    required Uint8List?   optimisedPdfBytes,
    required Uint8List?   optimisedDocxBytes,
    int                   designIndex = 0,
    String                cvName      = '',
    String                cvHeadline  = '',
    List<String>          cvSkills    = const [],
    String                cvSummary   = '',
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    if (!await hasConsent()) return null;

    try {
      // Create Firestore record first to get ID
      // NOTE: Raw CV text is NEVER stored in Firestore — data minimisation
      final docRef = await _db
        .collection('users').doc(uid)
        .collection('cvs').add({
          'company':          company,
          'jobTitle':         jobTitle,
          'timestamp':        FieldValue.serverTimestamp(),
          'retentionExpiry':  Timestamp.fromDate(
            DateTime.now().add(const Duration(days: _retentionDays))),
          'beforeScore':      beforeScore.toJson(),
          'afterScore':       afterScore.toJson(),
          // POPIA metadata
          'dataSubjectUid':   uid,
          'processingPurpose':'ats_optimisation',
          'thirdPartyProcessors': ['anthropic_claude_api'],
          'dataMinimised':    true,
          'designIndex':      designIndex,
          'cvName':           cvName,
          'cvHeadline':       cvHeadline,
          'cvSkills':         cvSkills,
          'cvSummary':        cvSummary,
        });

      final cvId = docRef.id;
      final base = 'users/$uid/cvs/$cvId';

      // Upload files to Firebase Storage
      final uploads = <Future>[];
      if (originalPdfBytes != null) {
        uploads.add(_upload('$base/original.pdf',
          originalPdfBytes, 'application/pdf'));
      }
      if (optimisedPdfBytes != null) {
        uploads.add(_upload('$base/optimised.pdf',
          optimisedPdfBytes, 'application/pdf'));
      }
      if (optimisedDocxBytes != null) {
        uploads.add(_upload('$base/optimised.docx', optimisedDocxBytes,
          'application/vnd.openxmlformats-officedocument'
          '.wordprocessingml.document'));
      }
      await Future.wait(uploads);
      return cvId;
    } catch (_) { return null; }
  }

  static Future<void> _upload(
      String path, Uint8List bytes, String mime) async {
    await _st.ref(path).putData(bytes,
      SettableMetadata(contentType: mime));
  }

  // ── Retrieve records ─────────────────────────────────────────

  static Future<List<CVRecord>> getCVs() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap = await _db
        .collection('users').doc(uid)
        .collection('cvs')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();
      return snap.docs.map((d) => CVRecord.fromDoc(d)).toList();
    } catch (_) { return []; }
  }

  static Future<String?> getDownloadUrl(
      String cvId, CVFileType type) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final path = 'users/$uid/cvs/$cvId/${type.filename}';
      return await _st.ref(path).getDownloadURL();
    } catch (_) { return null; }
  }

  // ── Delete (right to erasure — POPIA s.24) ───────────────────

  static Future<void> deleteCVRecord(String cvId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      // Delete Storage files
      final base = 'users/$uid/cvs/$cvId';
      for (final f in ['original.pdf','optimised.pdf','optimised.docx']) {
        try { await _st.ref('$base/$f').delete(); } catch (_) {}
      }
      // Delete Firestore record
      await _db.collection('users').doc(uid)
        .collection('cvs').doc(cvId).delete();
    } catch (_) {}
  }

  /// Deletes ALL CV records for this user.
  /// Implements POPIA right to be forgotten (s.24).
  static Future<void> deleteAllCVs() async {
    final uid = _uid;
    if (uid == null) return;
    final cvs = await getCVs();
    await Future.wait(cvs.map((cv) => deleteCVRecord(cv.id)));
  }

  /// Purge CVs past their retention date. Call on app start.
  static Future<void> purgeExpired() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final snap = await _db
        .collection('users').doc(uid)
        .collection('cvs')
        .where('retentionExpiry',
          isLessThan: Timestamp.fromDate(DateTime.now()))
        .get();
      await Future.wait(snap.docs.map((d) => deleteCVRecord(d.id)));
    } catch (_) {}
  }
}

enum CVFileType {
  original('original.pdf'),
  optimisedPdf('optimised.pdf'),
  optimisedDocx('optimised.docx');
  final String filename;
  const CVFileType(this.filename);
}

class CVRecord {
  final String    id;
  final String    company;
  final String    jobTitle;
  final DateTime? timestamp;
  final ATSScore  beforeScore;
  final ATSScore  afterScore;
  final DateTime? retentionExpiry;
  final int       designIndex;
  final String    cvName;
  final String    cvHeadline;
  final List<String> cvSkills;
  final String    cvSummary;

  const CVRecord({
    required this.id,
    required this.company,
    required this.jobTitle,
    required this.timestamp,
    required this.beforeScore,
    required this.afterScore,
    required this.retentionExpiry,
    this.designIndex = 0,
    this.cvName      = '',
    this.cvHeadline  = '',
    this.cvSkills    = const [],
    this.cvSummary   = '',
  });

  factory CVRecord.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CVRecord(
      id:       doc.id,
      company:  d['company']  as String? ?? '',
      jobTitle: d['jobTitle'] as String? ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate(),
      retentionExpiry:
        (d['retentionExpiry'] as Timestamp?)?.toDate(),
      beforeScore: d['beforeScore'] != null
        ? ATSScore.fromJson(d['beforeScore'] as Map<String, dynamic>)
        : ATSScore.failed(),
      afterScore: d['afterScore'] != null
        ? ATSScore.fromJson(d['afterScore'] as Map<String, dynamic>)
        : ATSScore.failed(),
      designIndex: d['designIndex'] as int?    ?? 0,
      cvName:      d['cvName']      as String? ?? '',
      cvHeadline:  d['cvHeadline']  as String? ?? '',
      cvSkills:    (d['cvSkills']   as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      cvSummary:   d['cvSummary']   as String? ?? '',
    );
  }

  int get improvement => afterScore.score - beforeScore.score;
}

