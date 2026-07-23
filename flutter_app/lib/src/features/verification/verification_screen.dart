import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';
import 'verification_provider.dart';

export 'verification_provider.dart';

// ─── Step definition ───────────────────────────────────────────────────────

enum _Step {
  cccdFront(
    icon: Icons.badge_rounded,
    label: 'CCCD mặt trước',
    hint: 'Chụp mặt trước CCCD rõ nét, đủ 4 góc',
    endpoint: '/api/verification/cccd',
    fileParam: 'image',
    needsIdRef: false,
  ),
  cccdBack(
    icon: Icons.badge_outlined,
    label: 'CCCD mặt sau',
    hint: 'Chụp mặt sau CCCD, đảm bảo QR/barcode rõ',
    endpoint: '/api/verification/cccd/back',
    fileParam: 'image',
    needsIdRef: false,
  ),
  licenseFront(
    icon: Icons.drive_eta_rounded,
    label: 'Bằng lái mặt trước',
    hint: 'Chụp mặt trước bằng lái rõ nét, đủ 4 góc',
    endpoint: '/api/verification/license',
    fileParam: 'image',
    needsIdRef: false,
  ),
  licenseBack(
    icon: Icons.drive_eta_outlined,
    label: 'Bằng lái mặt sau',
    hint: 'Chụp mặt sau bằng lái xe',
    endpoint: '/api/verification/license/back',
    fileParam: 'image',
    needsIdRef: false,
  ),
  face(
    icon: Icons.face_rounded,
    label: 'Xác thực khuôn mặt',
    hint: 'Chụp selfie nhìn thẳng, đủ ánh sáng, không đeo kính',
    endpoint: '/api/verification/face',
    fileParam: 'selfie',
    needsIdRef: true,
  );

  const _Step({
    required this.icon,
    required this.label,
    required this.hint,
    required this.endpoint,
    required this.fileParam,
    required this.needsIdRef,
  });

  final IconData icon;
  final String label;
  final String hint;
  final String endpoint;
  final String fileParam;
  final bool needsIdRef;
}

