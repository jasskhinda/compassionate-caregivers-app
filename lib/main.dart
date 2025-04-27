import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:healthcare/presentation/auth/login/login_screen.dart';
import 'package:healthcare/presentation/main/bottomBarScreens/chat/chat_screen.dart';
import 'package:healthcare/presentation/main/bottomBarScreens/chat/create_group_screen.dart';
import 'package:healthcare/presentation/main/bottomBarScreens/chat/recent_chat_screen.dart';
import 'package:healthcare/presentation/main/bottomBarScreens/home_screen.dart';
import 'package:healthcare/presentation/main/bottomBarScreens/library/assign_video_screen.dart';
import 'package:healthcare/presentation/main/bottomBarScreens/library/category/subcategory_screen.dart';
import 'package:healthcare/presentation/main/bottomBarScreens/library/category/subcategory_video_screen.dart';
import 'package:healthcare/presentation/main/bottomBarScreens/library/library_screen.dart';
import 'package:healthcare/presentation/main/bottomBarScreens/library/video_screen.dart';
import 'package:healthcare/presentation/main/bottomBarScreens/notification_screen.dart';
import 'package:healthcare/presentation/main/bottomBarScreens/profile/otherScreens/assigned_video_screen.dart';
import 'package:healthcare/presentation/main/bottomBarScreens/profile/otherScreens/edit_profile_screen.dart';
import 'package:healthcare/presentation/main/bottomBarScreens/profile/otherScreens/manage_video_screen.dart';
import 'package:healthcare/presentation/main/bottomBarScreens/profile/otherScreens/personal_screen.dart';
import 'package:healthcare/presentation/main/bottomBarScreens/profile/profile_screen.dart';
import 'package:healthcare/presentation/main/main_screen.dart';
import 'package:healthcare/presentation/main/manageUser/all_caregiver_user_screen.dart';
import 'package:healthcare/presentation/main/manageUser/all_nurse_user_screen.dart';
import 'package:healthcare/presentation/main/manageUser/create_user_screen.dart';
import 'package:healthcare/presentation/main/manageUser/manage_user_screen.dart';
import 'package:healthcare/presentation/splash/splash_screen.dart';
import 'package:healthcare/services/notification_service.dart';
import 'package:healthcare/theme/theme_provider.dart';
import 'package:healthcare/utils/appRoutes/app_routes.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Define the background message handler at the top level
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
    
    // Set the background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Initialize local notifications
    await NotificationService.init();
    
    // Initialize FCM - only on mobile platforms
    if (!kIsWeb) {
      try {
        final notificationService = NotificationService();
        await notificationService.initializeFCM();
      } catch (e) {
        debugPrint('Error initializing FCM: $e');
      }
    } else {
      debugPrint('Skipping FCM initialization on web platform');
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
        AppRoutes.allNurseUserScreen: (context) => const AllNurseUserScreen(),
        AppRoutes.subcategoryScreen: (context) => const SubcategoryScreen(),
        AppRoutes.subcategoryVideoScreen: (context) => const SubcategoryVideoScreen(),
        AppRoutes.createGroupScreen: (context) => const CreateGroupScreen(),
      },
      home: const SplashScreen(),
    );
  }
}