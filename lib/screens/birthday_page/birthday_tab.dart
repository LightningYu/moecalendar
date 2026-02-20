import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/character_provider.dart';
import '../../models/character_model.dart';
import '../../config/routes/app_routes.dart';
import '../../config/design_constants.dart';
import '../../utils/zodiac_utils.dart';
import 'self_birthday_card.dart';

class BirthdayTab extends StatefulWidget {
  final Character? targetCharacter;
  const BirthdayTab({super.key, this.targetCharacter});

  @override
  State<BirthdayTab> createState() => _BirthdayTabState();
}

class _BirthdayTabState extends State<BirthdayTab> {
  PageController? _pageController;
  Timer? _notificationTimer;
  int _currentPageIndex = 0;
  List<List<Character>> _currentPages = [];

  @override
  void initState() {
    super.initState();
    _notificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkNotifications();
    });
  }

  @override
  void didUpdateWidget(BirthdayTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果 targetCharacter 变化,跳转到对应页面
    if (widget.targetCharacter != null &&
        widget.targetCharacter != oldWidget.targetCharacter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToTargetCharacter();
      });
    }
  }

  void _jumpToTargetCharacter() {
    if (widget.targetCharacter == null ||
        _pageController == null ||
        _currentPages.isEmpty)
      return;

    final pageCount = _currentPages.length;
    for (int i = 0; i < pageCount; i++) {
      if (_currentPages[i].any((c) => c.id == widget.targetCharacter!.id)) {
        final currentAbsolutePage =
            _pageController!.page?.round() ?? _pageController!.initialPage;
        final currentModulo = currentAbsolutePage % pageCount;
        final difference = i - currentModulo;

        _pageController!.animateToPage(
          currentAbsolutePage + difference,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        break;
      }
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  List<List<Character>> _groupCharacters(List<Character> characters) {
    List<List<Character>> pages = [];

    // 1. Self - 放到第一页
    final self = characters.where((c) => c.isSelf).toList();
    if (self.isNotEmpty) {
      pages.add(self);
    }

    // 2. Others
    final others = characters.where((c) => !c.isSelf).toList();
    if (others.isNotEmpty) {
      Map<String, List<Character>> groups = {};
      for (var c in others) {
        final nextBirthday = ZodiacUtils.getNextBirthday(c);
        final key =
            '${nextBirthday.year}-${nextBirthday.month.toString().padLeft(2, '0')}-${nextBirthday.day.toString().padLeft(2, '0')}';
        if (!groups.containsKey(key)) {
          groups[key] = [];
        }
        groups[key]!.add(c);
      }

      // Sort groups by date
      final sortedKeys = groups.keys.toList()..sort();
      for (var key in sortedKeys) {
        pages.add(groups[key]!);
      }
    }

    return pages;
  }

  void _checkNotifications() {
    if (!mounted || _currentPages.isEmpty) return;
    final provider = Provider.of<CharacterProvider>(context, listen: false);
    final pages = _groupCharacters(provider.characters);
    final pageCount = pages.length;

    final now = DateTime.now();

    for (int i = 0; i < pageCount; i++) {
      final group = pages[i];
      if (group.first.isSelf) continue;

      final nextBirthday = ZodiacUtils.getNextBirthday(group.first);
      final diff = nextBirthday.difference(now).inSeconds;

      // 距离生日30秒提醒一次
      if (diff == 30) {
        _showNotification(group, i, pageCount);
      }

      // 距离生日16秒时，如果在该页则自动跳转动画页，否则再提醒一次
      if (diff == 16) {
        if (_currentPageIndex == i) {
          context.push(AppRoutes.congratulateCharacter, extra: group);
        } else {
          _showNotification(group, i, pageCount);
        }
      }
    }
  }

  void _showNotification(List<Character> group, int pageIndex, int pageCount) {
    final names = group.map((c) => c.name).join(', ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('即将迎来 $names 的生日！'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: '查看',
          onPressed: () {
            final currentAbsolutePage = _pageController?.page?.round() ?? 0;
            final currentModulo = currentAbsolutePage % pageCount;
            // 计算跳转到目标 modulo 索引的最短路径
            int difference = pageIndex - currentModulo;

            _pageController?.animateToPage(
              currentAbsolutePage + difference,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, child) {
        final characters = provider.characters;
        if (characters.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('生日展望')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cake_outlined,
                    size: 80,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  const Text('还没有添加人物哦，去右侧添加吧'),
                ],
              ),
            ),
          );
        }

        final pages = _groupCharacters(characters);
        _currentPages = pages;
        final pageCount = pages.length;

        bool hasBirthdayToday = characters.any(
          (c) =>
              ZodiacUtils.isBirthdayToday(c.birthMonth, c.birthDay, c.isLunar),
        );

        if (_pageController == null) {
          int initialOffset = 0;
          if (widget.targetCharacter != null) {
            for (int i = 0; i < pageCount; i++) {
              if (pages[i].any((c) => c.id == widget.targetCharacter!.id)) {
                initialOffset = i;
                break;
              }
            }
          }
          // 为了实现首末相连，我们设置一个很大的初始页码
          const int initialBatch = 500;
          _pageController = PageController(
            initialPage: (initialBatch * pageCount) + initialOffset,
          );
          _currentPageIndex = initialOffset;
        }

        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.grid_view_rounded),
                  onPressed: () => context.push(AppRoutes.birthGridPath),
                ),
                if (hasBirthdayToday)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: const Text(
              '生日展望',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push(AppRoutes.settings),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // Page Indicator
              if (pageCount > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(pageCount, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 6,
                        width: _currentPageIndex == index ? 20 : 6,
                        decoration: BoxDecoration(
                          color: _currentPageIndex == index
                              ? colorScheme.primary
                              : colorScheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPageIndex = index % pageCount;
                    });
                  },
                  itemBuilder: (context, index) {
                    final group = pages[index % pageCount];
                    if (group.first.isSelf) {
                      return SelfBirthdayCard(character: group.first);
                    }
                    return BirthdayCountdownPage(characters: group);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class BirthdayCountdownPage extends StatefulWidget {
  final List<Character> characters;
  const BirthdayCountdownPage({super.key, required this.characters});

  @override
  State<BirthdayCountdownPage> createState() => _BirthdayCountdownPageState();
}

class _BirthdayCountdownPageState extends State<BirthdayCountdownPage> {
  late Timer _timer;
  late Duration _timeLeft;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) _calculateTimeLeft();
    });
  }

  void _calculateTimeLeft() {
    if (widget.characters.isEmpty) return;
    final now = DateTime.now();
    final nextBirthday = ZodiacUtils.getNextBirthday(widget.characters.first);
    setState(() {
      _timeLeft = nextBirthday.difference(now);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isToday = ZodiacUtils.isBirthdayToday(
      widget.characters.first.birthMonth,
      widget.characters.first.birthDay,
      widget.characters.first.isLunar,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          // 角色姓名组 - 更加显眼
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: widget.characters.map((c) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star,
                      size: 16,
                      color: Colors.orangeAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      c.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // 核心展示卡片 - 调整为全宽且内容更紧凑防止溢出
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.surfaceVariant.withOpacity(0.5),
                  colorScheme.surfaceVariant.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(DesignConstants.radiusXl),
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                if (isToday) ...[
                  const Icon(
                    Icons.cake_rounded,
                    size: 100,
                    color: Colors.pinkAccent,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'HAPPY BIRTHDAY!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.pink,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        context.push(
                          AppRoutes.congratulateCharacter,
                          extra: widget.characters,
                        );
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: Colors.pinkAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text(
                        '立即发送周年祝福',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    'BIRTHDAY COUNTDOWN',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildCountdownTimer(context),
                ],
              ],
            ),
          ),

          const SizedBox(height: 48),
          Icon(
            Icons.favorite,
            color: Colors.pinkAccent.withOpacity(0.3),
            size: 24,
          ),
          const SizedBox(height: 12),
          Text(
            '每一个生日都值得被温柔以待',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              fontStyle: FontStyle.italic,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownTimer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final days = _timeLeft.inDays;
    final hours = _timeLeft.inHours % 24;
    final minutes = _timeLeft.inMinutes % 60;
    final seconds = _timeLeft.inSeconds % 60;
    final milliseconds = _timeLeft.inMilliseconds % 1000;

    return Column(
      children: [
        // 使用 Wrap 替代 Row 解决溢出问题，并增加间距
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 16,
          children: [
            _buildTimeBox(context, days.toString().padLeft(2, '0'), 'DAYS'),
            _buildTimeBox(context, hours.toString().padLeft(2, '0'), 'HOURS'),
            _buildTimeBox(context, minutes.toString().padLeft(2, '0'), 'MINS'),
            _buildTimeBox(context, seconds.toString().padLeft(2, '0'), 'SECS'),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '.${milliseconds.toString().padLeft(3, '0')}',
            style: TextStyle(
              fontSize: 20,
              fontFamily: 'monospace',
              color: colorScheme.primary.withOpacity(0.6),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeBox(BuildContext context, String value, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 70, // 固定宽度保证整齐
          height: 70,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
