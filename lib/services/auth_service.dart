
// import 'package:campus_marketplace/firebase_options.dart'; // COMMENTED OUT - Google Sign In
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart'; // COMMENTED OUT - Google Sign In

class AuthService {
  AuthService._internal()
      : _auth = FirebaseAuth.instance
      // ========== GOOGLE SIGN IN - COMMENTED OUT ==========
      // , _googleSignIn = GoogleSignIn.instance
      {
    // _googleSignIn.initialize(
    //   clientId: DefaultFirebaseOptions.android.androidClientId,
    //   serverClientId: '16019369694-1rc4jts6gl944cm0tan8508r670b8fsm.apps.googleusercontent.com',
    // );
    // ========== END GOOGLE SIGN IN ==========
  }

  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;

  final FirebaseAuth _auth;
  // final GoogleSignIn _googleSignIn; // COMMENTED OUT - Google Sign In
  
  // Stream for auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  //Sign up with email and password
  Future<UserCredential?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      //TODO: Handle errors: weak password and email already in use
      print(e);
      return null;
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      print(e);
      return null;
    }
  }

  // ========== GOOGLE SIGN IN - COMMENTED OUT ==========
  // // Authenticate with google
  // Future<UserCredential?> signInWithGoogle() async {
  //   try {
  //     // Trigger the authentication flow
  //     final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      
  //     // Obtain the auth details from the request
  //     final GoogleSignInAuthentication googleAuth = googleUser.authentication;

  //     // Create a new credential
  //     final OAuthCredential credential = GoogleAuthProvider.credential(
  //       idToken: googleAuth.idToken,
  //     );

  //     // Once signed in, return the UserCredential
  //     return await _auth.signInWithCredential(credential);
      
  //   } catch (e) {
  //     print(e);
  //   }
  //   return null;
  // }
  // ========== END GOOGLE SIGN IN ==========

  // Sign out
  Future<void> signOut() async {
    // await _googleSignIn.signOut(); // COMMENTED OUT - Google Sign In
    await _auth.signOut();
  }
}
