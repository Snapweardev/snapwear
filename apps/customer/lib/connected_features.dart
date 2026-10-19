import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> featureCall(
  String name,
  Map<String, dynamic> data,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Sign in to continue.');
  const local = bool.fromEnvironment('SNAPWEAR_LOCAL_TEST');
  const host = String.fromEnvironment(
    'SNAPWEAR_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  final base = local
      ? 'http://$host:5001/demo-snapwear/asia-south1'
      : 'https://asia-south1-snapwear-3222a.cloudfunctions.net';
  final response = await http
      .post(
        Uri.parse('$base/$name'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await user.getIdToken()}',
        },
        body: jsonEncode({'data': data}),
      )
      .timeout(const Duration(seconds: 30));
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  if (body['error'] != null) {
    throw StateError((body['error'] as Map)['message'].toString());
  }
  return Map<String, dynamic>.from(body['result'] as Map? ?? {});
}

Future<void>? _googleSetup;

class GoogleLoginButton extends StatefulWidget {
  final VoidCallback? onSuccess;
  const GoogleLoginButton({super.key, this.onSuccess});
  @override
  State<GoogleLoginButton> createState() => _GoogleLoginButtonState();
}

class _GoogleLoginButtonState extends State<GoogleLoginButton> {
  bool busy = false;
  String? error;
  Future<void> login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(
          GoogleAuthProvider()
            ..setCustomParameters({'prompt': 'select_account'}),
        );
      } else {
        await (_googleSetup ??= GoogleSignIn.instance.initialize());
        final account = await GoogleSignIn.instance.authenticate();
        final token = account.authentication.idToken;
        if (token == null) {
          throw StateError(
            'Google did not return a sign-in token. Check platform OAuth setup.',
          );
        }
        await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(idToken: token),
        );
      }
      if (mounted) widget.onSuccess?.call();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () => error = e.code == 'account-exists-with-different-credential'
              ? 'Sign in with your existing method first to link this Google account.'
              : 'Google sign-in: ${e.message ?? e.code}',
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: busy ? null : login,
        icon: const Icon(Icons.account_circle_outlined),
        label: Text(busy ? 'Connecting…' : 'Continue with Google'),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ],
  );
}
