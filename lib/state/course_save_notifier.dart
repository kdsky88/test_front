import 'package:flutter/foundation.dart';

/// A batch keeps successful items out of subsequent attempts.
class CourseSaveNotifier extends ChangeNotifier {
  CourseSaveNotifier(this.count, this.save);
  final int count;
  final Future<String?> Function(int) save;
  final Set<int> saved = {};
  final Map<int, String> errors = {};
  bool busy = false;
  bool _disposed = false;
  int attempted = 0;

  Future<void> run() async {
    if (busy || _disposed) return;
    busy = true;
    attempted = saved.length;
    notifyListeners();
    for (var i = 0; i < count; i++) {
      if (_disposed) break;
      if (saved.contains(i)) continue;
      String? error;
      try {
        error = await save(i);
      } catch (_) {
        error = '저장 결과를 확인하지 못했어요. 일정 목록을 먼저 확인해주세요.';
      }
      if (_disposed) break;
      if (error == null) {
        saved.add(i);
        errors.remove(i);
      } else {
        errors[i] = error;
      }
      attempted++;
      notifyListeners();
    }
    busy = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
