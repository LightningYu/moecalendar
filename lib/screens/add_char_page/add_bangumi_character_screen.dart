import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import '../../bangumi/bangumi.dart';
import '../../models/character_model.dart';
import '../../providers/character_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/path_manager.dart';
import '../../widgets/bangumi_character_list_item.dart';
import '../char_page/bangumi_anime_list_screen.dart';
import '../char_page/bangumi_character_list_screen.dart';
import '../char_page/character_detail_screen.dart';

class AddBangumiCharacterScreen extends StatefulWidget {
  const AddBangumiCharacterScreen({super.key});

  @override
  State<AddBangumiCharacterScreen> createState() =>
      _AddBangumiCharacterScreenState();
}

enum _AddBangumiView { search, collections }

class _AddBangumiCharacterScreenState extends State<AddBangumiCharacterScreen> {
  final TextEditingController _searchController = TextEditingController();
  final BangumiService _bangumiService = BangumiService();
  final ScrollController _scrollController = ScrollController();

  // Search State
  List<BangumiCharacterDto> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingSearch = false;
  bool _hasMoreSearch = true;
  int _searchOffset = 0;
  int _searchTotal = 0;
  static const int _limit = 20;
  String _currentKeyword = '';
  bool _isAdding = false;
  _AddBangumiView _activeView = _AddBangumiView.search;

