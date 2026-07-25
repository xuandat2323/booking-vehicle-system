import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/toast_utils.dart';
import '../cars/car_list_screen.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  static const _quickPrompts = [
    'Xe 7 chỗ giá rẻ',
    'VinFast điện',
    'Toyota tầm trung',
    'Chi nhánh Hoàn Kiếm',
    'Dưới 1 triệu/ngày',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      text: 'Xin chào! Mình là trợ lý GoRento.\n'
          'Hỏi mình theo hãng, số chỗ, giá hoặc chi nhánh — ví dụ bên dưới.',
      isBot: true,
      suggestions: _quickPrompts,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isBot: false));
      _isLoading = true;
    });
    if (preset == null) _controller.clear();
    _scrollToBottom();

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/api/chatbot/ask', data: {'question': text});
      final data = response.data['data'] as Map<String, dynamic>? ?? {};

      final answer = data['answer'] as String? ?? 'Xin lỗi, mình chưa hiểu câu hỏi.';
      final cars = (data['cars'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final suggestions = (data['suggestions'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const <String>[];

      setState(() {
        _messages.add(_ChatMessage(
          text: answer,
          isBot: true,
          cars: cars,
          suggestions: suggestions.isEmpty ? null : suggestions,
          relaxed: data['relaxed'] == true,
        ));
        _isLoading = false;
      });
    } catch (e) {
      final msg = e is DioException
          ? ToastUtils.mapError(e)
          : 'Xin lỗi, có lỗi xảy ra. Vui lòng thử lại!';
      setState(() {
        _messages.add(_ChatMessage(
          text: msg,
          isBot: true,
          suggestions: _quickPrompts,
        ));
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GoRento AI', style: tt.titleMedium),
                Text('Tìm xe theo ý bạn', style: tt.bodySmall),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildTypingIndicator(cs);
                }
                return _buildMessage(_messages[index], cs, tt);
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd,
                  vertical: AppTheme.spacingSm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _sendMessage(),
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: 'VD: xe 7 chỗ dưới 1 triệu…',
                          filled: true,
                          fillColor: cs.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: _isLoading ? cs.outlineVariant : cs.primary,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      child: InkWell(
                        onTap: _isLoading ? null : () => _sendMessage(),
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.send_rounded,
                            color: cs.onPrimary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(_ChatMessage message, ColorScheme cs, TextTheme tt) {
    final isBot = message.isBot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isBot) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isBot ? cs.surfaceContainerLow : cs.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isBot ? 4 : 18),
                      bottomRight: Radius.circular(isBot ? 18 : 4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.relaxed == true) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Đã nới tiêu chí để gần đúng hơn',
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        message.text,
                        style: tt.bodyMedium?.copyWith(
                          color: isBot ? cs.onSurface : cs.onPrimary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isBot && message.cars != null && message.cars!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 138,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: message.cars!.length > 6 ? 6 : message.cars!.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        return _buildCarCard(message.cars![index], cs, tt);
                      },
                    ),
                  ),
                ],
                if (isBot && message.suggestions != null && message.suggestions!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: message.suggestions!
                        .take(4)
                        .map(
                          (s) => ActionChip(
                            label: Text(s),
                            onPressed: _isLoading ? null : () => _sendMessage(s),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarCard(Map<String, dynamic> car, ColorScheme cs, TextTheme tt) {
    final carId = car['id'] ?? car['carId'];
    final title = carDisplayTitle(car['brand']?.toString(), car['name']?.toString());
    final price = car['pricePerDay'];
    final seats = car['seats'] ?? 5;
    final branch = (car['branchName'] ?? car['location'] ?? '').toString();
    final imageUrl = car['imageUrl']?.toString();

    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          if (carId != null) context.push('/cars/$carId');
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 210,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
            boxShadow: [AppTheme.softShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _carPlaceholder(cs),
                          )
                        : _carPlaceholder(cs),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title.isEmpty ? 'Xe' : title,
                      style: tt.titleSmall?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.event_seat_rounded, size: 14, color: cs.outline),
                  const SizedBox(width: 4),
                  Text('$seats chỗ', style: tt.bodySmall),
                  const Spacer(),
                  Text(
                    price != null ? '${_formatPrice(price)} đ/ngày' : '',
                    style: tt.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (branch.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  branch,
                  style: tt.bodySmall?.copyWith(fontSize: 11, color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _carPlaceholder(ColorScheme cs) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.directions_car, color: cs.outline, size: 22),
    );
  }

  String _formatPrice(dynamic price) {
    final n = double.tryParse(price.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toStringAsFixed(0);
  }

  Widget _buildTypingIndicator(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BounceDot(delay: 0, color: cs.outline),
                const SizedBox(width: 4),
                _BounceDot(delay: 150, color: cs.outline),
                const SizedBox(width: 4),
                _BounceDot(delay: 300, color: cs.outline),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isBot;
  final List<Map<String, dynamic>>? cars;
  final List<String>? suggestions;
  final bool? relaxed;

  _ChatMessage({
    required this.text,
    required this.isBot,
    this.cars,
    this.suggestions,
    this.relaxed,
  });
}

class _BounceDot extends StatefulWidget {
  final int delay;
  final Color color;

  const _BounceDot({required this.delay, required this.color});

  @override
  State<_BounceDot> createState() => _BounceDotState();
}

class _BounceDotState extends State<_BounceDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _animation.value),
        child: child,
      ),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
