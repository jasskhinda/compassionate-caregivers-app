import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../utils/appRoutes/assets.dart';
import '../../utils/app_utils/AppUtils.dart';
import '../../services/auth_wrapper.dart';

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
        duration: 3000, // Increased duration for web loading
        splashTransition: SplashTransition.fadeTransition,
        nextScreen: const AuthWrapper()
    );
  }
}