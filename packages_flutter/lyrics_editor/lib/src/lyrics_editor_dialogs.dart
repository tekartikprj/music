/// Small dialogs of the editor.
library;

import 'package:material_ui/material_ui.dart';

/// Ask for a text, null when cancelled.
Future<String?> lyricsEditorPromptText(
  BuildContext context, {
  required String title,
  required String label,
  String? initialValue,
  String? helperText,
}) async {
  var controller = TextEditingController(text: initialValue);
  var result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label, helperText: helperText),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  return result?.trim();
}

/// Ask for a confirmation.
Future<bool> lyricsEditorConfirm(
  BuildContext context, {
  required String title,
  String? message,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: message == null ? null : Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('OK'),
            ),
          ],
        ),
      ) ??
      false;
}

/// Show a snack bar, when there is a messenger.
void lyricsEditorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(message)));
}

/// `x0.75`: a playback rate as the speed menu shows it.
String formatLyricsPlaybackRate(double rate) {
  var text = rate.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return 'x$text';
}
