import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../data/quran_data.dart';
import '../../services/repeat_settings.dart';

/// Sets up a memorisation drill: how many times each ayah repeats, how many
/// ayahs the drill covers, and how many times the whole passage is replayed.
class RepeatSheet extends StatefulWidget {
  final RepeatSettings initial;

  const RepeatSheet({super.key, required this.initial});

  @override
  State<RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<RepeatSheet> {
  late RepeatSettings _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final total = _value.perAyah * _value.rangeLength * _value.wholeRange;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('التكرار للحفظ',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('تبدأ من الآية التي تحددها',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 16),

            _counter(
              label: 'عدد الآيات',
              hint: 'كم آية يشملها التكرار',
              value: _value.rangeLength,
              min: 1,
              max: 20,
              onChanged: (v) =>
                  setState(() => _value = _value.copyWith(rangeLength: v)),
            ),
            _counter(
              label: 'تكرار كل آية',
              hint: 'كم مرة تُعاد الآية الواحدة',
              value: _value.perAyah,
              min: 1,
              max: 20,
              onChanged: (v) =>
                  setState(() => _value = _value.copyWith(perAyah: v)),
            ),
            _counter(
              label: 'تكرار المقطع',
              hint: 'كم مرة يُعاد المقطع كاملاً',
              value: _value.wholeRange,
              min: 1,
              max: 20,
              onChanged: (v) =>
                  setState(() => _value = _value.copyWith(wholeRange: v)),
            ),

            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.goldMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Text(
                _value.isActive
                    ? 'إجمالاً: $total تلاوة'
                    : 'التكرار مُطفأ — تُقرأ السورة من الآية المحددة',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textGold, fontSize: 13),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                        context, const RepeatSettings()),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.goldBorder),
                    ),
                    child: const Text('إيقاف التكرار',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _value),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('حفظ'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _counter({
    required String label,
    required String hint,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14)),
                Text(hint,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          _stepper(Icons.remove,
              value > min ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 40,
            child: Text(QuranService.toArabicDigits(value),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
          ),
          _stepper(Icons.add, value < max ? () => onChanged(value + 1) : null),
        ],
      ),
    );
  }

  Widget _stepper(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.blackSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Icon(icon,
            size: 17,
            color: onTap == null ? AppColors.textMuted : AppColors.gold),
      ),
    );
  }
}
