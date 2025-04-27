import 'package:flutter/material.dart';
import 'package:healthcare/presentation/auth/login/login_ui.dart';
import 'package:healthcare/utils/appRoutes/assets.dart';
import '../../../utils/app_utils/AppUtils.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return SafeArea(
      child: AppUtils.getScreenSize(context).width >= 1000
          ? const DesktopLogin()
          : const MobileLogin(),
    );
  }
}

class MobileLogin extends StatelessWidget {
  const MobileLogin({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Stack(
              children: [
                // Background Image
                Image.asset(
                  Assets.loginBack,
                  fit: BoxFit.cover,
                  height: MediaQuery.of(context).size.height,
                ),

                // Semi-transparent overlay
                Container(
                  color: Colors.black.withAlpha(200),
                ),

                // Login UI
                Center(
                  child: SizedBox(
                    width: AppUtils.getScreenSize(context).width >= 600 ? 500 : AppUtils.getScreenSize(context).width,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: Colors.black.withAlpha(150)
                      ),
                      child: const LoginUi()
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DesktopLogin extends StatefulWidget {
  const DesktopLogin({super.key});

  @override
  State<DesktopLogin> createState() => _DesktopLoginState();
}

class _DesktopLoginState extends State<DesktopLogin> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Container(
            width: AppUtils.getScreenSize(context).width * 0.7,
            height: AppUtils.getScreenSize(context).height * 0.7,
            decoration: BoxDecoration(
              color: AppUtils.getColorScheme(context).primaryFixed,
              borderRadius: BorderRadius.circular(15)
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 30.0),
                  child: SizedBox(
                    width: AppUtils.getScreenSize(context).width * 0.27,
                    child: const LoginUi()
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 15.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.asset(
                      Assets.loginBack,
                      fit: BoxFit.cover,
                      width: AppUtils.getScreenSize(context).width * 0.37,
                      height: AppUtils.getScreenSize(context).height * 0.67,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
