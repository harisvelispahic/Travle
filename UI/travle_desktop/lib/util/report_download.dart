import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:travle_ui/travle_ui.dart';

/// Saves a generated report PDF to a location the admin chooses (native save
/// dialog), then confirms with a snackbar offering to open it in the OS default
/// viewer — where it can be viewed and printed. A generated PDF is inherently
/// printable, so this covers the "downloadable and printable" requirement.
/// Returns true when the file was saved, false if the user cancelled.
Future<bool> saveReportPdf(
  BuildContext context,
  Uint8List bytes,
  String suggestedName,
) async {
  final path = await FilePicker.saveFile(
    dialogTitle: 'Save report',
    fileName: suggestedName,
    bytes: bytes,
  );
  if (path == null) return false; // user cancelled

  // On desktop saveFile may only return the path without writing — ensure it.
  final file = File(path);
  if (!await file.exists() || await file.length() == 0) {
    await file.writeAsBytes(bytes);
  }
  if (!context.mounted) return true;

  final name = path.split(Platform.pathSeparator).last;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Report saved as "$name"'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => _openInDefaultViewer(path),
        ),
      ),
    );
  return true;
}

// Opens the file with its default handler (a PDF viewer) so the user can view/print.
Future<void> _openInDefaultViewer(String path) async {
  try {
    if (Platform.isWindows) {
      await Process.start('cmd', ['/c', 'start', '', path],
          mode: ProcessStartMode.detached);
    } else if (Platform.isMacOS) {
      await Process.start('open', [path], mode: ProcessStartMode.detached);
    } else {
      await Process.start('xdg-open', [path], mode: ProcessStartMode.detached);
    }
  } on ProcessException {
    // Opening is best-effort; the file is already saved, so a failure here is benign.
  }
}

/// Sends a generated report PDF straight to the OS print dialog, so the admin
/// can print from inside the console instead of saving the file and finding a
/// viewer for it (RS2 requires Download *and* Print as distinct actions).
///
/// [Printing.layoutPdf] hands the bytes to the platform's own print pipeline —
/// nothing is written to disk, and the backend's QuestPDF output is printed
/// exactly as it is downloaded. Returns false when the user cancels the dialog.
Future<bool> printReportPdf(
  BuildContext context,
  Uint8List bytes,
  String documentName,
) async {
  try {
    return await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: documentName,
    );
  } on Exception catch (e) {
    // A missing or misbehaving print subsystem must not take the screen down;
    // the same report is still downloadable.
    if (context.mounted) {
      AppSnackbars.error(context, 'Could not open the print dialog: $e');
    }
    return false;
  }
}
