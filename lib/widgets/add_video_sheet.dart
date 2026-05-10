import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/transcript_api_service.dart';
import 'progress_bar.dart';

Future<void> showAddVideoSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const AddVideoSheet(),
  );
}

class AddVideoSheet extends StatefulWidget {
  const AddVideoSheet({super.key});

  @override
  State<AddVideoSheet> createState() => _AddVideoSheetState();
}

class _AddVideoSheetState extends State<AddVideoSheet> {
  final TextEditingController _controller = TextEditingController();
  ParseStep? _step;
  bool _isParsing = false;
  String? _error;

  static const _labels = ['正在解析链接', '正在获取视频信息', '正在获取字幕', '正在保存', '完成'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isParsing = true;
      _error = null;
      _step = const ParseStep(label: '准备解析', index: 0, total: 5);
    });

    try {
      await context.read<AppState>().addVideoFromYoutubeUrl(
        _controller.text,
        onProgress: (step) {
          if (!mounted) {
            return;
          }
          setState(() => _step = step);
        },
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _isParsing = false;
      });
    } on TranscriptApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _isParsing = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '解析失败，请确认 FastAPI 服务已启动且视频有字幕';
        _isParsing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final progress = _step?.progress ?? 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(34),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '添加 YouTube 链接',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                enabled: !_isParsing,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _isParsing ? null : _parse(),
                decoration: InputDecoration(
                  hintText: 'https://www.youtube.com/watch?v=...',
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(
                    color: scheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (_isParsing) ...[
                const SizedBox(height: 18),
                ProgressBar(value: progress, height: 12),
                const SizedBox(height: 14),
                ...List.generate(_labels.length, (index) {
                  final done = (_step?.index ?? 0) > index;
                  final current = (_step?.index ?? 0) == index + 1;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(
                          done
                              ? Icons.check_circle_rounded
                              : current
                              ? Icons.radio_button_checked_rounded
                              : Icons.circle_outlined,
                          size: 20,
                          color: done || current
                              ? const Color(0xFF7D8A5E)
                              : scheme.outline,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _labels[index],
                          style: TextStyle(
                            color: current
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                            fontSize: 15,
                            fontWeight: current
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: _isParsing ? null : _parse,
                  child: Text(
                    _isParsing ? '解析中' : '解析',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
