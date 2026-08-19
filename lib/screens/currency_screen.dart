import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/exchange_api.dart';

// 여행에서 자주 쓰는 통화. 순서 유지(Map).
const Map<String, String> _currencies = {
  'KRW': '🇰🇷 원 (KRW)',
  'USD': '🇺🇸 미국 달러 (USD)',
  'JPY': '🇯🇵 엔 (JPY)',
  'EUR': '🇪🇺 유로 (EUR)',
  'CNY': '🇨🇳 위안 (CNY)',
  'THB': '🇹🇭 바트 (THB)',
  'VND': '🇻🇳 동 (VND)',
  'TWD': '🇹🇼 대만 달러 (TWD)',
  'HKD': '🇭🇰 홍콩 달러 (HKD)',
  'SGD': '🇸🇬 싱가포르 달러 (SGD)',
  'PHP': '🇵🇭 페소 (PHP)',
  'MYR': '🇲🇾 링깃 (MYR)',
  'GBP': '🇬🇧 파운드 (GBP)',
  'AUD': '🇦🇺 호주 달러 (AUD)',
};

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key, this.initialTo});

  /// 여행 목적지 통화 등 초기 '받는' 통화.
  final String? initialTo;

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  final _amountCtrl = TextEditingController(text: '1000');
  String _from = 'KRW';
  late String _to;
  ExchangeRates? _rates; // _from 기준
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _to = (widget.initialTo != null && _currencies.containsKey(widget.initialTo)) ? widget.initialTo! : 'JPY';
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await ExchangeApi.fetch(_from);
    if (!mounted) return;
    setState(() {
      _rates = r;
      _loading = false;
      if (r == null) _error = '환율을 불러오지 못했어요';
    });
  }

  void _swap() {
    setState(() {
      final t = _from;
      _from = _to;
      _to = t;
    });
    _load(); // base 바뀜 → 재조회
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    final rate = _rates?.rateTo(_to);
    final converted = rate == null ? null : amount * rate;
    final fmt = NumberFormat('#,##0.##');

    return Scaffold(
      appBar: AppBar(title: const Text('환율 계산기')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '금액',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _currencyDropdown(_from, (v) {
                  setState(() => _from = v);
                  _load();
                })),
                IconButton(
                  onPressed: _swap,
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: '바꾸기',
                ),
                Expanded(child: _currencyDropdown(_to, (v) => setState(() => _to = v))),
              ],
            ),
            const SizedBox(height: 28),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (_error != null)
              Column(children: [
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
              ])
            else if (converted != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text('${fmt.format(amount)} $_from', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text('${fmt.format(converted)} $_to',
                        style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text('1 $_from = ${NumberFormat('#,##0.####').format(rate)} $_to',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              ),
              if (_rates!.date.isNotEmpty)
                Center(child: Text('${_rates!.date} 기준', style: TextStyle(fontSize: 11, color: theme.colorScheme.outline))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _currencyDropdown(String value, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
      items: [
        for (final e in _currencies.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
