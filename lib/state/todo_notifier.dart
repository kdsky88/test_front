import 'package:flutter/foundation.dart';
import '../models/todo.dart';
import '../services/todo_api.dart';

const int kPageLimit = 20;

enum ListStatus { idle, initialLoading, refreshing, error }

class TodoNotifier extends ChangeNotifier {
  List<Todo> _todos = [];
  String _filter = 'all';
  String _searchQuery = '';
  String? _searchError;
  String? _tagFilter;
  int _page = 1;
  int _totalPages = 0;
  int _total = 0;
  ListStatus _listStatus = ListStatus.idle;
  String? _listError;

  // Per-item in-progress tracking
  final Set<String> _processingIds = {};

  // Per-item errors (itemId -> errorMessage)
  final Map<String, String> _itemErrors = {};

  // Request sequencing: only apply result if sequence still matches
  int _listSeq = 0;

  List<Todo> get todos => _todos;
  String get filter => _filter;
  String get searchQuery => _searchQuery;
  String? get searchError => _searchError;
  String? get tagFilter => _tagFilter;
  int get page => _page;
  int get totalPages => _totalPages;
  int get total => _total;
  ListStatus get listStatus => _listStatus;
  String? get listError => _listError;
  bool isProcessing(String id) => _processingIds.contains(id);
  String? itemError(String id) => _itemErrors[id];

  List<String> get allTags {
    final tags = <String>{};
    for (final todo in _todos) {
      tags.addAll(todo.tags);
    }
    if (_tagFilter != null) tags.add(_tagFilter!);
    final list = tags.toList()..sort();
    return list;
  }

  bool get canGoPrev => _page > 1;
  bool get canGoNext => _page < _totalPages;

