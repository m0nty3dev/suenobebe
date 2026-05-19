import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/app_user.dart';
import '../../../core/config/constants.dart';
import '../../../core/services/analytics/analytics_service.dart';
import '../../../core/services/notifications/notification_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

class AuthRepository {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn(
    clientId: AppConstants.googleWebClientId,
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Google Sign-In cancelled');
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    await _ensureUserDocument(result.user!, method: 'google');
    await NotificationService.persistToken(result.user!.uid);
    AnalyticsService.logLogin('google');
    return result;
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _ensureUserDocument(result.user!, method: 'email');
    await NotificationService.persistToken(result.user!.uid);
    AnalyticsService.logLogin('email');
    return result;
  }

  Future<UserCredential> createUserWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await result.user!.updateDisplayName(displayName);
    await _ensureUserDocument(result.user!, method: 'email', isNew: true);
    await NotificationService.persistToken(result.user!.uid);
    AnalyticsService.logSignUp('email');
    return result;
  }

  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) await NotificationService.removeToken(uid);
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<AppUser?> fetchUserDocument(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }

  Stream<AppUser?> watchUserDocument(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
  }

  Future<void> updateUserDocument(String userId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('users').doc(userId).update(data);
  }

  Future<void> _ensureUserDocument(
    User user, {
    required String method,
    bool isNew = false,
  }) async {
    final ref = _firestore.collection('users').doc(user.uid);
    // Transaction makes the check-then-create atomic, preventing duplicate
    // documents when two login flows run concurrently for the same uid.
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'email': user.email ?? '',
          'displayName': user.displayName ?? '',
          'photoUrl': user.photoURL,
          'locale': 'es',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'legalAccepted': null,
          'currentBabyId': null,
          'fcmTokens': {},
        });
      }
    });
  }
}
