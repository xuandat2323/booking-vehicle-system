import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/network/dio_provider.dart';

class PaymentWebviewScreen extends ConsumerStatefulWidget {
  const PaymentWebviewScreen({super.key, required this.paymentUrl});

  final String paymentUrl;

  @override
  ConsumerState<PaymentWebviewScreen> createState() => _PaymentWebviewScreenState();
}

class _PaymentWebviewScreenState extends ConsumerState<PaymentWebviewScreen> {
  late final WebViewController _controller;
  bool _pageLoading = true;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _pageLoading = true),
          onPageFinished: (_) => setState(() => _pageLoading = false),
          onWebResourceError: (_) => setState(() => _pageLoading = false),
          onNavigationRequest: (request) {
            if (request.url.contains('/api/payments/vnpay/return')) {
              // Intercept before webview tries to navigate to the return URL.
              // Extract VNPay params from the URL and confirm via backend JSON API.
              _handleReturnUrl(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  Future<void> _handleReturnUrl(String url) async {
    if (_confirming || !mounted) return;
    setState(() => _confirming = true);

    try {
      final uri = Uri.parse(url);
      // Pass all VNPay query params to backend for signature verification
      final params = Map<String, String>.from(uri.queryParameters);

      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/api/payments/vnpay/confirm',
        data: params,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final success = response.data['data'] == true;
      if (mounted) Navigator.of(context).pop(success);
    } on DioException catch (e) {
      // Network error → treat as failure, let user retry
      if (mounted) {
        setState(() => _confirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xác nhận thanh toán: ${e.message}')),
        );
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán VNPay'),
        actions: [
          if (_confirming)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_pageLoading && !_confirming)
            const Center(child: CircularProgressIndicator()),
          if (_confirming)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Đang xác nhận thanh toán...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