// ─── Screen ────────────────────────────────────────────────────────────────

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _picker = ImagePicker();
  final Map<_Step, bool> _uploading = {for (final s in _Step.values) s: false};
  final Map<_Step, Uint8List?> _stepPreviews = {};

  Uint8List? _cccdFrontBytes;
  String? _cccdFrontName;

  bool get _anyUploading => _uploading.values.any((v) => v);

  Future<void> _pickAndUpload(_Step step,
      {ImageSource source = ImageSource.gallery}) async {
    if (_anyUploading) return;

    final picked =
        await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    // Show preview immediately before upload
    if (mounted) setState(() => _stepPreviews[step] = bytes);

    setState(() => _uploading[step] = true);

    try {
      final dio = ref.read(dioProvider);
      final FormData form;

      if (step == _Step.cccdFront) {
        _cccdFrontBytes = bytes;
        _cccdFrontName = picked.name;
      }

      if (step == _Step.face) {
        if (_cccdFrontBytes == null) {
          _showSnack('Vui lòng upload CCCD mặt trước trước khi xác thực khuôn mặt',
              Colors.orange);
          return;
        }
        form = FormData.fromMap({
          'selfie': MultipartFile.fromBytes(bytes, filename: picked.name),
          'idImage': MultipartFile.fromBytes(_cccdFrontBytes!,
              filename: _cccdFrontName ?? 'cccd.jpg'),
        });
      } else {
        form = FormData.fromMap({
          step.fileParam: MultipartFile.fromBytes(bytes, filename: picked.name),
        });
      }

      final response = await dio.post(step.endpoint, data: form);
      final data =
          response.data['data'] as Map<String, dynamic>? ?? {};

      if (!mounted) return;
      ref.invalidate(verificationStatusProvider);

      final isSpoofed = data['isSpoofed'] == true;
      final ocrOk = data['ocrSuccess'] == true;
      final faceVerified = data['faceMatchVerified'] == true;
      final isLive = data['isLive'] == true;

      String msg;
      Color color;

      if (step == _Step.face) {
        if (!isLive) {
          msg = 'Không phát hiện khuôn mặt sống — vui lòng chụp lại';
          color = Colors.red;
        } else if (faceVerified) {
          final score =
              ((data['faceMatchScore'] ?? 0) * 100).toStringAsFixed(0);
          msg = 'Khuôn mặt khớp $score% — xác thực thành công!';
          color = Colors.green;
        } else {
          final score =
              ((data['faceMatchScore'] ?? 0) * 100).toStringAsFixed(0);
          msg = 'Khuôn mặt không khớp ($score%) — vui lòng thử lại';
          color = Colors.orange;
        }
      } else if (isSpoofed) {
        msg = 'Phát hiện giấy tờ giả mạo!';
        color = Colors.red;
      } else if (ocrOk) {
        msg = '${step.label} xác minh thành công!';
        color = Colors.green;
      } else if (step == _Step.cccdBack || step == _Step.licenseBack) {
        msg = '${step.label} hợp lệ!';
        color = Colors.green;
      } else {
        msg = 'Không nhận dạng được ảnh — vui lòng chụp lại rõ hơn';
        color = Colors.orange;
      }

      _showSnack(msg, color);
    } on DioException catch (e) {
      if (mounted) _showSnack('Lỗi kết nối: ${e.message}', Colors.red);
    } catch (e) {
      if (mounted) _showSnack('Lỗi: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _uploading[step] = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Source picker ──────────────────────────────────────────────────────────
  void _showSourcePicker(_Step step) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text('Chọn nguồn ảnh',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(context);
                _showCameraGuide(step); // show guide before opening camera
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(step, source: ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Camera guide sheet ─────────────────────────────────────────────────────
  void _showCameraGuide(_Step step) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CameraGuideSheet(
        step: step,
        onConfirm: () {
          Navigator.pop(context);
          _pickAndUpload(step, source: ImageSource.camera);
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(verificationStatusProvider);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration:
                    const BoxDecoration(gradient: AppTheme.heroGradient),
                padding:
                    const EdgeInsets.fromLTRB(24, 88, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Xác minh danh tính',
                        style: tt.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                    Text('Hoàn tất 5 bước để thuê xe dễ dàng',
                        style: tt.bodySmall
                            ?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            title: const Text('Xác minh danh tính'),
          ),

          statusAsync.when(
            data: (status) => SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _OverallBadge(
                      status: status['status']?.toString() ?? 'UNVERIFIED'),
                  const SizedBox(height: 20),

                  _ProgressBar(status: status),
                  const SizedBox(height: 24),

                  _StepCard(
                    step: _Step.cccdFront,
                    verified: status['cccdVerified'] == true,
                    spoofed: status['cccdSpoofed'] == true,
                    uploading: _uploading[_Step.cccdFront]!,
                    previewBytes: _stepPreviews[_Step.cccdFront],
                    extractedInfo: status['cccdVerified'] == true
                        ? '${status['fullName']}  •  ${status['cccdNumber']}'
                        : null,
                    onTap: () => _showSourcePicker(_Step.cccdFront),
                  ),
                  const SizedBox(height: 12),

                  _StepCard(
                    step: _Step.cccdBack,
                    verified: status['cccdBackVerified'] == true,
                    spoofed: status['cccdBackSpoofed'] == true,
                    uploading: _uploading[_Step.cccdBack]!,
                    previewBytes: _stepPreviews[_Step.cccdBack],
                    onTap: () => _showSourcePicker(_Step.cccdBack),
                  ),
                  const SizedBox(height: 12),

                  _StepCard(
                    step: _Step.licenseFront,
                    verified: status['licenseVerified'] == true,
                    spoofed: status['licenseSpoofed'] == true,
                    uploading: _uploading[_Step.licenseFront]!,
                    previewBytes: _stepPreviews[_Step.licenseFront],
                    extractedInfo: status['licenseVerified'] == true
                        ? 'Hạng ${status['licenseClass'] ?? '?'}'
                        : null,
                    onTap: () => _showSourcePicker(_Step.licenseFront),
                  ),
                  const SizedBox(height: 12),

                  _StepCard(
                    step: _Step.licenseBack,
                    verified: status['licenseBackVerified'] == true,
                    spoofed: status['licenseBackSpoofed'] == true,
                    uploading: _uploading[_Step.licenseBack]!,
                    previewBytes: _stepPreviews[_Step.licenseBack],
                    onTap: () => _showSourcePicker(_Step.licenseBack),
                  ),
                  const SizedBox(height: 12),

                  _FaceStepCard(
                    verified: status['faceMatchVerified'] == true,
                    isLive: status['livenessVerified'] == true,
                    faceScore:
                        (status['faceMatchScore'] as num?)?.toDouble() ??
                            0.0,
                    uploading: _uploading[_Step.face]!,
                    previewBytes: _stepPreviews[_Step.face],
                    cccdFrontUploaded: status['cccdVerified'] == true,
                    onTap: () => _showSourcePicker(_Step.face),
                  ),
                  const SizedBox(height: 28),

                  _TipsCard(),
                ]),
              ),
            ),
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline_rounded, size: 48),
                  const SizedBox(height: 12),
                  Text('Lỗi: $e'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        ref.invalidate(verificationStatusProvider),
                    child: const Text('Thử lại'),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Camera guide sheet ────────────────────────────────────────────────────

class _CameraGuideSheet extends StatelessWidget {
  const _CameraGuideSheet({required this.step, required this.onConfirm});

  final _Step step;
  final VoidCallback onConfirm;

  bool get _isFace => step == _Step.face;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final tips = _isFace
        ? const [
            'Nhìn thẳng vào camera, giữ khuôn mặt trong khung',
            'Đảm bảo đủ ánh sáng, tránh ngược sáng',
            'Không đeo kính, khẩu trang hoặc mũ',
            'Giữ điện thoại ngang tầm mắt',
          ]
        : const [
            'Đặt giấy tờ trên nền phẳng, màu tối',
            'Đảm bảo đủ 4 góc giấy tờ trong khung',
            'Tránh phản sáng và bóng che khuất',
            'Giữ điện thoại song song với giấy tờ',
          ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text(
              _isFace ? 'Hướng dẫn chụp selfie' : 'Hướng dẫn chụp giấy tờ',
              style:
                  tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),

            // Frame illustration
            _FrameIllustration(isFace: _isFace, step: step),
            const SizedBox(height: 24),

            // Tips
            ...tips.map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 18, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(tip, style: tt.bodyMedium)),
                    ],
                  ),
                )),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Mở camera'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Frame illustration ────────────────────────────────────────────────────

class _FrameIllustration extends StatelessWidget {
  const _FrameIllustration({required this.isFace, required this.step});

  final bool isFace;
  final _Step step;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (isFace) {
      return Container(
        width: 160,
        height: 200,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(80),
          border: Border.all(color: cs.primary, width: 2.5),
        ),
        child: Icon(Icons.face_rounded,
            size: 72, color: cs.primary.withValues(alpha: 0.25)),
      );
    }

    return Container(
      width: 260,
      height: 160,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Corner markers
          Positioned(
              top: 0,
              left: 0,
              child: CustomPaint(
                  size: const Size(24, 24),
                  painter: _CornerPainter(color: cs.primary))),
          Positioned(
              top: 0,
              right: 0,
              child: Transform.scale(
                  scaleX: -1,
                  child: CustomPaint(
                      size: const Size(24, 24),
                      painter: _CornerPainter(color: cs.primary)))),
          Positioned(
              bottom: 0,
              left: 0,
              child: Transform.scale(
                  scaleY: -1,
                  child: CustomPaint(
                      size: const Size(24, 24),
                      painter: _CornerPainter(color: cs.primary)))),
          Positioned(
              bottom: 0,
              right: 0,
              child: Transform.scale(
                  scaleX: -1,
                  scaleY: -1,
                  child: CustomPaint(
                      size: const Size(24, 24),
                      painter: _CornerPainter(color: cs.primary)))),
          Center(
            child: Icon(step.icon,
                size: 48, color: cs.primary.withValues(alpha: 0.2)),
          ),
        ],
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Overall badge ─────────────────────────────────────────────────────────

class _OverallBadge extends StatelessWidget {
  const _OverallBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final (icon, color, label) = switch (status) {
      'VERIFIED' => (
          Icons.verified_rounded,
          Colors.green,
          'Đã xác minh đầy đủ — có thể thuê xe'
        ),
      'PENDING' => (
          Icons.pending_rounded,
          Colors.orange,
          'Đã xác minh một phần — hoàn tất các bước còn lại'
        ),
      'REJECTED' => (
          Icons.cancel_rounded,
          cs.error,
          'Xác minh thất bại — giấy tờ không hợp lệ'
        ),
      _ => (
          Icons.info_outline_rounded,
          cs.outline,
          'Chưa xác minh — hoàn tất 5 bước bên dưới'
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: tt.titleSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ─── Progress bar ──────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.status});
  final Map<String, dynamic> status;

  int get _completed {
    int n = 0;
    if (status['cccdVerified'] == true) n++;
    if (status['cccdBackVerified'] == true) n++;
    if (status['licenseVerified'] == true) n++;
    if (status['licenseBackVerified'] == true) n++;
    if (status['faceMatchVerified'] == true) n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = _completed;
    final pct = done / 5;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Tiến độ xác minh',
            style: Theme.of(context).textTheme.labelMedium),
        const Spacer(),
        Text('$done/5 bước',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.primary, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: pct,
          minHeight: 8,
          backgroundColor: cs.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation(
              pct == 1.0 ? Colors.green : cs.primary),
        ),
      ),
    ]);
  }
}

