import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/character_provider.dart';
import '../../models/character_model.dart';
import '../../config/routes/app_routes.dart';
import '../../utils/zodiac_utils.dart';

class BirthdayGridScreen extends StatefulWidget {
  const BirthdayGridScreen({super.key});

  @override
  State<BirthdayGridScreen> createState() => _BirthdayGridScreenState();
}

class _BirthdayGridScreenState extends State<BirthdayGridScreen> {
  bool _isAscending = true;

  int _calculateDaysLeft(Character character) {
    final now = DateTime.now();
    final nextBirthday = ZodiacUtils.getNextBirthday(character);
    return nextBirthday.difference(now).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('生日概览'),
        actions: [
          IconButton(
            icon: Icon(
              _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
            ),
            tooltip: _isAscending ? '按生日升序' : '按生日降序',
            onPressed: () {
              setState(() {
                _isAscending = !_isAscending;
              });
            },
          ),
        ],
      ),
      body: Consumer<CharacterProvider>(
        builder: (context, provider, child) {
          final characters = provider.characters;
          if (characters.isEmpty) {
            return const Center(child: Text('暂无人物'));
          }

          // Sort by days left
          final sortedList = List<Character>.from(characters);
          sortedList.sort((a, b) {
            final daysA = _calculateDaysLeft(a);
            final daysB = _calculateDaysLeft(b);
            return _isAscending
                ? daysA.compareTo(daysB)
                : daysB.compareTo(daysA);
          });

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85, // Taller cards for better balance
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: sortedList.length,
            itemBuilder: (context, index) {
              final character = sortedList[index];
              final daysLeft = _calculateDaysLeft(character);
              final isToday = ZodiacUtils.isBirthdayToday(
                character.birthMonth,
                character.birthDay,
                character.isLunar,
              );

              return GestureDetector(
                onTap: () {
                  // 返回主页并定位到该角色
                  context.go(AppRoutes.birthTab, extra: character);
                },
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 上半部分:倒计时或蛋糕图标
                        Flexible(
                          flex: 3,
                          child: Center(
                            child: isToday
                                ? const Icon(
                                    Icons.cake,
                                    size: 64,
                                    color: Colors.pink,
                                  )
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '$daysLeft',
                                          style: TextStyle(
                                            fontSize: 48,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                          ),
                                        ),
                                        const Text(
                                          '天',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 下半部分:名字和日期
                        Flexible(
                          flex: 2,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    character.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MM-dd').format(character.date),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
