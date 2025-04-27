import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/appRoutes/assets.dart';
import '../../utils/app_utils/AppUtils.dart';

class NameImageLayout extends StatelessWidget {
  final String title;
  final String? description;
  final String? image;
  final String? profileImageUrl;

  const NameImageLayout({
    super.key,
    required this.title,
    this.description,
    this.image,
    this.profileImageUrl
  });

  @override
  Widget build(BuildContext context) {
    // Theme
    TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: profileImageUrl != null
              ? CachedNetworkImage(
                  imageUrl: profileImageUrl!,
                  fit: BoxFit.cover,
                  height: 47,
                  width: 47,
                  placeholder: (context, url) => Image.asset(
                    image ?? Assets.loginBack,
                    fit: BoxFit.cover,
                    height: 47,
                    width: 47,
                  ),
                  errorWidget: (context, url, error) => Image.asset(
                    image ?? Assets.loginBack,
                    fit: BoxFit.cover,
                    height: 47,
                    width: 47,
                  ),
                )
              : Image.asset(
                  image ?? Assets.loginBack,
                  fit: BoxFit.cover,
                  height: 47,
                  width: 47,
                ),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                color: AppUtils.getColorScheme(context).onSurface,
                fontWeight: FontWeight.bold
              )
            ),
            description != null ? const SizedBox(height: 3) : const SizedBox(),
            description != null
                ? Text(
                    description!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppUtils.getColorScheme(context).onSurface.withAlpha(120)
                    )
                  )
                : const SizedBox()
          ],
        ),
      ],
    );
  }
}
