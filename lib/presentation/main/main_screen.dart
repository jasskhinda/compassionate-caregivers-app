import 'package:flutter/material.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/chat/recent_chat_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/library/library_screen.dart';
import 'package:caregiver/presentation/main/bottomBarScreens/profile/profile_screen.dart';
import 'package:caregiver/utils/app_utils/AppUtils.dart';
import '../../component/bottomBar/bottom_bar.dart';
import '../../component/bottomBar/nav_drawer.dart';
import 'bottomBarScreens/home_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {

  // Manage the selected index for both BottomBar and NavDrawer
  int _selectedIndex = 0;

  // Update the selected index
  void _updateSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Screen List
  final List<Widget> _pages = [
    const HomeScreen(),
    const RecentChatScreen(),
    const LibraryScreen(),
    const ProfileScreen()
  ];

  @override
  Widget build(BuildContext context) {

    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
        backgroundColor: AppUtils.getColorScheme(context).surface,
        body: screenWidth < 1000
            ? MainMobileUI(onTabChange: _updateSelectedIndex, pages: _pages, selectedIndex: _selectedIndex)
            : MainDesktopUI(onTabChange: _updateSelectedIndex, pages: _pages, selectedIndex: _selectedIndex)
    );
  }
}

class MainDesktopUI extends StatelessWidget {
  final void Function(int) onTabChange;
  final List<Widget> pages;
  final int selectedIndex;
  const MainDesktopUI({
    super.key,
    required this.onTabChange,
    required this.pages,
    required this.selectedIndex
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Drawer
        NavDrawer(onTabChange: (index)  => onTabChange(index), pages: pages, selectedIndex: selectedIndex,),

        // Rest UI
        Expanded(
            child: IndexedStack(
                index: selectedIndex,
                children: pages
            )
        )
      ],
    );
  }
}


class MainMobileUI extends StatelessWidget {
  final void Function(int) onTabChange;
  final List<Widget> pages;
  final int selectedIndex;
  const MainMobileUI({
    super.key,
    required this.onTabChange,
    required this.pages,
    required this.selectedIndex
  });

  @override
  Widget build(BuildContext context) {

    return Stack(
      children: [
        IndexedStack(
            index: selectedIndex,
            children: pages
        ),
        Align(
            alignment: Alignment.bottomCenter,
            child: BottomBar(
                onTabChange: (index) => onTabChange(index),
                selectedIndex: selectedIndex
            )
        )
      ],
    );
  }
}