import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/dio_provider.dart';
import '../../core/utils/format_utils.dart';

/// Màn thanh toán đặt cọc — QR VietQR theo STK + nội dung chuyến thuê.
class PaymentWebviewScreen extends ConsumerStatefulWidget {
  const PaymentWebviewScreen({
    super.key,
    this.paymentUrl,
    this.paymentData,
  });

  final String? paymentUrl;
  final Map<String, dynamic>? paymentData;

  @override
  ConsumerState<PaymentWebviewScreen> createState() => _PaymentWebviewScreenState();
}

class _PaymentWebviewScreenState extends ConsumerState<PaymentWebviewScreen> {
  final GlobalKey _qrCardKey = GlobalKey();

  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  bool _confirming = false;
  bool _saving = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    if (widget.paymentData != null) {
      _data = Map<String, dynamic>.from(widget.paymentData!);
      _loading = false;
      _startPolling();
    } else {
      _error = 'Thiếu thông tin thanh toán PayOS';
      _loading = false;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  int? get _bookingId {
    final v = _data?['bookingId'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  bool get _mockMode => _data?['mockMode'] == true;
  String get _checkoutUrl => _data?['checkoutUrl']?.toString() ?? '';
  String get _qrCode => _data?['qrCode']?.toString() ?? '';
  String get _qrImageUrl => _data?['qrImageUrl']?.toString() ?? '';
  String get _paymentContent => _data?['paymentContent']?.toString() ?? '';

  void _startPolling() {
    final id = _bookingId;
    if (id == null) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkPaid(id));
  }

  Future<void> _checkPaid(int bookingId) async {
    if (_confirming || !mounted) return;
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('/api/payments/payos/status/$bookingId');
      if (resp.data['data'] == true && mounted) {
        _pollTimer?.cancel();
        Navigator.of(context).pop(true);
      }
    } catch (_) {}
  }

  Future<void> _openCheckout() async {
    if (_checkoutUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có link PayOS (đang ở chế độ demo)')),
      );
      return;
    }
    final ok = await launchUrl(
      Uri.parse(_checkoutUrl),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được trang PayOS')),
      );
    }
  }

  Future<void> _simulatePaid() async {
    final id = _bookingId;
    if (id == null) return;
    setState(() => _confirming = true);
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.post('/api/payments/payos/simulate/$id');
      if (resp.data['data'] == true && mounted) {
        _pollTimer?.cancel();
        Navigator.of(context).pop(true);
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không xác nhận được: $e')),
        );
      }
    }
    if (mounted) setState(() => _confirming = false);
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã copy $label')));
    }
  }

  Future<void> _saveQrCard() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // Đợi frame vẽ xong (ảnh mạng VietQR).
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await WidgetsBinding.instance.endOfFrame;

      final boundary = _qrCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Không chụp được QR');

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Xuất ảnh thất bại');
      final bytes = byteData.buffer.asUint8List();

      final name = 'GoRento_QR_${_bookingId ?? 'pay'}.png';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: name,
            ),
          ],
          text: _paymentContent.isEmpty ? 'QR thanh toán GoRento' : _paymentContent,
          subject: 'QR đặt cọc GoRento',
          fileNameOverrides: [name],
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã mở lưu / chia sẻ ảnh QR')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không lưu được QR: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Thanh toán đặt cọc'),
        actions: [
          if (!_loading && _error == null)
            IconButton(
              tooltip: 'Lưu QR',
              onPressed: _saving ? null : _saveQrCard,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final amount = (_data!['amount'] as num?)?.toInt() ?? 0;
    final accountNumber = _data!['accountNumber']?.toString() ?? '';
    final accountName = _data!['accountName']?.toString() ?? '';
    final carName = _data!['carName']?.toString() ?? '';
    final renterName = _data!['renterName']?.toString() ?? '';
    final rentalPeriod = _data!['rentalPeriod']?.toString() ?? '';
    final content = _paymentContent.isNotEmpty
        ? _paymentContent
        : [carName, renterName, rentalPeriod].where((e) => e.isNotEmpty).join(' - ');

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            // Hero amount
            Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primary,
                    Color.lerp(cs.primary, const Color(0xFF0A2540), 0.35)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'SỐ TIỀN ĐẶT CỌC',
                    style: tt.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    FormatUtils.vnd(amount),
                    style: tt.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                    ),
                  ),
                  if (carName.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      carName,
                      style: tt.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Capturable QR card
            RepaintBoundary(
              key: _qrCardKey,
              child: _QrPaymentCard(
                qrCode: _qrCode,
                qrImageUrl: _qrImageUrl,
                amountLabel: FormatUtils.vnd(amount),
                accountNumber: accountNumber,
                accountName: accountName,
                paymentContent: content,
                carName: carName,
                renterName: renterName,
                rentalPeriod: rentalPeriod,
                mockMode: _mockMode,
              ),
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: _saving ? null : _saveQrCard,
              icon: const Icon(Icons.save_alt_rounded),
              label: const Text('Lưu QR (kèm nội dung thanh toán)'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),
            if (content.isNotEmpty)
              TextButton.icon(
                onPressed: () => _copy('nội dung CK', content),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy nội dung chuyển khoản'),
              ),

            const SizedBox(height: 8),
            if (!_mockMode && _checkoutUrl.isNotEmpty) ...[
              FilledButton.icon(
                onPressed: _openCheckout,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Mở trang PayOS'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              const SizedBox(height: 8),
              Text(
                'Sau khi thanh toán, màn hình sẽ tự cập nhật.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (_mockMode) ...[
              FilledButton.icon(
                onPressed: _confirming ? null : _simulatePaid,
                icon: const Icon(Icons.verified_rounded),
                label: const Text('Tôi đã thanh toán (demo)'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Thanh toán sau'),
            ),
          ],
        ),
        if (_confirming)
          Container(
            color: Colors.black38,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Đang xác nhận…'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QrPaymentCard extends StatelessWidget {
  const _QrPaymentCard({
    required this.qrCode,
    required this.qrImageUrl,
    required this.amountLabel,
    required this.accountNumber,
    required this.accountName,
    required this.paymentContent,
    required this.carName,
    required this.renterName,
    required this.rentalPeriod,
    required this.mockMode,
  });

  final String qrCode;
  final String qrImageUrl;
  final String amountLabel;
  final String accountNumber;
  final String accountName;
  final String paymentContent;
  final String carName;
  final String renterName;
  final String rentalPeriod;
  final bool mockMode;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    const navy = Color(0xFF0B1F3A);
    const accent = Color(0xFF1B6EF3);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
        border: Border.all(color: const Color(0xFFE8EEF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GoRento',
                        style: tt.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Quét VietQR để đặt cọc',
                        style: tt.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (mockMode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('DEMO', style: tt.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD9E6FF)),
                  ),
                  child: _buildQrVisual(),
                ),
                const SizedBox(height: 16),
                Text(
                  amountLabel,
                  style: tt.headlineSmall?.copyWith(color: accent, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                _meta(Icons.account_balance_rounded, 'Số tài khoản', accountNumber.isEmpty ? '—' : accountNumber),
                _meta(Icons.badge_outlined, 'Chủ tài khoản', accountName.isEmpty ? '—' : accountName),
                const Divider(height: 22),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'NỘI DUNG THANH TOÁN',
                    style: tt.labelSmall?.copyWith(
                      color: Colors.black54,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE2A8)),
                  ),
                  child: Text(
                    paymentContent.isEmpty ? '—' : paymentContent,
                    style: tt.bodyMedium?.copyWith(
                      color: navy,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
                if (carName.isNotEmpty || renterName.isNotEmpty || rentalPeriod.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  if (carName.isNotEmpty) _chipRow('Xe', carName),
                  if (renterName.isNotEmpty) _chipRow('Người thuê', renterName),
                  if (rentalPeriod.isNotEmpty) _chipRow('Ngày thuê', rentalPeriod),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrVisual() {
    if (qrImageUrl.isNotEmpty) {
      return Image.network(
        qrImageUrl,
        width: 260,
        height: 260,
        fit: BoxFit.contain,
        errorBuilder: (_, error, stackTrace) => _fallbackQr(),
      );
    }
    return _fallbackQr();
  }

  Widget _fallbackQr() {
    if (qrCode.isNotEmpty) {
      return QrImageView(
        data: qrCode,
        version: QrVersions.auto,
        size: 240,
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0033C9)),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF1A1A2E),
        ),
      );
    }
    return SizedBox(
      width: 240,
      height: 240,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2_rounded, size: 72, color: Colors.blueGrey.shade300),
          const SizedBox(height: 8),
          Text(
            mockMode ? 'Cấu hình STK trong .env để hiện QR' : 'Đang tải QR…',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1B6EF3)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w600)),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0B1F3A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black45)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0B1F3A))),
          ),
        ],
      ),
    );
  }
}
