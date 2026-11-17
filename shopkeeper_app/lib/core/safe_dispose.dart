import 'package:flutter/foundation.dart';

/// Dispose controllers only after a dialog's close animation has finished.
///
/// A dialog/TextField keeps rebuilding for a short time after it is closed.
/// Disposing its TextEditingController right after `await Get.dialog(...)`
/// causes "A TextEditingController was used after being disposed".
void disposeLater(Iterable<ChangeNotifier> items) {
  final list = items.toList();
  Future<void>.delayed(const Duration(milliseconds: 700), () {
    for (final item in list) {
      item.dispose();
    }
  });
}
