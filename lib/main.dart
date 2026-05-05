import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'models/app_user.dart';
import 'ui/login_screen.dart';
import 'ui/main_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '9th-Grade Student App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1A237E),
        brightness: Brightness.light,
      ),
      home: const AuthGate(),
    );
  }
}

/// Listens to Firebase Auth state and routes accordingly.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still connecting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not logged in → show login
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // Logged in → fetch Firestore profile then show home
        return FutureBuilder<AppUser>(
          future: AuthService().getAppUser(snapshot.data!.uid),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (userSnap.hasError) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Error: ${userSnap.error}'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return MainDashboardScreen(appUser: userSnap.data!);
          },
        );
      },
    );
  }
}