// ─── Step card (documents) ─────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.verified,
    required this.spoofed,
    required this.uploading,
    required this.onTap,
    this.previewBytes,
    this.extractedInfo,
  });

  final _Step step;
  final bool verified;
  final bool spoofed;
  final bool uploading;
  final Uint8List? previewBytes;
  final String? extractedInfo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final (stateColor, stateLabel) = spoofed
        ? (cs.error, 'Giả mạo')
        : verified
            ? (Colors.green, 'Đã xác minh')
            : (cs.outline, 'Chưa xác minh');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: [AppTheme.softShadow],
        border: verified
            ? Border.all(color: Colors.green.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Preview thumbnail or icon
          if (previewBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(previewBytes!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  cacheWidth: 88),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(step.icon, color: cs.primary, size: 20),
            ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(step.label,
                    style:
                        tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                Text(step.hint,
                    style: tt.bodySmall?.copyWith(color: cs.outline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ])),
          const SizedBox(width: 8),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: _StatusChip(label: stateLabel, color: stateColor),
            ),
          ),
        ]),
        if (extractedInfo != null) ...[
          const SizedBox(height: 10),
          _ExtractedRow(info: extractedInfo!),
        ],
        const SizedBox(height: 14),
        _UploadButton(
          verified: verified,
          uploading: uploading,
          onTap: onTap,
        ),
      ]),
    );
  }
}

