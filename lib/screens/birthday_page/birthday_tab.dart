import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/character_provider.dart';
import '../../models/character_model.dart';
import '../../config/routes/app_routes.dart';
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
    if (widget.targetCharacter == null || _pageController == null) return;

    for (int i = 0; i < _currentPages.length; i++) {
      if (_currentPages[i].any((c) => c.id == widget.targetCharacter!.id)) {
        _pageController!.animateToPage(
          i,
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

    // 1. Self
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
            '${nextBirthday.year}-${nextBirthday.month}-${nextBirthday.day}';
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
// 以下未经过测试,意义不大的代码,作用是检查是否有即将到来的生日,并显示通知,我不太喜欢这个功能,哪天删掉,但不是今天
  void _checkNotifications() {
    if (!mounted) return;
    final provider = Provider.of<CharacterProvider>(context, listen: false);
    final pages = _groupCharacters(provider.characters);

    final now = DateTime.now();

    for (int i = 0; i < pages.length; i++) {
      final group = pages[i];
      if (group.first.isSelf) continue;

      final nextBirthday = ZodiacUtils.getNextBirthday(group.first);
      final diff = nextBirthday.difference(now).inSeconds;

      // T-30s
      if (diff == 30) {
        _showNotification(group, i);
      }

      // T-16s
      if (diff == 16) {
        if (_currentPageIndex == i) {
          context.push(AppRoutes.congratulateCharacter, extra: group);
        } else {
          _showNotification(group, i);
        }
      }
    }
  }

  void _showNotification(List<Character> group, int pageIndex) {
    final names = group.map((c) => c.name).join(', ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('等待 $names 生日！点击跳转'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '跳转',
          onPressed: () {
            _pageController?.animateToPage(
              pageIndex,
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
            appBar: AppBar(title: const Text('生日详情')),
            body: const Center(child: Text('还没有添加人物哦，去右侧添加吧')),
          );
        }

        final pages = _groupCharacters(characters);

        // 检查是否有今天生日的人物显示红点
        bool hasBirthdayToday = false;
        for (var c in characters) {
          if (ZodiacUtils.isBirthdayToday(
            c.birthMonth,
            c.birthDay,
            c.isLunar,
          )) {
            hasBirthdayToday = true;
            break;
          }
        }

        // 保存当前页面数据
        _currentPages = pages;

        // Initialize controller (只初始化一次)
        if (_pageController == null) {
          int initialPage = 0;
          // 如果有目标角色,定位到该角色所在页面
          if (widget.targetCharacter != null) {
            for (int i = 0; i < pages.length; i++) {
              if (pages[i].any((c) => c.id == widget.targetCharacter!.id)) {
                initialPage = i;
                break;
              }
            }
          }
          _pageController = PageController(initialPage: initialPage);
          _currentPageIndex = initialPage;
        }

        return Scaffold(
          appBar: AppBar(
            leading: Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.grid_view),
                  onPressed: () => context.push(AppRoutes.birthGridPath),
                ),
                if (hasBirthdayToday)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            title: const Text('生日详情'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => context.push(AppRoutes.settings),
              ),
            ],
          ),
          body: PageView.builder(
            controller: _pageController,
            itemCount: pages.length,
            onPageChanged: (index) {
              setState(() {
                _currentPageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final group = pages[index];
              if (group.first.isSelf) {
                return SelfBirthdayCard(character: group.first);
              }
              return BirthdayCountdownPage(characters: group);
            },
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
      _calculateTimeLeft();
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
    final days = _timeLeft.inDays;
    final hours = _timeLeft.inHours % 24;
    final minutes = _timeLeft.inMinutes % 60;
    final seconds = _timeLeft.inSeconds % 60;
    final milliseconds = _timeLeft.inMilliseconds % 1000;

    final isToday = ZodiacUtils.isBirthdayToday(
      widget.characters.first.birthMonth,
      widget.characters.first.birthDay,
      widget.characters.first.isLunar,
    );

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...widget.characters.map(
            (c) => Column(
              children: [
                Text(c.name, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (isToday) ...[
            const Text(
              '今天是生日！',
              style: TextStyle(fontSize: 24, color: Colors.pink),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                context.push(
                  AppRoutes.congratulateCharacter,
                  extra: widget.characters,
                );
              },
              child: const Text('发送祝福'),
            ),
          ] else ...[
            const Text('距离生日还有', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                _buildTimeItem(days, '天'),
                _buildTimeItem(hours, '时'),
                _buildTimeItem(minutes, '分'),
                _buildTimeItem(seconds, '秒'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '.$milliseconds',
              style: const TextStyle(fontSize: 30, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeItem(int value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
          ),
          Text(unit, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
