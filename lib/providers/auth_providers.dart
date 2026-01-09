// lib/providers/auth_providers.dart - Complete Fixed Version
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../core/network/api_client.dart';
import '../core/utils/result.dart';
import '../data/models/user_model.dart';
import 'api_providers.dart';
import 'tenant_providers.dart';

// Auth State
class AuthState {
  final bool? isAuth;
  final UserModel? user;
  final String? token;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  AuthState({
    this.isAuth,
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  AuthState copyWith({
    bool? isAuth,
    UserModel? user,
    String? token,
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return AuthState(
      isAuth: isAuth ?? this.isAuth,
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthService(apiClient: apiClient);
});

// Auth State Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final StorageService _storageService;
  final ApiClient _apiClient;

  AuthNotifier(this._authService, this._storageService, this._apiClient)
      : super(AuthState()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    state = state.copyWith(isLoading: true);

    final token = await _storageService.getToken();
    if (token != null) {
      _apiClient.setAuthToken(token);
      final result = await _authService.checkAuth();

      if (result is Success<UserModel>) {
        state = state.copyWith(
          isAuth: true,
          user: result.data,
          token: token,
          isLoading: false,
        );
      } else {
        // Token is invalid, clear it but keep remember me if enabled
        await _storageService.saveToken('');
        state = state.copyWith(
          isAuth: false,
          isLoading: false,
        );
      }
    } else {
      // Try auto-login if remember me is enabled
      final rememberMe = await _storageService.getRememberMe();
      if (rememberMe) {
        final savedIdentifier = await _storageService.getSavedIdentifier();
        final savedPassword = await _storageService.getSavedPassword();

        if (savedIdentifier != null && savedPassword != null) {
          // Auto-login with saved credentials (email or phone)
          final isEmail = savedIdentifier.contains('@');
          await login(
            email: isEmail ? savedIdentifier : null,
            phone: isEmail ? null : savedIdentifier,
            password: savedPassword,
            rememberMe: true,
          );
          return;
        }
      }

      state = state.copyWith(
        isAuth: false,
        isLoading: false,
      );
    }
  }

  Future<void> login({
    String? email,
    String? phone,
    required String password,
    bool rememberMe = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.login(
      email: email,
      phone: phone,
      password: password,
    );

    if (result is Success<Map<String, dynamic>>) {
      final data = result.data;
      final token = data['token'] as String?;
      final userData = data['user'] as Map<String, dynamic>?;

      if (token != null && userData != null) {
        await _storageService.saveToken(token);
        _apiClient.setAuthToken(token);

        // Save remember me credentials with whichever identifier was used
        final identifier = email ?? phone ?? '';
        await _storageService.saveRememberMe(rememberMe, identifier, password);

        final user = UserModel.fromJson(userData);
        state = state.copyWith(
          isAuth: true,
          user: user,
          token: token,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid response from server',
        );
      }
    } else {
      state = state.copyWith(
        isLoading: false,
        error: (result as Failure).message,
      );
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
    String? address,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      phone: phone,
      address: address,
    );

    if (result is Success<Map<String, dynamic>>) {
      final data = result.data;
      final token = data['token'] as String?;
      final userData = data['user'] as Map<String, dynamic>?;

      if (token != null) {
        await _storageService.saveToken(token);
        _apiClient.setAuthToken(token);
      }

      if (userData != null) {
        final user = UserModel.fromJson(userData);
        state = state.copyWith(
          isAuth: true,
          user: user,
          token: token,
          isLoading: false,
          successMessage: 'Registration successful!',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Registration successful! Please login.',
        );
      }
    } else {
      state = state.copyWith(
        isLoading: false,
        error: (result as Failure).message,
      );
    }
  }

  Future<void> registerWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Use Firebase Auth for Google Sign-In
      // Firebase Auth automatically handles OAuth using google-services.json
      // Uses the web client ID from google-services.json automatically
      final FirebaseAuth auth = FirebaseAuth.instance;

      // Create Google Sign-In instance - Firebase will use google-services.json config
      // No need to specify serverClientId - Firebase handles it automatically
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        state = state.copyWith(
          isLoading: false,
          error: 'Google sign-in was cancelled',
        );
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential =
          await auth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to authenticate with Google. Please try again.',
        );
        return;
      }

      // Extract user data from Firebase Auth
      final String name =
          firebaseUser.displayName ?? googleUser.displayName ?? '';
      final String email = firebaseUser.email ?? '';
      final String picture = firebaseUser.photoURL ?? googleUser.photoUrl ?? '';

      // Validate that we have at least email
      if (email.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to get email from Google account. Please try again.',
        );
        // Sign out from Firebase if we can't proceed
        await auth.signOut();
        await googleSignIn.signOut();
        return;
      }

      // Register user with Google data in your backend
      final result = await _authService.register(
        name: name,
        email: email,
        password: 'googleauth',
        passwordConfirmation: 'googleauth',
        additionalData: {
          'profile_photo_path': picture,
          'loginbygoogle': true,
        },
      );

      if (result is Success<Map<String, dynamic>>) {
        final data = result.data;
        final token = data['token'] as String?;
        final userData = data['user'] as Map<String, dynamic>?;

        if (token != null) {
          await _storageService.saveToken(token);
          _apiClient.setAuthToken(token);
        }

        if (userData != null) {
          final user = UserModel.fromJson(userData);
          state = state.copyWith(
            isAuth: true,
            user: user,
            token: token,
            isLoading: false,
            successMessage: 'Google sign-in successful!',
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            successMessage: 'Registration successful! Please login.',
          );
        }
      } else {
        state = state.copyWith(
          isLoading: false,
          error: (result as Failure).message,
        );
        // Sign out from Firebase if backend registration fails
        await auth.signOut();
        await googleSignIn.signOut();
      }
    } catch (e) {
      // Provide more specific error messages
      String errorMessage = 'Google sign-in failed';

      final errorString = e.toString().toLowerCase();

      if (errorString.contains('network_error') ||
          errorString.contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (errorString.contains('sign_in_canceled') ||
          errorString.contains('cancelled')) {
        errorMessage = 'Google sign-in was cancelled';
      } else if (errorString
          .contains('account_exists_with_different_credential')) {
        errorMessage =
            'An account already exists with this email. Please use a different sign-in method.';
      } else {
        errorMessage = 'Google sign-in failed: ${e.toString()}';
      }

      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );

      // Clean up Firebase auth state on error
      try {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn().signOut();
      } catch (_) {
        // Ignore cleanup errors
      }
    }
  }

  Future<void> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.forgotPassword(email);

    if (result is Success<String>) {
      state = state.copyWith(
        isLoading: false,
        successMessage: result.data,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: (result as Failure).message,
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Try to logout from server, but don't fail if it doesn't work
      final result = await _authService.logout();

      // Clear auth-related data but preserve tenant selection
      await _storageService.saveToken('');
      await _storageService.clearRememberMe();
      _apiClient.setAuthToken(null);

      state = AuthState(
        isAuth: false,
        isLoading: false,
        successMessage: result is Success<String> ? (result).data : null,
      );
    } catch (e) {
      // Even if API call fails, clear local state
      await _storageService.saveToken('');
      await _storageService.clearRememberMe();
      _apiClient.setAuthToken(null);

      state = AuthState(
        isAuth: false,
        isLoading: false,
        error: null, // Don't show error to user, just logout locally
      );
    }
  }

  void resetError() {
    state = state.copyWith(error: null);
  }

  void resetSuccessMessage() {
    state = state.copyWith(successMessage: null);
  }
}

// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  final apiClient = ref.watch(apiClientProvider);

  return AuthNotifier(authService, storageService, apiClient);
});
