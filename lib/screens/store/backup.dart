import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../widgets/common.dart';
import '../../widgets/scope.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// One "Backup" row opens this: make a backup, or restore one.
Future<void> showBackupSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: const Text('Back up my data'),
            subtitle: const Text(
              'Send a copy of your records to yourself. Photos are not included.',
            ),
            onTap: () {
              Navigator.pop(ctx);
              backupData(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: const Text('Restore a backup'),
            subtitle: const Text(
              'Replace this shop\'s records with a backup file',
            ),
            onTap: () {
              Navigator.pop(ctx);
              restoreData(context);
            },
          ),
        ],
      ),
    ),
  );
}

/// Sends a copy of all records to the phone's share sheet (save to Drive, send
/// to yourself on Messenger or email). The file is plain text.
Future<void> backupData(BuildContext context) async {
  final store = context.store;
  try {
    final now = DateTime.now();
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}-${_two(now.hour)}${_two(now.minute)}';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/a2z2go-backup-$stamp.json');
    await file.writeAsString(store.exportJson());
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        title: 'A2Z2GO backup',
        subject: 'A2Z2GO backup $stamp',
      ),
    );
  } catch (_) {
    if (context.mounted) {
      showMsg(context, 'Could not create the backup.', error: true);
    }
  }
}

/// Replaces this shop's records with a backup file chosen by the seller.
Future<void> restoreData(BuildContext context) async {
  final store = context.store;
  final ok = await confirmDialog(
    context,
    title: 'Restore a backup?',
    message: 'This replaces everything in this shop with the records in the backup file. Photos are not part of a backup. This cannot be undone.',
    confirmLabel: 'Choose file',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  try {
    final picked = await FilePicker.pickFiles(dialogTitle: 'Choose a backup');
    if (picked.isEmpty) return;
    final path = picked.first.path;
    if (path == null) throw const FormatException('no path');
    final res = store.restoreFromJson(await File(path).readAsString());
    if (!context.mounted) return;
    showMsg(context, res.ok ? 'Backup restored' : res.error!, error: !res.ok);
  } catch (_) {
    if (context.mounted) {
      showMsg(context, 'Could not open that file.', error: true);
    }
  }
}