// ─── Face step card ────────────────────────────────────────────────────────

class _FaceStepCard extends StatelessWidget {
  const _FaceStepCard({
    required this.verified,
    required this.isLive,
    required this.faceScore,
    required this.uploading,
    required this.cccdFrontUploaded,
    required this.onTap,
    this.previewBytes,
  });

  final bool verified;
  final bool isLive;
  final double faceScore;
  final bool uploading;
  final bool cccdFrontUploaded;
  final Uint8List? previewBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final step = _Step.face;

    final (stateColor, stateLabel) = verified
        ? (Colors.green, 'Đã xác thực')
        : (cs.outline, 'Chưa xác thực');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: [AppTheme.softShadow],
        border: verified
            ? Border.all(color: Colors.green.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Preview thumbnail or icon
          if (previewBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.memory(previewBytes!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  cacheWidth: 88),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(step.icon, color: cs.primary, size: 20),
            ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(step.label,
                    style:
                        tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                Text(step.hint,
                    style: tt.bodySmall?.copyWith(color: cs.outline),
                    maxLines: 2),
              ])),
          _StatusChip(label: stateLabel, color: stateColor),
        ]),

        if (faceScore > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (verified ? Colors.green : Colors.orange)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(
                isLive
                    ? Icons.face_retouching_natural_rounded
                    : Icons.no_photography_rounded,
                color: isLive ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                isLive
                    ? 'Khuôn mặt thật  •  Khớp ${(faceScore * 100).toStringAsFixed(0)}%'
                    : 'Không phát hiện khuôn mặt sống',
                style:
                    tt.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              ),
            ]),
          ),
        ],

        if (!cccdFrontUploaded) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 14, color: cs.outline),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Hoàn tất CCCD mặt trước trước',
                  style: tt.bodySmall?.copyWith(color: cs.outline)),
            ),
          ]),
        ],

        const SizedBox(height: 14),
        _UploadButton(
          verified: verified,
          uploading: uploading,
          onTap: cccdFrontUploaded ? onTap : null,
          disabledLabel: 'Cần upload CCCD trước',
          uploadLabel: 'Chụp selfie xác thực',
          uploadedLabel: 'Chụp lại selfie',
        ),
      ]),
    );
  }
}

