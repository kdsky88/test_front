import 'package:flutter/material.dart';
import '../state/todo_notifier.dart';
import '../widgets/todo_item_widget.dart';
import '../widgets/todo_form_dialog.dart';

class TodoListScreen extends StatefulWidget {
  final TodoNotifier notifier;

  const TodoListScreen({super.key, required this.notifier});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  late final TextEditingController _searchCtrl;
  String _lastSyncedSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    widget.notifier.addListener(_syncSearchController);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.notifier.loadTodos(initial: true);
      widget.notifier.loadAssignees();
    });
  }

  @override
  void didUpdateWidget(covariant TodoListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notifier == widget.notifier) return;
    oldWidget.notifier.removeListener(_syncSearchController);
    widget.notifier.addListener(_syncSearchController);
    _syncSearchController();
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_syncSearchController);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.notifier,
      builder: (context, _) {
        final n = widget.notifier;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Todo List'),
            centerTitle: false,
            bottom: n.listStatus == ListStatus.refreshing
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(),
                  )
                : null,
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openCreate(context),
            icon: const Icon(Icons.add),
            label: const Text('새 Todo'),
          ),
          body: Column(
            children: [
              _buildSearchBar(context, n),
              _buildFilterBar(context, n),
              if (n.allTags.isNotEmpty) _buildTagFilterBar(context, n),
              Expanded(child: _buildBody(context, n)),
              if (n.totalPages > 1) _buildPagination(context, n),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context, TodoNotifier n) {
    final isBusy =
        n.listStatus == ListStatus.initialLoading ||
        n.listStatus == ListStatus.refreshing;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final field = TextField(
            controller: _searchCtrl,
            enabled: !isBusy,
            maxLength: 110,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submitSearch(n),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      tooltip: '검색어 지우기',
                      onPressed: isBusy ? null : () => _clearSearch(n),
                      icon: const Icon(Icons.close),
                    )
                  : null,
              labelText: '제목 검색',
              hintText: '검색어를 입력하세요',
              errorText: n.searchError,
              counterText: '',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          );

          final button = FilledButton.icon(
            onPressed: isBusy ? null : () => _submitSearch(n),
            icon: const Icon(Icons.search),
            label: const Text('검색'),
          );

          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [field, const SizedBox(height: 8), button],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field),
              const SizedBox(width: 8),
              SizedBox(height: 48, child: button),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, TodoNotifier n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _FilterButton(
                label: '전체',
                value: 'all',
                current: n.filter,
                onTap: () => n.setFilter('all'),
              ),
              const SizedBox(width: 6),
              _FilterButton(
                label: '미완료',
                value: 'active',
                current: n.filter,
                onTap: () => n.setFilter('active'),
              ),
              const SizedBox(width: 6),
              _FilterButton(
                label: '완료',
                value: 'completed',
                current: n.filter,
                onTap: () => n.setFilter('completed'),
              ),
              const Spacer(),
              if (n.total > 0)
                Text(
                  n.searchQuery.isEmpty
                      ? '총 ${n.total}개'
                      : '검색 결과 ${n.total}개',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (n.assignees.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildAssigneeDropdown(context, n),
          ],
        ],
      ),
    );
  }

  Widget _buildAssigneeDropdown(BuildContext context, TodoNotifier n) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.person_outline,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          '담당자',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: n.assigneeFilter,
            isDense: true,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  '전체',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              ...n.assignees.map(
                (a) => DropdownMenuItem<String?>(
                  value: a,
                  child: Text(a, style: theme.textTheme.bodySmall),
                ),
              ),
            ],
            onChanged: (value) => n.setAssigneeFilter(value),
          ),
        ),
      ],
    );
  }

  Widget _buildTagFilterBar(BuildContext context, TodoNotifier n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _TagChipButton(
              label: '전체',
              selected: n.tagFilter == null,
              onTap: () => n.setTagFilter(null),
            ),
            ...n.allTags.map(
              (tag) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _TagChipButton(
                  label: tag,
                  selected: n.tagFilter == tag,
                  onTap: () => n.setTagFilter(tag),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, TodoNotifier n) {
    if (n.listStatus == ListStatus.initialLoading) {
      return _buildSkeleton();
    }

    if (n.listStatus == ListStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                n.listError ?? '오류가 발생했습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => n.retry(),
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final todos = n.todos;
    if (todos.isEmpty) {
      final hasSearch = n.searchQuery.isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.checklist, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                hasSearch
                    ? '"${n.searchQuery}" 검색 결과가 없습니다.'
                    : (n.filter == 'all'
                          ? '등록된 할 일이 없습니다.'
                          : (n.filter == 'active'
                                ? '미완료 할 일이 없습니다.'
                                : '완료된 할 일이 없습니다.')),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              if (hasSearch) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _clearSearch(n),
                  icon: const Icon(Icons.close),
                  label: const Text('검색 해제'),
                ),
              ],
              if (n.filter == 'all') ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _openCreate(context),
                  icon: const Icon(Icons.add),
                  label: const Text('할 일 추가'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: todos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        return TodoItemWidget(todo: todos[index], notifier: n);
      },
    );
  }

  Widget _buildSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (_, _) => const _SkeletonItem(),
    );
  }

  Widget _buildPagination(BuildContext context, TodoNotifier n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: n.canGoPrev && n.listStatus != ListStatus.refreshing
                ? () => n.goToPage(n.page - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: '이전',
          ),
          const SizedBox(width: 8),
          Text(
            '${n.page} / ${n.totalPages}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: n.canGoNext && n.listStatus != ListStatus.refreshing
                ? () => n.goToPage(n.page + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: '다음',
          ),
        ],
      ),
    );
  }

  void _openCreate(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => TodoFormDialog(notifier: widget.notifier),
    );
  }

  Future<void> _submitSearch(TodoNotifier n) async {
    final applied = await n.submitSearch(_searchCtrl.text);
    if (!mounted || !applied) return;
    _lastSyncedSearchQuery = n.searchQuery;
    FocusScope.of(context).unfocus();
  }

  Future<void> _clearSearch(TodoNotifier n) async {
    _searchCtrl.clear();
    setState(() {});
    await n.clearSearch();
    _lastSyncedSearchQuery = n.searchQuery;
  }

  void _syncSearchController() {
    final query = widget.notifier.searchQuery;
    if (query == _lastSyncedSearchQuery) return;
    _lastSyncedSearchQuery = query;
    _searchCtrl.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _TagChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TagChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SkeletonItem extends StatelessWidget {
  const _SkeletonItem();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 120,
                    color: Colors.grey.shade200,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
