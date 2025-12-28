import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxibook/services/auth_service.dart';

enum AuthStatus { uninitialized, authenticated, authenticating, unauthenticated }

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  AuthStatus _status = AuthStatus.uninitialized;

  bool _isManualLogin = false;
  String? _manualUserName;
  String? _manualUserEmail;

  AuthProvider() {
    _loadManualUser();
    _authService.user.listen((User? user) {
      if (!_isManualLogin) { // Only update if not manually logged in
        _user = user;
        _status = user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
        notifyListeners();
      }
    });
  }

  User? get user => _user;
  AuthStatus get status => _status;
  bool get isManualLogin => _isManualLogin;
  String? get manualUserName => _manualUserName;
  String? get manualUserEmail => _manualUserEmail;

  Future<void> _loadManualUser() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('manual_email');
    if (email != null) {
      _isManualLogin = true;
      _manualUserEmail = email;
      _manualUserName = prefs.getString('manual_name');
      _status = AuthStatus.authenticated;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    _status = AuthStatus.authenticating;
    notifyListeners();
    User? user = await _authService.signInWithGoogle();
    if (user != null) {
      _user = user;
      _isManualLogin = false;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    }
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    return false;
  }

  Future<void> signInManually({required String name, required String phone, required String email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('manual_name', name);
    await prefs.setString('manual_phone', phone);
    await prefs.setString('manual_email', email);

    _isManualLogin = true;
    _manualUserName = name;
    _manualUserEmail = email;
    _user = null; // Ensure no firebase user is active
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('manual_name');
    await prefs.remove('manual_phone');
    await prefs.remove('manual_email');

    _user = null;
    _isManualLogin = false;
    _manualUserName = null;
    _manualUserEmail = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