// ─── Shared small widgets ──────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
        ),
      );
}

class _ExtractedRow extends StatelessWidget {
  const _ExtractedRow({required this.info});
  final String info;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded,
              color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(info,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w500))),
        ]),
      );
}

class _UploadButton extends StatelessWidget {
  const _UploadButton({
    required this.verified,
    required this.uploading,
    required this.onTap,
    this.disabledLabel = 'Không khả dụng',
    this.uploadLabel = 'Chụp ảnh / Chọn từ thư viện',
    this.uploadedLabel = 'Upload lại',
  });

  final bool verified;
  final bool uploading;
  final VoidCallback? onTap;
  final String disabledLabel;
  final String uploadLabel;
  final String uploadedLabel;

  @override
  Widget build(BuildContext context) {
    final label = uploading
        ? 'Đang xử lý...'
        : onTap == null
            ? disabledLabel
            : verified
                ? uploadedLabel
                : uploadLabel;

    final icon = uploading
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2))
        : Icon(
            onTap == null
                ? Icons.lock_outline_rounded
                : verified
                    ? Icons.refresh_rounded
                    : Icons.camera_alt_rounded,
            size: 18,
          );

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: uploading ? null : onTap,
        icon: icon,
        label: Text(label),
      ),
    );
  }
}

// ─── Tips card ─────────────────────────────────────────────────────────────

class _TipsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border:
            Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.tips_and_updates_rounded,
              color: cs.primary, size: 18),
          const SizedBox(width: 8),
          Text('Lưu ý khi chụp ảnh',
              style: tt.labelLarge?.copyWith(color: cs.primary)),
        ]),
        const SizedBox(height: 10),
        for (final tip in const [
          'Giấy tờ: đặt trên nền phẳng, ánh sáng đều, đủ 4 góc, không phản sáng',
          'Mặt sau CCCD: đảm bảo barcode/QR code hiển thị rõ',
          'Selfie: nhìn thẳng vào camera, đủ ánh sáng, không đeo kính',
          'Ảnh tối thiểu 300KB, không bị mờ, nghiêng hoặc bị che khuất',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ',
                      style: tt.bodySmall?.copyWith(color: cs.primary)),
                  Expanded(child: Text(tip, style: tt.bodySmall)),
                ]),
          ),
      ]),
    );
  }
}
