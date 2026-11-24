/// Sign in with Apple: the code is done, but it needs a paid Apple
/// Developer Program membership (the capability isn't available to a free
/// Personal Team), and the App Store only requires it once the app is
/// submitted. Until then the button stays hidden.
///
/// To turn it on (after enrolling):
///  1. Set this to true.
///  2. Add `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` back to
///     the Runner target's Debug, Release and Profile build settings in
///     ios/Runner.xcodeproj/project.pbxproj (the file is already there).
///  3. Apple Developer: enable "Sign In with Apple" on the App ID
///     com.pattarapon.giveAndTake.
///  4. Firebase Console: Authentication > Sign-in method > Apple > Enable,
///     plus the OAuth code flow key (Team ID, Key ID, .p8) so deleting an
///     account can revoke the Apple token.
const bool kAppleSignInEnabled = false;
