import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  AppUser? _user;
  bool _loading = false;
  bool _needsRegistration = false;
  String? _verifiedPhone;
  String? _verificationId;

  AppUser? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  bool get needsRegistration => _needsRegistration;
  String? get verifiedPhone => _verifiedPhone;

  bool get isAdmin => _user?.role == UserRole.admin;
  bool get isFirma => _user?.role == UserRole.firma;
  bool get isSurucu => _user?.role == UserRole.surucu;
  bool get isUretici => _user?.role == UserRole.uretici;

  Future<void> loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserJson = prefs.getString('saved_user');
      if (savedUserJson != null) {
        final Map<String, dynamic> userMap = jsonDecode(savedUserJson);
        final uid = userMap['uid'] as String;
        _user = AppUser.fromMap(uid, userMap);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load saved user session: $e');
    }
  }

  Future<void> _persistUser(AppUser? user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (user != null) {
        final userMap = user.toMap();
        userMap['uid'] = user.uid;
        await prefs.setString('saved_user', jsonEncode(userMap));
      } else {
        await prefs.remove('saved_user');
      }
    } catch (e) {
      debugPrint('Failed to persist user session: $e');
    }
  }

  AuthProvider() {
    loadSavedSession();
    // Listen to Firebase Auth state changes
    _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        _loading = true;
        notifyListeners();
        
        final profile = await _firestoreService.getUserProfile(firebaseUser.uid);
        if (profile != null) {
          _user = AppUser.fromMap(firebaseUser.uid, profile);
          await _persistUser(_user);
          _needsRegistration = false;
          _verifiedPhone = null;
        } else {
          final rawPhone = firebaseUser.phoneNumber ?? '';
          if (rawPhone.isNotEmpty) {
            // 1. Check matching company (firma)
            final firmalarSnap = await FirebaseFirestore.instance.collection('firmalar').get();
            DocumentSnapshot? matchedFirma;
            for (var doc in firmalarSnap.docs) {
              final tel = doc['tel'] as String? ?? '';
              if (comparePhoneNumbers(tel, rawPhone)) {
                matchedFirma = doc;
                break;
              }
            }

            if (matchedFirma != null) {
              final fData = matchedFirma.data() as Map<String, dynamic>;
              final String firmaName = fData['ad'] ?? '';
              final String yetkiliName = fData['yetkili'] ?? '';
              final String adres = fData['adres'] ?? '';

              final Map<String, dynamic> userData = {
                'displayName': yetkiliName,
                'name': yetkiliName,
                'email': '',
                'role': 'firma',
                'phone': rawPhone,
                'il': '',
                'ilce': '',
                'mahalleKoy': '',
                'adresDetay': adres,
                'postaKodu': '',
                'firmaId': matchedFirma.id,
                'firmaName': firmaName,
              };
              await _firestoreService.createUserProfile(firebaseUser.uid, userData);
              _user = AppUser.fromMap(firebaseUser.uid, userData);
              await _persistUser(_user);
              _needsRegistration = false;
              _verifiedPhone = null;
              _loading = false;
              notifyListeners();
              return;
            }

            // 2. Check matching driver (surucu)
            final suruculerSnap = await FirebaseFirestore.instance.collection('suruculer').get();
            DocumentSnapshot? matchedSurucu;
            for (var doc in suruculerSnap.docs) {
              final tel = doc['tel'] as String? ?? '';
              if (comparePhoneNumbers(tel, rawPhone)) {
                matchedSurucu = doc;
                break;
              }
            }

            if (matchedSurucu != null) {
              final dData = matchedSurucu.data() as Map<String, dynamic>;
              final String surucuName = '${dData['ad'] ?? ''} ${dData['soyad'] ?? ''}'.trim();
              final String dFirma = dData['firma'] ?? '';

              final Map<String, dynamic> userData = {
                'displayName': surucuName,
                'name': surucuName,
                'email': dData['email'] ?? '',
                'role': 'surucu',
                'phone': rawPhone,
                'il': '',
                'ilce': '',
                'mahalleKoy': '',
                'adresDetay': '',
                'postaKodu': '',
                'firmaId': '',
                'firmaName': dFirma,
              };
              await _firestoreService.createUserProfile(firebaseUser.uid, userData);
              _user = AppUser.fromMap(firebaseUser.uid, userData);
              await _persistUser(_user);
              _needsRegistration = false;
              _verifiedPhone = null;
              _loading = false;
              notifyListeners();
              return;
            }

            // 3. Check matching producer (uretici)
            final ureticilerSnap = await FirebaseFirestore.instance.collection('ureticiler').get();
            DocumentSnapshot? matchedUretici;
            for (var doc in ureticilerSnap.docs) {
              final tel = doc['phone'] as String? ?? '';
              if (comparePhoneNumbers(tel, rawPhone)) {
                matchedUretici = doc;
                break;
              }
            }

            if (matchedUretici != null) {
              final uData = matchedUretici.data() as Map<String, dynamic>;
              final String ureticiName = uData['name'] ?? '';
              final String bolge = uData['bolge'] ?? '';
              final String group = uData['group'] ?? '';
              final List<dynamic> firmalar = uData['firmalar'] as List? ?? [];
              final String firstFirma = firmalar.isNotEmpty ? firmalar.first.toString() : '';

              final Map<String, dynamic> userData = {
                'displayName': ureticiName,
                'name': ureticiName,
                'email': '',
                'role': 'uretici',
                'phone': rawPhone,
                'il': '',
                'ilce': bolge,
                'mahalleKoy': group,
                'adresDetay': '',
                'postaKodu': '',
                'firmaId': '',
                'firmaName': firstFirma,
              };
              await _firestoreService.createUserProfile(firebaseUser.uid, userData);
              _user = AppUser.fromMap(firebaseUser.uid, userData);
              await _persistUser(_user);
              _needsRegistration = false;
              _verifiedPhone = null;
              _loading = false;
              notifyListeners();
              return;
            }
          }

          // User is logged in via Auth but doesn't have a profile yet (needs registration)
          _user = null;
          await _persistUser(null);
          _needsRegistration = true;
          _verifiedPhone = firebaseUser.phoneNumber;
        }
      } else {
        if (_user == null || !_user!.uid.startsWith('demo_')) {
          _user = null;
          await _persistUser(null);
          _needsRegistration = false;
          _verifiedPhone = null;
        }
      }
      _loading = false;
      notifyListeners();
    });
  }

  /// Verify phone number via SMS
  Future<void> verifyPhone({
    required String phone,
    required Function(String code) onCodeSent,
    required Function(String error) onError,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval (usually Android only)
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _loading = false;
          notifyListeners();
          onError(e.message ?? 'Telefon doğrulaması başarısız oldu.');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _loading = false;
          notifyListeners();
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      _loading = false;
      notifyListeners();
      onError(e.toString());
    }
  }

  /// Sign in with SMS OTP Code
  Future<void> signInWithOTP(String smsCode) async {
    if (_verificationId == null) throw Exception('Doğrulama kodu gönderilmedi.');
    
    _loading = true;
    notifyListeners();

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      await _auth.signInWithCredential(credential);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Complete registration for new users
  Future<void> registerUser({
    required String displayName,
    required String il,
    required String ilce,
    required String mahalleKoy,
    required String adresDetay,
    required String postaKodu,
    String? email,
    String? firmaId,
    String? firmaName,
    UserRole role = UserRole.uretici,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) throw Exception('Kullanıcı oturumu bulunamadı.');

    _loading = true;
    notifyListeners();

    try {
      final Map<String, dynamic> userData = {
        'displayName': displayName,
        'name': displayName,
        'email': email ?? '',
        'role': role.name,
        'phone': firebaseUser.phoneNumber ?? _verifiedPhone ?? '',
        'il': il,
        'ilce': ilce,
        'mahalleKoy': mahalleKoy,
        'adresDetay': adresDetay,
        'postaKodu': postaKodu,
        'firmaId': firmaId ?? '',
        'firmaName': firmaName ?? '',
      };

      await _firestoreService.createUserProfile(firebaseUser.uid, userData);
      
      // Load user profile
      _user = AppUser.fromMap(firebaseUser.uid, userData);
      await _persistUser(_user);
      _needsRegistration = false;
      _verifiedPhone = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Fetch milk collection companies
  Future<List<Map<String, dynamic>>> getCompanies() {
    return _firestoreService.getCompanies();
  }

  /// Demo giriş — test için
  Future<void> demoLogin(UserRole role, {String? customName}) async {
    _loading = true;
    notifyListeners();

    // Simüle edilen yükleme
    await Future.delayed(const Duration(milliseconds: 400));

    final baseUser = AppUser.demo(role);
    _user = AppUser(
      uid: customName != null ? 'demo_${role.name}_${customName.hashCode}' : baseUser.uid,
      displayName: customName ?? baseUser.displayName,
      email: baseUser.email,
      role: role,
      firmaId: baseUser.firmaId,
      phone: baseUser.phone,
      il: baseUser.il,
      ilce: baseUser.ilce,
      mahalleKoy: baseUser.mahalleKoy,
      adresDetay: baseUser.adresDetay,
      postaKodu: baseUser.postaKodu,
    );
    await _persistUser(_user);
    _needsRegistration = false;
    _loading = false;
    notifyListeners();
  }

  /// Update user profile details
  Future<void> updateUserProfile({
    required String displayName,
    required String email,
    required String phone,
    required String il,
    required String ilce,
  }) async {
    if (_user == null) return;
    _loading = true;
    notifyListeners();

    try {
      final updates = {
        'displayName': displayName,
        'name': displayName,
        'email': email,
        'phone': phone,
        'il': il,
        'ilce': ilce,
      };

      // Only update Firestore if it's not a demo user
      if (!_user!.uid.startsWith('demo_')) {
        await _firestoreService.updateUserProfile(_user!.uid, updates);
      }

      // Update local state
      _user = AppUser(
        uid: _user!.uid,
        displayName: displayName,
        email: email,
        role: _user!.role,
        firmaId: _user!.firmaId,
        phone: phone,
        il: il,
        ilce: ilce,
        mahalleKoy: _user!.mahalleKoy,
        adresDetay: _user!.adresDetay,
        postaKodu: _user!.postaKodu,
      );
      await _persistUser(_user);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Çıkış
  Future<void> logout() async {
    _loading = true;
    notifyListeners();
    try {
      await _auth.signOut();
    } catch (_) {}
    _user = null;
    await _persistUser(null);
    _needsRegistration = false;
    _verifiedPhone = null;
    _loading = false;
    notifyListeners();
  }

  bool comparePhoneNumbers(String phone1, String phone2) {
    final digits1 = phone1.replaceAll(RegExp(r'\D'), '');
    final digits2 = phone2.replaceAll(RegExp(r'\D'), '');
    
    if (digits1.length < 10 || digits2.length < 10) {
      return digits1.isNotEmpty && digits1 == digits2;
    }
    
    final last10_1 = digits1.substring(digits1.length - 10);
    final last10_2 = digits2.substring(digits2.length - 10);
    return last10_1 == last10_2;
  }
}

