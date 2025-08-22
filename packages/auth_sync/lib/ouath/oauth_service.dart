import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

class OAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/drive.file', // For backup
    ],
  );
  
  final FlutterAppAuth _appAuth = FlutterAppAuth();
  
  // Google Sign In
  Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw AuthCancelledException();
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Send tokens to backend
      final response = await _backend.authenticateWithGoogle(
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );
      
      return AuthResult(
        user: User(
          id: response.userId,
          email: googleUser.email,
          name: googleUser.displayName,
          photoUrl: googleUser.photoUrl,
          provider: AuthProvider.google,
        ),
        tokens: Tokens(
          access: response.accessToken,
          refresh: response.refreshToken,
          idToken: googleAuth.idToken,
        ),
      );
    } catch (e) {
      throw AuthException('Google sign in failed: $e');
    }
  }
  
  // Apple Sign In
  Future<AuthResult> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'com.teleprompt.pro',
          redirectUri: Uri.parse('https://teleprompt.pro/auth/apple/callback'),
        ),
      );
      
      // Send to backend
      final response = await _backend.authenticateWithApple(
        identityToken: credential.identityToken!,
        authorizationCode: credential.authorizationCode,
        user: credential.givenName != null ? {
          'firstName': credential.givenName,
          'lastName': credential.familyName,
          'email': credential.email,
        } : null,
      );
      
      return AuthResult(
        user: User(
          id: response.userId,
          email: credential.email ?? response.email,
          name: '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim(),
          provider: AuthProvider.apple,
        ),
        tokens: Tokens(
          access: response.accessToken,
          refresh: response.refreshToken,
        ),
      );
    } catch (e) {
      throw AuthException('Apple sign in failed: $e');
    }
  }
  
  // Facebook Sign In
  Future<AuthResult> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );
      
      if (result.status != LoginStatus.success) {
        throw AuthException('Facebook login failed: ${result.status}');
      }
      
      final AccessToken accessToken = result.accessToken!;
      final userData = await FacebookAuth.instance.getUserData();
      
      // Send to backend
      final response = await _backend.authenticateWithFacebook(
        accessToken: accessToken.token,
      );
      
      return AuthResult(
        user: User(
          id: response.userId,
          email: userData['email'],
          name: userData['name'],
          photoUrl: userData['picture']['data']['url'],
          provider: AuthProvider.facebook,
        ),
        tokens: Tokens(
          access: response.accessToken,
          refresh: response.refreshToken,
        ),
      );
    } catch (e) {
      throw AuthException('Facebook sign in failed: $e');
    }
  }
  
  // Microsoft Sign In
  Future<AuthResult> signInWithMicrosoft() async {
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          'YOUR_CLIENT_ID',
          'com.teleprompt.pro://auth',
          discoveryUrl: 'https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration',
          scopes: ['openid', 'profile', 'email', 'offline_access'],
        ),
      );
      
      if (result == null) throw AuthCancelledException();
      
      // Send to backend
      final response = await _backend.authenticateWithMicrosoft(
        idToken: result.idToken!,
        accessToken: result.accessToken!,
      );
      
      return AuthResult(
        user: User.fromIdToken(result.idToken!),
        tokens: Tokens(
          access: response.accessToken,
          refresh: response.refreshToken,
        ),
      );
    } catch (e) {
      throw AuthException('Microsoft sign in failed: $e');
    }
  }
  
  // LinkedIn Sign In
  Future<AuthResult> signInWithLinkedIn() async {
    // Implementation similar to Microsoft
  }
  
  // Twitter Sign In
  Future<AuthResult> signInWithTwitter() async {
    // Implementation
  }
}