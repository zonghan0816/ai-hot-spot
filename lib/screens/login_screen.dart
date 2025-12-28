import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:taxibook/providers/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '歡迎使用計程車帳本',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              '請登入以繼續',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 48),
            if (authProvider.status == AuthStatus.authenticating)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('使用 Google 帳號登入'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  authProvider.signInWithGoogle().catchError((error) {
                    // Check if the widget is still in the tree before showing a SnackBar
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('登入失敗: $error')),
                      );
                    }
                    // Return false as the signInWithGoogle Future expects a bool
                    return false;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}
