import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/appRoutes/assets.dart';
import '../../utils/app_utils/AppUtils.dart';

class UserLayout extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? trailing;
  final void Function() onTap;
  final String? profileImageUrl;

  const UserLayout({
    super.key,
    this.trailing,
    this.description,
    this.profileImageUrl,
    required this.title,
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.all(10),
      tileColor: AppUtils.getColorScheme(context).secondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: profileImageUrl != null
            ? CachedNetworkImage(
                imageUrl: profileImageUrl!,
                fit: BoxFit.cover,
                height: 47,
                width: 47,
                placeholder: (context, url) => Image.asset(
                  Assets.loginBack,
                  fit: BoxFit.cover,
                  height: 47,
                  width: 47,
                ),
                errorWidget: (context, url, error) => Image.asset(
                  Assets.loginBack,
                  fit: BoxFit.cover,
                  height: 47,
                  width: 47,
                ),
              )
            : Image.asset(
                Assets.loginBack,
                fit: BoxFit.cover,
                height: 47,
                width: 47,
              ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppUtils.getColorScheme(context).onSurface
        )
      ),
      subtitle: Text(
        description ?? '',
        style: TextStyle(
          fontSize: 12,
          color: AppUtils.getColorScheme(context).onSurface.withAlpha(150)
        )
      ),
      trailing: trailing
    );
  }
}
