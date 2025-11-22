import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:caregiver/services/auth_debug_service.dart';
import 'package:caregiver/presentation/auth/forgot_password.dart';
import 'package:caregiver/presentation/auth/login/login_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/chat/chat_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/chat/create_group_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/chat/recent_chat_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/exam/assign_exam_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/exam/create_exam_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/exam/manage_exams_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/exam/caregiver/take_exam_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/home_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/library/assign_video_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/library/category/subcategory_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/library/category/subcategory_video_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/library/category/vimeo_video_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/library/library_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/library/upload_video_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/library/video_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/notification_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/profile/otherScreens/assigned_video_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/profile/otherScreens/change_password.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/profile/otherScreens/edit_profile_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/profile/otherScreens/manage_video_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/profile/otherScreens/personal_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/profile/profile_screen.dart';
import 'package:caregiver/presentation/main/main_screen.dart';
import 'package:caregiver/presentation/main/manageUser/all_caregiver_user_screen.dart';
import 'package:caregiver/presentation/main/manageUser/all_staff_user_screen.dart';
import 'package:caregiver/presentation/main/manageUser/all_admin_user_screen.dart';
import 'package:caregiver/presentation/main/manageUser/all_users_screen.dart';
import 'package:caregiver/presentation/main/manageUser/create_user_screen.dart';
import 'package:caregiver/presentation/main/manageUser/manage_user_screen.dart';
import 'package:caregiver/presentation/main/manageUser/night_shift_alerts_screen.dart';
import 'package:caregiver/presentation/splash/splash_screen.dart';
import 'package:caregiver/presentation/terms/privacy_and_policy.dart';
import 'package:caregiver/presentation/terms/terms_and_conditions_screen.dart';
import 'package:caregiver/services/notification_service.dart';
import 'package:caregiver/services/firebase_service.dart';
import 'package:caregiver/theme/theme_provider.dart';
import 'package:caregiver/utils/appRoutes/app_routes.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Define the background message handler at the top level
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // await dotenv.load(fileName: ".env");

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
    
    // Initialize Firestore settings
    await FirebaseService.initializeFirestore();

    // Initialize OneSignal
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize("39bdbb79-5651-45e0-a7ef-52505feb88ca");

    // Request notification permission
    OneSignal.Notifications.requestPermission(true);

    // Set up notification click handler
    OneSignal.Notifications.addClickListener((event) {
      debugPrint('OneSignal notification clicked: ${event.notification.additionalData}');
    });

    debugPrint('OneSignal initialized successfully');

    // Set the background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize local notifications
    await NotificationService.init();

    // Note: FCM initialization is handled in native iOS AppDelegate
    // and should be called after user login to save the token

    // Test Firestore connection (non-blocking)
    FirebaseService.testConnection().then((success) {
      debugPrint('Firestore connection test: ${success ? "✅ Success" : "❌ Failed"}');
    });
    
    // Start authentication debugging for web
    if (kIsWeb) {
      AuthDebugService.startDebugging();
      // Run initial auth test after a brief delay
      Future.delayed(const Duration(seconds: 2), () {
        AuthDebugService.testAuthentication();
      });
    }
    
  } catch (e) {
    debugPrint('Error in main initialization: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    )
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Provider.of<ThemeProvider>(context).themeData,
      routes: {
        AppRoutes.loginScreen: (context) => const LoginScreen(),
        AppRoutes.splashScreen: (context) => const SplashScreen(),
        AppRoutes.mainScreen: (context) => const MainScreen(),
        AppRoutes.homeScreen: (context) => const HomeScreen(),
        AppRoutes.libraryScreen: (context) => const LibraryScreen(),
        AppRoutes.chatScreen: (context) => const ChatScreen(),
        AppRoutes.recentChatScreen: (context) => const RecentChatScreen(),
        AppRoutes.notificationScreen: (context) => const NotificationScreen(),
        AppRoutes.profileScreen: (context) => const ProfileScreen(),
        AppRoutes.editProfileScreen: (context) => const EditProfileScreen(),
        AppRoutes.personalInfoScreen: (context) => const PersonalInfo(),
        AppRoutes.assignVideoScreen: (context) => const AssignVideoScreen(),
        AppRoutes.videoScreen: (context) => const VideoScreen(),
        AppRoutes.createUserScreen: (context) => const CreateUserScreen(),
        AppRoutes.manageUserScreen: (context) => const ManageUserScreen(),
        AppRoutes.assignedVideoScreen: (context) => const AssignedVideoScreen(),
        AppRoutes.manageVideoScreen: (context) => const ManageVideoScreen(),
        AppRoutes.allCaregiverUserScreen: (context) => const AllCaregiverUserScreen(),
        AppRoutes.allStaffUserScreen: (context) => const AllStaffUserScreen(),
        AppRoutes.allAdminUserScreen: (context) => const AllAdminUserScreen(),
        AppRoutes.allUsersScreen: (context) => const AllUsersScreen(),
        AppRoutes.subcategoryScreen: (context) => const SubcategoryScreen(),
        AppRoutes.subcategoryVideoScreen: (context) => const SubcategoryVideoScreen(),
        AppRoutes.createGroupScreen: (context) => const CreateGroupScreen(),
        AppRoutes.createExamScreen: (context) => const CreateExamScreen(),
        AppRoutes.manageExamScreen: (context) => const ManageExamsScreen(),
        AppRoutes.assignExamScreen: (context) => const AssignExamScreen(),
        AppRoutes.takeExamScreen: (context) => const TakeExamScreen(),
        AppRoutes.vimeoVideoScreen: (context) => const VimeoVideoScreen(),
        AppRoutes.forgotPasswordScreen: (context) => const ForgotPassword(),
        AppRoutes.changePasswordScreen: (context) => const ChangePassword(),
        AppRoutes.termsAndConditionScreen: (context) => const TermsAndConditionsScreen(),
        AppRoutes.privacyAndPolicyScreen: (context) => const PrivacyAndPolicyScreen(),
        AppRoutes.createCategoryScreen: (context) => const LibraryScreen(), // Redirect to library screen for category creation
        AppRoutes.uploadVideoScreen: (context) => const UploadVideoScreen(), // Dedicated video upload screen
        AppRoutes.nightShiftAlertsScreen: (context) => const NightShiftAlertsScreen(),
      },
      home: const SplashScreen(),
    );
  }
}