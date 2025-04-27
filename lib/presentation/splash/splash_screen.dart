import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:healthcare/presentation/auth/login/login_screen.dart';
import 'package:healthcare/presentation/main/main_screen.dart';
import 'package:lottie/lottie.dart';
import '../../utils/appRoutes/assets.dart';
import '../../utils/app_utils/AppUtils.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
        backgroundColor: AppUtils.getColorScheme(context).surface,
        splash: Center(
          child: Lottie.asset(Assets.splashIcon),
        ),
        splashIconSize: 200,
        duration: 2000,
        splashTransition: SplashTransition.fadeTransition,
        nextScreen: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(), // Check is user logged in or not
            builder: (context, snapshot) {
              // user is logged in
              if (snapshot.hasData) {
                return MainScreen();
              } else {
                // user is not logged in
                return LoginScreen();
              }
            }
        )
    );
  }
}