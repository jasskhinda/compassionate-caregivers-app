import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../component/other/name_image_layout.dart';
import '../../../../utils/appRoutes/assets.dart';
import '../../../../utils/app_utils/AppUtils.dart';

class ChatLayout extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int? badgeCount;
  final bool? hasBadge;
  final Color backgroundColor;
  final void Function() onTap;
  final String? profileImageUrl;

  const ChatLayout({
    super.key,
    this.title,
    this.subtitle,
    this.lastMessage,
    this.lastMessageTime,
    this.badgeCount,
    this.hasBadge,
    required this.onTap,
    required this.backgroundColor,
    this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: backgroundColor
        ),
        child: Padding(
          padding: const EdgeInsets.only(right: 5.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: profileImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: profileImageUrl!,
                              fit: BoxFit.cover,
                              height: 40,
                              width: 40,
                              placeholder: (context, url) => Image.asset(
                                Assets.loginBack,
                                fit: BoxFit.cover,
                                height: 40,
                                width: 40,
                              ),
                              errorWidget: (context, url, error) => Image.asset(
                                Assets.loginBack,
                                fit: BoxFit.cover,
                                height: 40,
                                width: 40,
                              ),
                            )
                          : Image.asset(
                              Assets.loginBack,
                              fit: BoxFit.cover,
                              height: 40,
                              width: 40,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title!,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (lastMessage != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              lastMessage!,
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (lastMessageTime != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _formatTime(lastMessageTime!),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (hasBadge == true && badgeCount != null && badgeCount! > 0)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppUtils.getColorScheme(context).tertiary
                  ),
                  child: Center(
                    child: Text(
                      badgeCount.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}