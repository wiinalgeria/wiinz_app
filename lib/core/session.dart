import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import '../models/models.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class SessionState {
  final bool loading;
  final bool checkingSession;
  final WiinzUser? user;
  final AppConfig config;

  SessionState({this.loading = false, this.checkingSession = true, this.user, AppConfig? config})
      : config = config ?? AppConfig.fallback();

  SessionState copyWith({bool? loading, bool? checkingSession, WiinzUser? user, AppConfig? config}) => SessionState(
        loading: loading ?? this.loading,
        checkingSession: checkingSession ?? this.checkingSession,
        user: user ?? this.user,
        config: config ?? this.config,
      );

  bool get isLoggedIn => user != null;
}

class SessionNotifier extends Notifier<SessionState> {
  static const _tokenKey = 'wiinz_token';
  static const _userKey = 'wiinz_user'; // cached profile JSON for instant/offline restore
  ApiClient get api => ref.read(apiClientProvider);

  Future<void> _cacheUser(Map<String, dynamic> userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(userJson));
  }

  // One-shot flag: true right after a fresh signup, so home can show a welcome
  // popup once. Read it via [consumeJustSignedUp] (self-clearing).
  bool _justSignedUp = false;
  bool consumeJustSignedUp() {
    final v = _justSignedUp;
    _justSignedUp = false;
    return v;
  }

  // One-shot: true when a user logged in / opened the app with a temporary
  // (admin-reset) password still active, so home can nudge them to change it.
  bool _tempPwPrompt = false;
  bool consumeTempPwPrompt() {
    final v = _tempPwPrompt;
    _tempPwPrompt = false;
    return v;
  }

  // One-shot: true when the user just entered the app (login / signup / restored
  // session) so home can show the promotional popup once.
  bool _promoPending = false;
  bool consumePromo() {
    final v = _promoPending;
    _promoPending = false;
    return v;
  }

  @override
  SessionState build() {
    _restore();
    return SessionState();
  }

  Future<void> _restore() async {
    api.warmUp(); // start waking the (possibly sleeping) Render instance immediately
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final config = await api.config();
    if (token == null) {
      state = state.copyWith(checkingSession: false, config: config);
      return;
    }
    api.token = token;
    try {
      final res = await api.me();
      _tempPwPrompt = WiinzUser.fromJson(res['user']).tempPassword;
      _promoPending = true;
      await _cacheUser(res['user']);
      state = state.copyWith(user: WiinzUser.fromJson(res['user']), checkingSession: false, config: config);
    } on ApiException catch (e) {
      // A connectivity/cold-start failure must NOT log the user out. If we have a
      // cached profile, go straight into the app and refresh in the background.
      final cached = prefs.getString(_userKey);
      if (e.network && cached != null) {
        _promoPending = true;
        final u = WiinzUser.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        _tempPwPrompt = u.tempPassword;
        state = state.copyWith(user: u, checkingSession: false, config: config);
        refreshMe(); // fire-and-forget; updates once the server is awake
        return;
      }
      if (e.network) {
        // No cache but transient network error: keep the token, let them retry later.
        state = state.copyWith(checkingSession: false, config: config);
        return;
      }
      // Real auth error (expired/invalid token): clear the session.
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      api.token = null;
      state = state.copyWith(checkingSession: false, config: config);
    } catch (_) {
      // Unexpected non-API error: fail safe to logged-out without wiping the token.
      state = state.copyWith(checkingSession: false, config: config);
    }
  }

  Future<ApiException?> login(String identifier, String password) async {
    state = state.copyWith(loading: true);
    try {
      final res = await api.login(identifier, password);
      await _persist(res);
      return null;
    } on ApiException catch (e) {
      return e;
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<String?> signup(Map<String, dynamic> data) async {
    state = state.copyWith(loading: true);
    try {
      final res = await api.signup(data);
      await _persist(res);
      _justSignedUp = true;
      return null;
    } on ApiException catch (e) {
      return e.message;
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> _persist(Map<String, dynamic> res) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, res['token']);
    await prefs.setString(_userKey, jsonEncode(res['user']));
    api.token = res['token'];
    final u = WiinzUser.fromJson(res['user']);
    _tempPwPrompt = u.tempPassword;
    _promoPending = true;
    state = state.copyWith(user: u);
  }

  void setUser(WiinzUser u) => state = state.copyWith(user: u);
  void setPoints(int points) {
    if (state.user != null) state = state.copyWith(user: state.user!.copyWith(points: points));
  }

  void setVideosLeft(int n) {
    if (state.user != null) state = state.copyWith(user: state.user!.copyWith(videosLeft: n));
  }

  Future<void> refreshMe() async {
    try {
      final res = await api.me();
      await _cacheUser(res['user']);
      state = state.copyWith(user: WiinzUser.fromJson(res['user']));
    } catch (_) {}
  }

  Future<String?> saveProfile(Map<String, dynamic> patch) async {
    try {
      final res = await api.updateMe(patch);
      await _cacheUser(res['user']);
      state = state.copyWith(user: WiinzUser.fromJson(res['user']));
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    api.token = null;
    state = SessionState(checkingSession: false, config: state.config);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