  // 多选模式
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _isSearching = _searchController.text.isNotEmpty;
    });
  }

  void _onScroll() {
    if (_activeView != _AddBangumiView.search || !_isSearching) {
      return;
    }

    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingSearch &&
        _hasMoreSearch) {
      _loadMoreSearch();
    }
  }

  // --- Search ---

  Future<void> _search() async {
    if (_searchController.text.isEmpty) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoadingSearch = true;
      _searchResults = [];
      _searchOffset = 0;
      _searchTotal = 0;
      _hasMoreSearch = true;
      _currentKeyword = _searchController.text;
    });

    final response = await _bangumiService.searchCharacters(
      _currentKeyword,
      limit: _limit,
      offset: _searchOffset,
    );

    if (!mounted) return;

    setState(() {
      _searchResults = response.data;
      _searchTotal = response.total;
      _isLoadingSearch = false;
      _searchOffset += response.data.length;
      _hasMoreSearch = _searchOffset < _searchTotal;
    });
  }

  Future<void> _loadMoreSearch() async {
    setState(() {
      _isLoadingSearch = true;
    });

    final response = await _bangumiService.searchCharacters(
      _currentKeyword,
      limit: _limit,
      offset: _searchOffset,
    );

    if (!mounted) return;

    setState(() {
      _searchResults.addAll(response.data);
      _isLoadingSearch = false;
      _searchOffset += response.data.length;
      _hasMoreSearch = _searchOffset < _searchTotal;
    });
  }

  // --- Add ---

  Future<String?> _downloadImage(
    String url,
    String id, {
    String suffix = '',
  }) async {
    try {
      final extension = path.extension(url);
      final fileName = 'avatar_$id$suffix$extension';
      final savePath = PathManager().getImagePath(fileName);

      await Dio().download(url, savePath);
      return savePath;
    } catch (e) {
      debugPrint('Error downloading image: $e');
      return null;
    }
  }
  // 批量添加选中的角色
  Future<void> _addSelectedCharacters() async {
    if (_selectedIds.isEmpty) return;

    setState(() {
      _isAdding = true;
    });

    final provider = Provider.of<CharacterProvider>(context, listen: false);
    int addedCount = 0;
    int skippedCount = 0;

    final selectedList = _searchResults
        .where((c) => _selectedIds.contains(c.id))
        .toList();

    for (final simpleDto in selectedList) {
      final detailDto = await _bangumiService.getCharacterDetail(simpleDto.id);

      if (detailDto == null ||
          detailDto.birthMon == null ||
          detailDto.birthDay == null) {
        skippedCount++;
        continue;
      }

      final String id =
          DateTime.now().millisecondsSinceEpoch.toString() +
          addedCount.toString();
      final int notificationId =
          (DateTime.now().millisecondsSinceEpoch + addedCount) & 0x7FFFFFFF;

      String? gridPath;
      String? largePath;
      final gridImage = detailDto.avatarGridUrl;
      final largeImage = detailDto.avatarLargeUrl;

      if (gridImage != null) {
        gridPath = await _downloadImage(gridImage, id, suffix: '_grid');
      }
      if (largeImage != null) {
        largePath = await _downloadImage(largeImage, id, suffix: '_large');
      }

      final newCharacter = BangumiCharacter(
        id: id,
        notificationId: notificationId,
        name: detailDto.nameCn ?? detailDto.name,
        birthYear: detailDto.birthYear,
        birthMonth: detailDto.birthMon!,
        birthDay: detailDto.birthDay!,
        notify: true,
        avatarPath: largePath ?? largeImage,
        bangumiId: detailDto.id,
        originalData: detailDto.originalData,
        gridAvatarPath: gridPath ?? gridImage,
        largeAvatarPath: largePath ?? largeImage,
      );

      await provider.addCharacter(newCharacter);
      addedCount++;
    }

    setState(() {
      _isAdding = false;
      _selectedIds.clear();
      _isSelectionMode = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已添加 $addedCount 个角色，跳过 $skippedCount 个（无生日信息）'),
        ),
      );
    }
  }

  void _toggleSelection(int id) {
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

  void _enterSelectionMode(int id) {
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

  // --- UI Components ---

  Widget _buildSearchList() {
    if (_isLoadingSearch && _searchResults.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return _buildEmptySearchState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _searchResults.length + (_hasMoreSearch ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _searchResults.length) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final item = _searchResults[index];
        final isSelected = _selectedIds.contains(item.id);

        return BangumiCharacterListItem(
          character: item,
          isSelected: isSelected,
          isSelectionMode: _isSelectionMode,
          onTap: () {
            // 点击进入详情页
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    CharacterDetailScreen.fromBangumi(bangumiDto: item),
              ),
            );
          },
          onLongPress: () {
            // 长按进入多选模式
            _enterSelectionMode(item.id);
          },
          onCheckChanged: (val) => _toggleSelection(item.id),
        );
      },
    );
  }

  Widget _buildEmptySearchState() {
    final theme = Theme.of(context);
    final isInitial = _currentKeyword.isEmpty;
    final title = isInitial ? '搜索 Bangumi 角色' : '没有匹配的角色';
    final subtitle = isInitial
        ? '支持角色名、中文别名或作品名关键字\n长按可进入多选模式批量添加'
        : '可以尝试更换关键字，或切换到收藏标签';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isInitial ? Icons.travel_explore : Icons.sentiment_dissatisfied,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索角色、中文名或作品名',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isSearching
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              FocusScope.of(context).unfocus();
                              setState(() {
                                _searchResults = [];
                                _currentKeyword = '';
                              });
                            },
                          )
                        : null,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSearching ? _search : null,
                child: const Text('搜索'),
              ),
            ],
          ),
        ),
        Expanded(child: _buildSearchList()),
      ],
    );
  }

  Widget _buildViewSwitcher() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SegmentedButton<_AddBangumiView>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment<_AddBangumiView>(
            value: _AddBangumiView.search,
            label: Text('搜索角色'),
            icon: Icon(Icons.search),
          ),
          ButtonSegment<_AddBangumiView>(
            value: _AddBangumiView.collections,
            label: Text('我的收藏'),
            icon: Icon(Icons.collections_bookmark),
          ),
        ],
        selected: <_AddBangumiView>{_activeView},
        onSelectionChanged: (selection) {
          final next = selection.first;
          if (next == _activeView) return;
          FocusScope.of(context).unfocus();
          setState(() {
            _activeView = next;
          });
        },
      ),
    );
  }

  Widget _buildCollectionsBody() {
    final authProvider = Provider.of<AuthProvider>(context);
    if (!authProvider.isLoggedIn) {
      return _buildLoginPrompt();
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildShortcutCard(
          icon: Icons.movie,
          title: '我的动画收藏',
          subtitle: '浏览番剧条目并批量导入角色',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BangumiAnimeListScreen(),
              ),
            );
          },
        ),
        _buildShortcutCard(
          icon: Icons.person,
          title: '我的角色收藏',
          subtitle: '在 Bangumi 收藏夹中多选角色添加',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BangumiCharacterListScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '登录 Bangumi 以查看收藏',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '登录后即可快速从收藏导入角色到生日列表',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请前往设置页面登录 Bangumi')),
                );
              },
              child: const Text('前往设置'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? '已选择 ${_selectedIds.length} 个' : '添加 Bangumi 角色',
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: [
          if (_isSelectionMode)
            TextButton(
              onPressed: _selectedIds.isEmpty ? null : _addSelectedCharacters,
              child: const Text('添加'),
            ),
        ],
      ),
      floatingActionButton: _isSelectionMode && _selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isAdding ? null : _addSelectedCharacters,
              icon: _isAdding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add),
              label: Text(_isAdding ? '添加中...' : '添加 ${_selectedIds.length} 个'),
            )
          : null,
      body: Stack(
        children: [
          Column(
            children: [
              if (!_isSelectionMode) _buildViewSwitcher(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(_activeView),
                    child: _activeView == _AddBangumiView.search
                        ? _buildSearchBody()
                        : _buildCollectionsBody(),
                  ),
                ),
              ),
            ],
          ),
          if (_isAdding)
            Container(
              color: Theme.of(
                context,
              ).colorScheme.scrim.withValues(alpha: 0.45),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
