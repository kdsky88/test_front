import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/currencies.dart';
import '../models/expense.dart';
import '../models/todo.dart'; // ApiException
import '../services/expense_api.dart';
import '../widgets/empty_state.dart';

const List<String> _categories = ['식비', '교통', '숙박', '관광', '쇼핑', '기타'];
const Map<String, String> _catEmoji = {
  '식비': '🍽️', '교통': '🚌', '숙박': '🏨', '관광': '📷', '쇼핑': '🛍️', '기타': '💳',
};
final _amountFmt = NumberFormat('#,##0.##');

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, required this.tripId, required this.tripTitle});
  final String tripId;
  final String tripTitle;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense>? _items;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ExpenseApi.list(widget.tripId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '서버에 연결할 수 없습니다.';
        _loading = false;
      });
    }
  }

  // 통화별 합계.
  Map<String, double> get _totals {
    final m = <String, double>{};
    for (final e in _items ?? const <Expense>[]) {
      m[e.currency] = (m[e.currency] ?? 0) + e.amount;
    }
    return m;
  }

  Future<void> _openAdd() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddExpenseSheet(tripId: widget.tripId),
    );
    if (ok == true) _load();
  }

  Future<void> _delete(Expense e) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ExpenseApi.delete(widget.tripId, e.id);
      if (!mounted) return;
      setState(() => _items?.removeWhere((x) => x.id == e.id));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('삭제하지 못했어요')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('경비')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add),
        label: const Text('경비 추가'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  emoji: '⚠️',
                  title: '불러오지 못했어요',
                  subtitle: _error,
                  action: FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('다시 시도')),
                )
              : _body(),
    );
  }

  Widget _body() {
    final items = _items ?? const <Expense>[];
    final theme = Theme.of(context);
    return Column(
      children: [
        if (_totals.isNotEmpty) _totalsBar(theme),
        Expanded(
          child: items.isEmpty
              ? const EmptyState(emoji: '💳', title: '아직 경비가 없어요', subtitle: '아래 + 버튼으로 지출을 기록해 보세요.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _tile(theme, items[i]),
                ),
        ),
      ],
    );
  }

  Widget _totalsBar(ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('합계', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final e in _totals.entries)
                Text('${_amountFmt.format(e.value)} ${e.key}',
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(ThemeData theme, Expense e) {
    return Card(
      child: ListTile(
        leading: Text(_catEmoji[e.category] ?? '💳', style: const TextStyle(fontSize: 22)),
        title: Text('${_amountFmt.format(e.amount)} ${e.currency}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([
          e.category,
          if (e.memo != null && e.memo!.isNotEmpty) e.memo!,
          if (e.createdAt != null) DateFormat('M/d').format(e.createdAt!.toLocal()),
        ].join('  ·  ')),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          tooltip: '삭제',
          onPressed: () => _delete(e),
        ),
      ),
    );
  }
}

class _AddExpenseSheet extends StatefulWidget {
  const _AddExpenseSheet({required this.tripId});
  final String tripId;

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _amountCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  String _category = '식비';
  String _currency = 'KRW';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = '금액을 올바르게 입력해주세요.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ExpenseApi.create(widget.tripId,
          amount: amount, currency: _currency, category: _category, memo: _memoCtrl.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.error.message;
          _submitting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '저장하지 못했어요';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 4, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('경비 추가', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _amountCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '금액', border: OutlineInputBorder(), isDense: true),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _currency,
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: [
                      for (final c in kCurrencies.keys) DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _currency = v ?? 'KRW'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                for (final c in _categories)
                  ChoiceChip(
                    label: Text('${_catEmoji[c]} $c'),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _memoCtrl,
              decoration: const InputDecoration(labelText: '메모 (선택)', border: OutlineInputBorder(), isDense: true),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}
