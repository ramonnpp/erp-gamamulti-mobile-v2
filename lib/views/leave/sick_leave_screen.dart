import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../widgets/custom_snackbar.dart';

class SickLeaveScreen extends StatefulWidget {
  const SickLeaveScreen({super.key});

  @override
  State<SickLeaveScreen> createState() => _SickLeaveScreenState();
}

class _SickLeaveScreenState extends State<SickLeaveScreen> {
  final TextEditingController _reasonController = TextEditingController();
  DateTime? _date;
  String _duration = '1 Hari';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Izin / Sakit'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Laporkan izin atau sakit Anda dengan lengkap dan jelas.',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tanggal
            const Text(
              'Tanggal Izin / Sakit',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 7)),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) {
                  setState(() => _date = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _date?.toString().split(' ')[0] ?? 'Pilih Tanggal',
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Durasi
            const Text(
              'Durasi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButton<String>(
                value: _duration,
                isExpanded: true,
                underline: const SizedBox(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                items: ['1 Hari', '2 Hari', '3 Hari', 'Lainnya']
                    .map(
                      (dur) => DropdownMenuItem(value: dur, child: Text(dur)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _duration = value ?? '1 Hari');
                },
              ),
            ),
            const SizedBox(height: 20),

            // Alasan
            const Text(
              'Alasan / Keterangan',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Jelaskan alasan izin atau kondisi sakit Anda',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Button Submit
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (_date == null) {
                    CustomSnackbar.error(context, 'Pilih tanggal izin/sakit');
                    return;
                  }

                  final user = DatabaseService().getCurrentUser();
                  if (user == null) {
                    CustomSnackbar.error(context, 'User tidak ditemukan');
                    return;
                  }

                  // Hitung end_date berdasarkan durasi
                  int days = int.tryParse(_duration.split(' ')[0]) ?? 1;
                  DateTime endDate = _date!.add(Duration(days: days - 1));

                  final success = await DatabaseService().submitLeaveRequest(
                    userId: user['id'],
                    leaveType: 'Sakit/Izin',
                    startDate: _date.toString().split(' ')[0],
                    endDate: endDate.toString().split(' ')[0],
                    reason: _reasonController.text,
                  );

                  if (success) {
                    CustomSnackbar.success(
                      context,
                      'Laporan izin/sakit berhasil disimpan!',
                    );
                    // Reset form
                    setState(() {
                      _date = null;
                      _reasonController.clear();
                    });
                  } else {
                    CustomSnackbar.error(
                      context,
                      'Gagal menyimpan ke database',
                    );
                  }
                },
                child: const Text(
                  'Kirim Laporan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}
