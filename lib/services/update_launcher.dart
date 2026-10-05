import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_checker.dart';

/// Opens the signed APK in the browser: Android downloads it and offers to install it over the current version
/// (same signing key since).
Future<void> openUpdateDownload(BuildContext context, AvailableUpdate update) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await launchUrl(Uri.parse(update.downloadUrl), mode: LaunchMode.externalApplication);
  if (!ok) {
    messenger.showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir ${update.downloadUrl}')));
  }
}
