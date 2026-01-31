import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/character_provider.dart';
import '../../models/character_model.dart';
import '../../config/routes/app_routes.dart';
import '../../utils/zodiac_utils.dart';
import '../../widgets/local_character_list_item.dart';
import '../../config/design_constants.dart';

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

  // 多选相关
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

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

  int _calculateDaysLeft(Character character) {
    final now = DateTime.now();
    final nextBirthday = ZodiacUtils.getNextBirthday(character);
    return nextBirthday.difference(now).inDays;
  }

  void _enterSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<Character> characters) {
    setState(() {
      if (_selectedIds.length == characters.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(characters.map((e) => e.id));
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    // 检查是否包含自己
    final provider = Provider.of<CharacterProvider>(context, listen: false);
    final hasSelf = _selectedIds.any((id) {
      final character = provider.characters.firstWhere(
        (c) => c.id == id,
        orElse: () => ManualCharacter(
          id: '',
          notificationId: 0,
          name: '',
          birthMonth: 1,
          birthDay: 1,
          notify: false,
        ),
      );
      return character is ManualCharacter && character.isSelf;
    });

    if (hasSelf) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('不能删除自己的生日信息，请取消选择后重试')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${_selectedIds.length} 个角色吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final id in _selectedIds) {
        final character = provider.characters.firstWhere(
          (c) => c.id == id,
          orElse: () => ManualCharacter(
            id: '',
            notificationId: 0,
            name: '',
            birthMonth: 1,
            birthDay: 1,
            notify: false,
          ),
        );
        if (character.id.isNotEmpty) {
          await provider.deleteCharacter(character.id);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 ${_selectedIds.length} 个角色')),
        );
        _exitSelectionMode();
      }
    }
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: DesignConstants.spacing,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: DesignConstants.spacing,
                  ),
                  child: Text(
                    '添加新角色',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: DesignConstants.spacingSm),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: DesignConstants.spacingLg,
                    vertical: DesignConstants.spacingSm,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.edit,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: const Text('手动添加'),
                  subtitle: const Text('自定义输入角色信息'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.addManualPath);
                  },
                ),
                const SizedBox(height: DesignConstants.spacingXs),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: DesignConstants.spacingLg,
                    vertical: DesignConstants.spacingSm,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.secondaryContainer,
                    child: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  title: const Text('Bangumi'),
                  subtitle: const Text('搜索或从收藏导入角色'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.addBangumiPath);
                  },
                ),
                const SizedBox(height: DesignConstants.spacing),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, child) {
        var characters = provider.characters.toList();

        // Filter
        if (_searchQuery.isNotEmpty) {
          characters = characters.where((c) {
            final name = c.name.toLowerCase();
            final query = _searchQuery.toLowerCase();
            return name.contains(query);
          }).toList();
        }

        return Scaffold(
          appBar: AppBar(
            title: _isSelectionMode
                ? Text('已选择 ${_selectedIds.length} 个')
                : _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '搜索人物...',
                      border: InputBorder.none,
                    ),
                  )
                : const Text('人物列表'),
            leading: _isSelectionMode
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _exitSelectionMode,
                  )
                : null,
            actions: _isSelectionMode
                ? [
                    TextButton(
                      onPressed: () => _selectAll(characters),
                      child: Text(
                        _selectedIds.length == characters.length
                            ? '取消全选'
                            : '全选',
                      ),
                    ),
                  ]
                : [
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
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<SortType>>[
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
          floatingActionButton: _isSelectionMode && _selectedIds.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete),
                  label: Text('删除 ${_selectedIds.length} 个'),
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onErrorContainer,
                )
              : FloatingActionButton(
                  onPressed: () => _showAddOptions(context),
                  child: const Icon(Icons.add),
                ),
          body: _buildBody(characters),
        );
      },
    );
  }

  Widget _buildBody(List<Character> characters) {
    if (characters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 64,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(height: DesignConstants.iconSizeLg),
            Text(
              _searchQuery.isNotEmpty ? '未找到匹配人物' : '暂无人物',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: DesignConstants.spacingSm),
            Text(
              _searchQuery.isNotEmpty ? '尝试其他关键词' : '点击右下角按钮添加',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      );
    }

    // 分离"自己"和其他角色
    ManualCharacter? selfCharacter;
    final otherCharacters = <Character>[];
    for (final c in characters) {
      if (c is ManualCharacter && c.isSelf) {
        selfCharacter = c;
      } else {
        otherCharacters.add(c);
      }
    }

    if (_sortType == SortType.date) {
      final sortedList = List<Character>.from(otherCharacters);
      sortedList.sort(
        (a, b) => _calculateDaysLeft(a).compareTo(_calculateDaysLeft(b)),
      );

      // 如果有自己，插入到最前面
      if (selfCharacter != null) {
        sortedList.insert(0, selfCharacter);
      }

      return ListView.builder(
        padding: const EdgeInsets.only(
          top: DesignConstants.spacingSm,
          bottom: DesignConstants.listBottomPadding,
        ),
        itemCount: sortedList.length,
        itemBuilder: (context, index) {
          final character = sortedList[index];
          final isSelf = character is ManualCharacter && character.isSelf;

          return LocalCharacterListItem(
            character: character,
            isSelected: _selectedIds.contains(character.id),
            isSelectionMode: _isSelectionMode,
            onTap: () {
              if (isSelf) {
                // 点击自己跳转到编辑页
                context.push(AppRoutes.editSelfPath, extra: character);
              } else {
                context.push(AppRoutes.characterDetailPath, extra: character);
              }
            },
            onLongPress: () => _enterSelectionMode(character.id),
            onCheckChanged: (val) => _toggleSelection(character.id),
          );
        },
      );
    } else {
      // Grouped
      final manualCharacters = otherCharacters
          .whereType<ManualCharacter>()
          .toList();
      final bangumiCharacters = otherCharacters
          .whereType<BangumiCharacter>()
          .toList();

      return CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: SizedBox(height: DesignConstants.spacingSm),
          ),
          // 自己放在最上面
          if (selfCharacter != null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DesignConstants.spacing,
                  DesignConstants.spacingSm,
                  DesignConstants.spacing,
                  DesignConstants.spacingXs,
                ),
                child: Text(
                  '你',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: LocalCharacterListItem(
                character: selfCharacter,
                isSelected: _selectedIds.contains(selfCharacter.id),
                isSelectionMode: _isSelectionMode,
                onTap: () {
                  // 点击自己跳转到编辑页
                  context.push(AppRoutes.editSelfPath, extra: selfCharacter);
                },
                onLongPress: () => _enterSelectionMode(selfCharacter!.id),
                onCheckChanged: (val) => _toggleSelection(selfCharacter!.id),
              ),
            ),
          ],
          if (manualCharacters.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DesignConstants.spacing,
                  DesignConstants.spacing,
                  DesignConstants.spacing,
                  DesignConstants.spacingXs,
                ),
                child: Text(
                  '手动添加 (${manualCharacters.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final character = manualCharacters[index];
                return LocalCharacterListItem(
                  character: character,
                  isSelected: _selectedIds.contains(character.id),
                  isSelectionMode: _isSelectionMode,
                  onTap: () {
                    context.push(
                      AppRoutes.characterDetailPath,
                      extra: character,
                    );
                  },
                  onLongPress: () => _enterSelectionMode(character.id),
                  onCheckChanged: (val) => _toggleSelection(character.id),
                );
              }, childCount: manualCharacters.length),
            ),
          ],
          if (bangumiCharacters.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DesignConstants.spacing,
                  DesignConstants.spacing,
                  DesignConstants.spacing,
                  DesignConstants.spacingXs,
                ),
                child: Text(
                  'Bangumi (${bangumiCharacters.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final character = bangumiCharacters[index];
                return LocalCharacterListItem(
                  character: character,
                  isSelected: _selectedIds.contains(character.id),
                  isSelectionMode: _isSelectionMode,
                  onTap: () {
                    context.push(
                      AppRoutes.characterDetailPath,
                      extra: character,
                    );
                  },
                  onLongPress: () => _enterSelectionMode(character.id),
                  onCheckChanged: (val) => _toggleSelection(character.id),
                );
              }, childCount: bangumiCharacters.length),
            ),
          ],
          const SliverToBoxAdapter(
            child: SizedBox(height: DesignConstants.listBottomPadding),
          ),
        ],
      );
    }
  }
}
