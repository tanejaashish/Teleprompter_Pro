class SocialLoginScreen extends StatelessWidget {
  final OAuthService _oauthService = OAuthService();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome to TelePrompt Pro',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 32),
              
              // Google Sign In
              ElevatedButton.icon(
                onPressed: () => _signInWithGoogle(context),
                icon: Image.asset('assets/icons/google.png', height: 24),
                label: Text('Continue with Google'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              
              SizedBox(height: 12),
              
              // Apple Sign In
              if (Platform.isIOS || Platform.isMacOS)
                SignInWithAppleButton(
                  onPressed: () => _signInWithApple(context),
                  height: 50,
                ),
              
              SizedBox(height: 12),
              
              // Facebook Sign In
              ElevatedButton.icon(
                onPressed: () => _signInWithFacebook(context),
                icon: Icon(Icons.facebook),
                label: Text('Continue with Facebook'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1877F2),
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              
              SizedBox(height: 12),
              
              // Microsoft Sign In
              ElevatedButton.icon(
                onPressed: () => _signInWithMicrosoft(context),
                icon: Image.asset('assets/icons/microsoft.png', height: 24),
                label: Text('Continue with Microsoft'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              
              SizedBox(height: 24),
              
              // Traditional login link
              TextButton(
                onPressed: () => _showEmailLogin(context),
                child: Text('Sign in with email'),
              ),
              
              // Privacy policy
              SizedBox(height: 16),
              Text(
                'By continuing, you agree to our Terms of Service and Privacy Policy',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final result = await _oauthService.signInWithGoogle();
      await _handleAuthSuccess(context, result);
    } catch (e) {
      _showError(context, 'Google sign in failed');
    }
  }
  
  Future<void> _handleAuthSuccess(BuildContext context, AuthResult result) async {
    // Store tokens
    await SecureStorage.setTokens(result.tokens);
    
    // Update user state
    context.read<AuthProvider>().setUser(result.user);
    
    // Navigate to main app
    Navigator.of(context).pushReplacementNamed('/dashboard');
  }
}