  Future<void> loadTodos({bool initial = false}) async {
    if (initial) {
      _listStatus = ListStatus.initialLoading;
    } else {
      _listStatus = ListStatus.refreshing;
    }
    _listError = null;
    notifyListeners();

    final seq = ++_listSeq;
    try {
      final result = await TodoApi.getTodos(
        status: _filter,
        page: _page,
        limit: kPageLimit,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        tag: _tagFilter,
      );
      if (seq != _listSeq) return; // stale response

      final lastValidPage = result.totalPages > 0 ? result.totalPages : 1;
      if (_page > lastValidPage || (result.data.isEmpty && _page > 1)) {
        _page = lastValidPage < _page ? lastValidPage : _page - 1;
        await loadTodos();
        return;
      }

      _todos = result.data;
      _totalPages = result.totalPages;
      _total = result.total;
      _listStatus = ListStatus.idle;
      notifyListeners();
    } on ApiException catch (e) {
      if (seq != _listSeq) return;
      if (e.error.code == 'INVALID_FILTER') {
        _filter = 'all';
        _page = 1;
        await loadTodos();
        return;
      }
      final searchError = e.error.fields?['search'];
      if (searchError != null) {
        _searchError = searchError;
        _listStatus = ListStatus.idle;
        notifyListeners();
        return;
      }
      _listStatus = ListStatus.error;
      _listError = e.error.message;
      notifyListeners();
    } catch (error) {
      if (seq != _listSeq) return;
      _listStatus = ListStatus.error;
      _listError = _dataErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> setFilter(String filter) async {
    if (_filter == filter) return;
    _filter = filter;
    _page = 1;
    await loadTodos();
  }

  Future<void> setTagFilter(String? tag) async {
    if (_tagFilter == tag) return;
    _tagFilter = tag;
    _page = 1;
    await loadTodos();
  }

  Future<bool> submitSearch(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.length > 100) {
      _searchError = '검색어는 100자 이하로 입력해주세요.';
      notifyListeners();
      return false;
    }

    if (_searchQuery == trimmed && _searchError == null) return true;
    _searchQuery = trimmed;
    _searchError = null;
    _page = 1;
    await loadTodos();
    return true;
  }

  Future<void> clearSearch() => submitSearch('');

  Future<void> goToPage(int page) async {
    if (page < 1 || page > _totalPages) return;
    _page = page;
    await loadTodos();
  }

  Future<void> retry() => loadTodos();

  /// Returns null on success, error message on failure.
  Future<String?> createTodo({
    required String title,
    required TodoPriority priority,
    String? description,
    String? note,
    String? dueAt,
    List<String> tags = const [],
  }) async {
    try {
      final created = await TodoApi.createTodo(
        title: title,
        priority: priority,
        description: description?.isNotEmpty == true ? description : null,
        note: note?.isNotEmpty == true ? note : null,
        dueAt: dueAt,
      );
      for (final tag in tags) {
        await TodoApi.addTag(id: created.id, tag: tag);
      }
      // On success: always go to all/page 1
      _filter = 'all';
      _searchQuery = '';
      _searchError = null;
      _tagFilter = null;
      _page = 1;
      await loadTodos();
      return null;
    } on ApiException catch (e) {
      return e.error.message;
    } catch (error) {
      return _dataErrorMessage(error);
    }
  }

  /// Returns (updatedTodo, errorMessage). Updates local list on success.
  Future<(Todo?, String?)> addTagToTodo(String id, String tag) async {
    try {
      final updated = await TodoApi.addTag(id: id, tag: tag);
      final idx = _todos.indexWhere((t) => t.id == id);
      if (idx >= 0) {
        _todos = List.of(_todos)..[idx] = updated;
        notifyListeners();
      }
      return (updated, null);
    } on ApiException catch (e) {
      return (null, e.error.message);
    } catch (_) {
      return (null, '태그를 추가할 수 없습니다.');
    }
  }

  /// Returns (updatedTodo, errorMessage). Updates local list on success.
  Future<(Todo?, String?)> removeTagFromTodo(String id, String tag) async {
    try {
      final updated = await TodoApi.removeTag(id: id, tag: tag);
      final idx = _todos.indexWhere((t) => t.id == id);
      if (idx >= 0) {
        _todos = List.of(_todos)..[idx] = updated;
        notifyListeners();
      }
      return (updated, null);
    } on ApiException catch (e) {
      return (null, e.error.message);
    } catch (_) {
      return (null, '태그를 삭제할 수 없습니다.');
    }
  }

  /// Returns (updatedTodo, errorMessage). On 404: refreshes list.
  Future<(Todo?, ApiException?, String?)> updateTodo({
    required String id,
    required String title,
    required TodoPriority priority,
    String? description,
    String? note,
    String? dueAt,
    bool clearDescription = false,
    bool clearNote = false,
    bool clearDueAt = false,
  }) async {
    try {
      final updated = await TodoApi.updateTodo(
        id: id,
        title: title,
        priority: priority,
        description: description,
        note: note,
        dueAt: dueAt,
        clearDescription: clearDescription,
        clearNote: clearNote,
        clearDueAt: clearDueAt,
      );
      await loadTodos();
      return (updated, null, null);
    } on ApiException catch (e) {
      if (e.error.code == 'TODO_NOT_FOUND') {
        await loadTodos();
      }
      return (null, e, e.error.message);
    } catch (error) {
      return (null, null, _dataErrorMessage(error));
    }
  }

  Future<void> toggleComplete(String id) async {
    if (_processingIds.contains(id)) return;
    final todo = _todos.firstWhere((t) => t.id == id);
    final newCompleted = !todo.completed;

    _processingIds.add(id);
    _itemErrors.remove(id);
    notifyListeners();

    try {
      final updated = await TodoApi.updateTodo(id: id, completed: newCompleted);
      _processingIds.remove(id);

      // Remove from list if filter excludes the new state
      final shouldKeep =
          _filter == 'all' ||
          (_filter == 'active' && !updated.completed) ||
          (_filter == 'completed' && updated.completed);

      if (!shouldKeep) {
        _todos = _todos.where((t) => t.id != id).toList();
      } else {
        final idx = _todos.indexWhere((t) => t.id == id);
        if (idx >= 0) {
          _todos = List.of(_todos)..[idx] = updated;
        }
      }
      notifyListeners();
    } on ApiException catch (e) {
      _processingIds.remove(id);
      _itemErrors[id] = e.error.message;
      notifyListeners();
    } catch (_) {
      _processingIds.remove(id);
      _itemErrors[id] = '완료 상태를 변경할 수 없습니다.';
      notifyListeners();
    }
  }

  Future<bool> deleteTodo(String id) async {
    if (_processingIds.contains(id)) return false;

    _processingIds.add(id);
    _itemErrors.remove(id);
    notifyListeners();

    try {
      await TodoApi.deleteTodo(id);
      _processingIds.remove(id);

      final wasLastOnPage = _todos.length == 1 && _page > 1;
      _todos = _todos.where((t) => t.id != id).toList();

      if (wasLastOnPage || _todos.isEmpty) {
        if (_page > 1) _page -= 1;
        await loadTodos();
      } else {
        notifyListeners();
      }
      return true;
    } on ApiException catch (e) {
      _processingIds.remove(id);
      if (e.error.code == 'TODO_NOT_FOUND') {
        await loadTodos();
        return true;
      }
      _itemErrors[id] = e.error.message;
      notifyListeners();
      return false;
    } catch (_) {
      _processingIds.remove(id);
      _itemErrors[id] = '삭제할 수 없습니다. 다시 시도해주세요.';
      notifyListeners();
      return false;
    }
  }

  void clearItemError(String id) {
    _itemErrors.remove(id);
    notifyListeners();
  }

  String _dataErrorMessage(Object error) {
    if (error is FormatException || error is TypeError) {
      return '응답 데이터가 올바르지 않습니다. 다시 시도해주세요.';
    }
    return '서버에 연결할 수 없습니다. 다시 시도해주세요.';
  }
}
