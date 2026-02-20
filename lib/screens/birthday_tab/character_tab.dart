import 'dart:io';
import 'package:flutter/material.dart';
import 'package:moecalendar/config/app_info.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../providers/character_provider.dart';
import '../../models/character_model.dart';
import '../../config/routes/app_routes.dart';
import '../../utils/zodiac_utils.dart';
import '../../widgets/name_avatar_widget.dart';
import '../../services/task_pool_service.dart';

enum SortType { grouped, date }

class CharacterTab extends StatefulWidget {
  const CharacterTab({super.key});

  @override
  State<CharacterTab> createState() => _CharacterTabState();
}

class _CharacterTabState extends State<CharacterTab> {
  SortType _sortType = SortType.grouped;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ImageProvider? _getAvatarProvider(String? url) {
    if (url == null) return null;
    if (url.startsWith('http')) {
      return NetworkImage(url);
    } else {
      return FileImage(File(url));
    }
  }

  /// 为 BangumiCharacter 解析列表头像：优先下载缓存本地路径 → 模型字段 → 网络 URL
  ImageProvider? _resolveBangumiListAvatar(BangumiCharacter character) {
    final taskPool = TaskPoolService();
    // 优先使用下载缓存的本地路径（grid 优先）
    final cachedPath = taskPool.getCachedListAvatar(character.id);
    if (cachedPath != null) {
      return FileImage(File(cachedPath));
    }
    // 降级到模型上的 listAvatar（可能是本地路径或网络 URL）
    return _getAvatarProvider(character.listAvatar);
  }

  int _calculateDaysLeft(Character character) {
    final now = DateTime.now();
    final nextBirthday = ZodiacUtils.getNextBirthday(character);
    return nextBirthday.difference(now).inDays;
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('手动添加'),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.addManualPath);
                },
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Bangumi'),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.addBangumiPath);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('添加自己'),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.addSelfPath);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索人物...',
                  border: InputBorder.none,
                ),
              )
            : const Text('人物列表'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          PopupMenuButton<SortType>(
            icon: const Icon(Icons.sort),
            onSelected: (SortType result) {
              setState(() {
                _sortType = result;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortType>>[
              const PopupMenuItem<SortType>(
                value: SortType.grouped,
                child: Text('默认分组'),
              ),
              const PopupMenuItem<SortType>(
                value: SortType.date,
                child: Text('按生日排序'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        child: const Icon(Icons.add),
      ),
      body: Consumer<CharacterProvider>(
        builder: (context, provider, child) {
          var characters = provider.characters.toList();
          if (characters.isEmpty) {
            return const Center(child: Text('暂无人物，点击右上角添加'));
          }

          // Filter
          if (_searchQuery.isNotEmpty) {
            characters = characters.where((c) {
              final name = c.name.toLowerCase();
              final query = _searchQuery.toLowerCase();
              return name.contains(query);
            }).toList();
          }

          if (characters.isEmpty) {
            return const Center(child: Text('未找到匹配人物'));
          }

          if (_sortType == SortType.date) {
            final sortedList = List<Character>.from(characters);
            sortedList.sort(
              (a, b) => _calculateDaysLeft(a).compareTo(_calculateDaysLeft(b)),
            );

            return ListView.builder(
              itemExtent: AppInfo.kCharacterListItemHeight,
              itemCount: sortedList.length,
              itemBuilder: (context, index) {
                final character = sortedList[index];
                return ListTile(
                  onTap: () {
                    context.push(
                      AppRoutes.characterDetailPath,
                      extra: character,
                    );
                  },
                  leading: character is BangumiCharacter
                      ? CircleAvatar(
                          backgroundImage: _resolveBangumiListAvatar(character),
                          backgroundColor: character.avatarColor != null
                              ? Color(character.avatarColor!)
                              : null,
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: NameAvatarWidget(
                            name:
                                character is ManualCharacter && character.isSelf
                                ? '你'
                                : character.name,
                            size: 40,
                            isSelf:
                                character is ManualCharacter &&
                                character.isSelf,
                            avatarColor: character.avatarColor,
                          ),
                        ),
                  title: Text(
                    character.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    character.birthYear != null
                        ? DateFormat('yyyy年MM月dd日').format(character.date)
                        : DateFormat('MM月dd日').format(character.date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text('${_calculateDaysLeft(character)}天'),
                );
              },
            );
          } else {
            // Grouped
            final manualCharacters = characters
                .whereType<ManualCharacter>()
                .toList();
            final bangumiCharacters = characters
                .whereType<BangumiCharacter>()
                .toList();

            return CustomScrollView(
              slivers: [
                if (manualCharacters.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        '手动添加',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final character = manualCharacters[index];
                      return ListTile(
                        onTap: () {
                          context.push(
                            AppRoutes.characterDetailPath,
                            extra: character,
                          );
                        },
                        title: Text(
                          character.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          character.birthYear != null
                              ? DateFormat('yyyy年MM月dd日').format(character.date)
                              : DateFormat('MM月dd日').format(character.date),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }, childCount: manualCharacters.length),
                  ),
                ],
                if (bangumiCharacters.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Bangumi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final character = bangumiCharacters[index];
                      return ListTile(
                        onTap: () {
                          context.push(
                            AppRoutes.characterDetailPath,
                            extra: character,
                          );
                        },
                        leading: _resolveBangumiListAvatar(character) != null
                            ? CircleAvatar(
                                backgroundImage: _resolveBangumiListAvatar(
                                  character,
                                ),
                                backgroundColor: character.avatarColor != null
                                    ? Color(character.avatarColor!)
                                    : null,
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: NameAvatarWidget(
                                  name: character.name,
                                  size: 40,
                                  avatarColor: character.avatarColor,
                                ),
                              ),
                        title: Text(
                          character.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          character.birthYear != null
                              ? DateFormat('yyyy年MM月dd日').format(character.date)
                              : DateFormat('MM月dd日').format(character.date),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }, childCount: bangumiCharacters.length),
                  ),
                ],
              ],
            );
          }
        },
      ),
    );
  }
}
