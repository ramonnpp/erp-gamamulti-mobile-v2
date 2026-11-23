import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ActivityLogDetailSheet extends StatelessWidget {
  final Map<String, dynamic> log;
  final String formattedActivityDate;
  final String formattedCreatedAt;

  const ActivityLogDetailSheet({
    super.key,
    required this.log,
    required this.formattedActivityDate,
    required this.formattedCreatedAt,
  });

  static void show(
    BuildContext context, {
    required Map<String, dynamic> log,
    required String formattedActivityDate,
    required String formattedCreatedAt,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ActivityLogDetailSheet(
        log: log,
        formattedActivityDate: formattedActivityDate,
        formattedCreatedAt: formattedCreatedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Text(
                  formattedActivityDate,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              log['log']?.toString() ?? '',
              style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, height: 1.6),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(formattedCreatedAt, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Tutup',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
