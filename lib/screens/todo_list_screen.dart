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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.notifier.loadTodos(initial: true);
    });
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
              _buildFilterBar(context, n),
              Expanded(child: _buildBody(context, n)),
              if (n.totalPages > 1) _buildPagination(context, n),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar(BuildContext context, TodoNotifier n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
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
              '총 ${n.total}개',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
        ],
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
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.checklist, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                n.filter == 'all'
                    ? '등록된 할 일이 없습니다.'
                    : (n.filter == 'active' ? '미완료 할 일이 없습니다.' : '완료된 할 일이 없습니다.'),
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
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
            color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
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
            Container(width: 22, height: 22, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(height: 14, width: double.infinity, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 120, color: Colors.grey.shade200),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
