import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../widgets/custom_snackbar.dart';

class AddActivityLogSheet extends StatelessWidget {
  final VoidCallback onSuccess;

  const AddActivityLogSheet({super.key, required this.onSuccess});

  static void show(BuildContext context, {required VoidCallback onSuccess}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddActivityLogSheet(onSuccess: onSuccess),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final displayDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now());

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
        MediaQuery.of(context).viewInsets.bottom + 24,
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
          const Text(
            'Melaporkan Aktivitas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 20),
          // Tanggal readonly — hanya hari ini
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayDate,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: const BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.all(Radius.circular(8))),
                  child: const Text('Hari Ini', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: controller,
            maxLines: 8,
            maxLength: 500,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Tulis kegiatan hari ini...',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
              counterText: '',
            ),
            keyboardType: TextInputType.multiline,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) {
                CustomSnackbar.error(context, 'Isi log tidak boleh kosong.');
                return;
              }
              final ok = await DatabaseService().submitActivityLog(content: text, activityDate: today);
              if (!context.mounted) return;
              if (ok) {
                CustomSnackbar.success(context, 'Log berhasil disimpan!');
                Navigator.pop(context);
                onSuccess();
              } else {
                CustomSnackbar.error(context, 'Gagal menyimpan log. Silakan coba lagi.');
              }
            },
            style: ElevatedButton.styleFrom(
              elevation: 0,
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Simpan Log', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
