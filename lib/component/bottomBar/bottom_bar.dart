import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import '../../utils/app_utils/AppUtils.dart';

class BottomBar extends StatefulWidget {
  final void Function(int)? onTabChange;
  final int selectedIndex;
  const BottomBar({super.key, this.onTabChange, required this.selectedIndex});

  @override
  State<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> {

  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
  }

  @override
  Widget build(BuildContext context) {

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 1,
          width: double.infinity,
          color: Colors.white,
        ),
        Container(
          decoration: BoxDecoration(
            color: AppUtils.getColorScheme(context).surface
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20),
            child: GNav(
                onTabChange: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                  if (widget.onTabChange != null) {
                    widget.onTabChange!(index);
                  }
                },
                selectedIndex: _currentIndex,
                color: AppUtils.getColorScheme(context).onSurface.withAlpha(80),
                activeColor: AppUtils.getColorScheme(context).onSurface,
                tabBackgroundColor: AppUtils.getColorScheme(context).secondary,
                padding: const EdgeInsets.all(12.0),
                gap: 8,
                textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppUtils.getColorScheme(context).onSurface),
                tabs: [
                  GButton(
                      icon: _currentIndex == 0 ? Icons.home : Icons.home_outlined,
                      text: 'Home'
                  ),
                  GButton(
                      icon: _currentIndex == 1 ? Icons.message_rounded : Icons.message_outlined,
                      text: 'Chat'
                  ),
                  GButton(
                      icon: _currentIndex == 2 ? Icons.video_library : Icons.video_library_outlined,
                      text: 'Library'
                  ),
                  GButton(
                      icon: _currentIndex == 3 ? Icons.account_circle_rounded : Icons.account_circle_outlined,
                      text: 'Profile'
                  ),
                ]
            ),
          ),
        ),
      ],
    );
  }
}