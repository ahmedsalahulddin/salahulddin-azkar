import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../data/adhkar_data.dart';
import '../services/storage_service.dart';

class TasbihCounter extends StatefulWidget {
  final Dhikr dhikr;

  const TasbihCounter({super.key, required this.dhikr});

  @override
  State<TasbihCounter> createState() => _TasbihCounterState();
}

class _TasbihCounterState extends State<TasbihCounter> with SingleTickerProviderStateMixin {
  int _count = 0;
  bool _completed = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  int get _target => widget.dhikr.repetitions;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _loadCount();
  }

  Future<void> _loadCount() async {
    final c = await StorageService.getTasbihCount(widget.dhikr.id);
    if (mounted) setState(() => _count = c);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_completed) return;
    _animController.forward().then((_) => _animController.reverse());

    setState(() {
      _count++;
      if (_count >= _target) _completed = true;
    });

    HapticFeedback.lightImpact();
    if (_completed) HapticFeedback.heavyImpact();

    await StorageService.saveTasbihCount(widget.dhikr.id, _count);
  }

  Future<void> _handleReset() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _count = 0;
      _completed = false;
    });
    await StorageService.saveTasbihCount(widget.dhikr.id, 0);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _target > 0 ? (_count / _target).clamp(0.0, 1.0) : 0.0;
    final remaining = (_target - _count).clamp(0, _target);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: SafeArea(
          child: Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.88,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.blackCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleBtn('✕', () => Navigator.pop(context)),
                      const Text('عداد التسبيح', style: TextStyle(color: AppColors.gold, fontSize: 20, fontWeight: FontWeight.bold)),
                      _circleBtn('↻', _handleReset),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Dhikr text
                  Text(
                    widget.dhikr.text,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, height: 1.8),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.blackSurface,
                      valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Counter circle
                  GestureDetector(
                    onTap: _handleTap,
                    child: ScaleTransition(
                      scale: _scaleAnim,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _completed ? AppColors.success : AppColors.gold,
                            width: 3,
                          ),
                          color: _completed
                              ? const Color(0x1A4CAF50)
                              : AppColors.goldMuted,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$_count',
                              style: const TextStyle(color: AppColors.gold, fontSize: 48, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '/ $_target',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status
                  Text(
                    _completed
                        ? '✨ أتممت الذكر - جزاك الله خيراً'
                        : 'باقي $remaining ${remaining > 10 ? 'مرة' : 'مرات'}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  if (_completed)
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                      ),
                      child: const Text('تم ✓', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.blackSurface,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 20)),
        ),
      ),
    );
  }
}
