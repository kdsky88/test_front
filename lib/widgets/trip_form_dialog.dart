import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../models/todo.dart';
import '../services/trip_api.dart';
import '../screens/location_picker_screen.dart';

final _dateFmt = DateFormat('yyyy.MM.dd');
final _apiDateFmt = DateFormat('yyyy-MM-dd');

/// 여행 만들기/수정 다이얼로그. 성공 시 생성/수정된 Trip 반환. existing=null이면 생성.
class TripFormDialog extends StatefulWidget {
  const TripFormDialog({super.key, this.existing, this.save});

  final Trip? existing;
  final Future<Trip> Function(
    String title,
    String destination,
    String? start,
    String? end,
  )?
  save;

  @override
  State<TripFormDialog> createState() => _TripFormDialogState();
}

class _TripFormDialogState extends State<TripFormDialog> {
  late final _titleController = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final _destinationController = TextEditingController(
    text: widget.existing?.destination ?? '',
  );
  late DateTime? _start = widget.existing?.startDate;
  late DateTime? _end = widget.existing?.endDate;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _titleController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? (_start ?? now) : (_end ?? _start ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: !isStart && _start != null ? _start! : DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _pickDestination() async {
    final current = _destinationController.text.trim();
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialQuery: current.isEmpty ? null : current,
        ),
      ),
    );
    if (result?.name == null || !mounted) return;
    setState(() => _destinationController.text = result!.name!);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final destination = _destinationController.text.trim();
    if (!_isEdit && destination.isEmpty) {
      setState(() => _error = '추천받고 싶은 목적지를 입력해주세요.');
      return;
    }
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : destination.isEmpty
        ? '새 여행'
        : '$destination 여행';
    if ((_start == null) != (_end == null)) {
      setState(() => _error = '시작일과 종료일을 모두 선택하거나 날짜를 나중에 정해주세요.');
      return;
    }
    if (_start != null && _end!.isBefore(_start!)) {
      setState(() => _error = '종료일은 시작일 이후로 선택해주세요.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final startDate = _start == null ? null : _apiDateFmt.format(_start!);
      final endDate = _end == null ? null : _apiDateFmt.format(_end!);
      final Trip saved;
      if (widget.save != null) {
        saved = await widget.save!(title, destination, startDate, endDate);
      } else if (_isEdit) {
        saved = await TripApi.updateTrip(
          widget.existing!.id,
          title: title,
          destination: destination,
          startDate: startDate,
          endDate: endDate,
        );
      } else {
        saved = await TripApi.createTrip(
          title: title,
          destination: destination,
          startDate: startDate,
          endDate: endDate,
        );
      }
      if (mounted) Navigator.pop(context, saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.error.message;
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '저장에 실패했습니다.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
        title: Text(_isEdit ? '여행 수정' : '새 여행'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _destinationController,
                enabled: !_submitting,
                autofocus: !_isEdit,
                maxLength: 90,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '목적지',
                  counterText: '',
                  hintText: '예: 제주, 부산, 오사카',
                  helperText: '목적지에 맞는 관광지와 맛집을 추천해드려요.',
                  helperMaxLines: 3,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.map_outlined),
                    tooltip: '지도에서 검색',
                    onPressed: _pickDestination,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                enabled: !_submitting,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: '여행 이름',
                  counterText: '',
                  hintText: _destinationController.text.trim().isEmpty
                      ? '목적지를 입력하면 이름을 제안해드려요'
                      : '${_destinationController.text.trim()} 여행',
                  helperText: _destinationController.text.trim().isEmpty
                      ? '선택 입력 · 비워두면 목적지로 이름을 만들어요.'
                      : '선택 입력 · 비워두면 「${_destinationController.text.trim()} 여행」으로 만들어요.',
                  helperMaxLines: 3,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('여행 날짜 (선택)'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => _pickDate(isStart: true),
                      child: Text(
                        _start == null ? '시작일' : _dateFmt.format(_start!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => _pickDate(isStart: false),
                      child: Text(
                        _end == null ? '종료일' : _dateFmt.format(_end!),
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                        _start = null;
                        _end = null;
                      }),
                child: const Text('날짜는 나중에 정하기'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEdit ? '저장' : '만들기'),
          ),
        ],
      ),
    );
  }
}
