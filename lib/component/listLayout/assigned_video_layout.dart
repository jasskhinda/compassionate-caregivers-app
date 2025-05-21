import 'package:flutter/material.dart';
import '../../utils/app_utils/AppUtils.dart';

class AssignedVideoLayout extends StatelessWidget {
  final String videoTitle;
  final String? adminName;
  final double? progress;
  final String date;
  final void Function() onTap;

  const AssignedVideoLayout({
    super.key,
    required this.videoTitle,
    required this.adminName,
    required this.progress,
    required this.date,
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(10),
        tileColor: AppUtils.getColorScheme(context).secondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          videoTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppUtils.getColorScheme(context).onSurface,
            fontSize: 14
          )
        ),
        subtitle: adminName != null ? Text('Assigned by $adminName', style: TextStyle(fontSize: 10, color: AppUtils.getColorScheme(context).onSurface.withAlpha(100))) : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (progress != null)
              Text(progress == 0 ? 'Not watched yet' : '${progress!.toInt()}% watched', style: TextStyle(fontWeight: FontWeight.bold, color: AppUtils.getColorScheme(context).tertiaryContainer, fontSize: 14)),

            if (date.isNotEmpty)
              Text('Assigned on $date', style: TextStyle(color: AppUtils.getColorScheme(context).onSurface.withAlpha(100), fontSize: 8)),
          ],
        ),
      ),
    );
  }
}
