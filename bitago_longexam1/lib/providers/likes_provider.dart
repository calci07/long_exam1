import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LikesProvider extends ChangeNotifier {
  LikesProvider(this.preferences, Object userId) : _key = 'likes_$userId' {
    _liked = (preferences.getStringList(_key) ?? []).toSet();
  }
  final SharedPreferences preferences;
  final String _key;
  late Set<String> _liked;
  bool _saving = false;
  bool contains(String key) => _liked.contains(key);

  Future<void> toggle(String key) async {
    if (_saving) return;
    _saving = true;
    try {
      final next = {..._liked};
      if (!next.remove(key)) next.add(key);
      if (!await preferences.setStringList(_key, next.toList())) {
        throw Exception('Could not save your like.');
      }
      _liked = next;
      notifyListeners();
    } finally {
      _saving = false;
    }
  }
}
