import 'package:firebase_core/firebase_core.dart';

/// iOS Firebase client configuration.
///
/// **Why this exists instead of a GoogleService-Info.plist.**
/// On Android the config is a committed `google-services.json` that the Gradle
/// plugin picks up. The iOS equivalent has to be added to the Xcode project as a
/// bundle resource, which cannot be done from Windows — this project has no Mac.
/// Passing the same values to `Firebase.initializeApp(options:)` is equivalent
/// and needs no Xcode change at all.
///
/// These are **not secrets**. They are the same class of client identifiers as
/// the `google-services.json` that is already committed for Android; Firebase
/// access is controlled by security rules and by the server's service account,
/// never by these.
///
/// ---------------------------------------------------------------------------
/// ## TO FILL THIS IN (5 minutes, one time)
///
/// 1. Firebase console → project **wiinz-app** → Project settings → *Your apps*
///    → **Add app → iOS**.
/// 2. Apple bundle ID: **com.wiinalgeria.wiinz** (must match exactly — it is not
///    the Android package name; see the bundle-id note in HANDOFF-CURRENT.md).
///    App nickname "WIIN iOS". App Store ID can be left blank.
/// 3. Download **GoogleService-Info.plist** and copy the four values below out of
///    it. Do NOT bother adding the file to Xcode — that is the step this file
///    replaces.
///
///        API_KEY          -> _apiKey
///        GOOGLE_APP_ID    -> _appId       (looks like 1:736202502215:ios:…)
///        GCM_SENDER_ID    -> _senderId    (736202502215)
///        PROJECT_ID       -> _projectId   (wiinz-app)
///
/// 4. While in the console: **Project settings → Cloud Messaging → APNs
///    authentication key** → upload the `.p8` key from the Apple Developer
///    portal (Keys → + → Apple Push Notifications service). Without that key
///    Firebase cannot deliver to iOS at all, no matter what is set here.
///
/// Until step 3 is done these stay empty, `iosFirebaseOptions()` returns null,
/// and `initPush()` simply skips Firebase on iOS: the app runs normally, just
/// with no push. Nothing else breaks.
/// ---------------------------------------------------------------------------

const _apiKey = '';
const _appId = '';
const _senderId = '736202502215'; // same Firebase project as Android
const _projectId = 'wiinz-app';

/// The iOS Firebase options, or null while the config above is unfilled.
FirebaseOptions? iosFirebaseOptions() {
  if (_apiKey.isEmpty || _appId.isEmpty) return null;
  return const FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _senderId,
    projectId: _projectId,
  );
}
