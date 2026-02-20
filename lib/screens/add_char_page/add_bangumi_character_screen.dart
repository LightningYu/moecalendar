import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../bangumi/bangumi.dart';
import '../../config/routes/app_routes.dart';
import '../../providers/character_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/bangumi_character_list_item.dart';
import '../../widgets/bangumi_subject_list_item.dart';
import '../char_page/bangumi_anime_list_screen.dart';
import '../char_page/bangumi_character_list_screen.dart';
import '../char_page/character_detail_screen.dart';
import '../char_page/subject_detail_screen.dart';

class AddBangumiCharacterScreen extends StatefulWidget {
  const AddBangumiCharacterScreen({super.key});

  @override
  State<AddBangumiCharacterScreen> createState() =>
      _AddBangumiCharacterScreenState();
}

enum _AddBangumiView { search, collections }

enum _SearchType { character, subject }

class _AddBangumiCharacterScreenState extends State<AddBangumiCharacterScreen> {
  final TextEditingController _searchController = TextEditingController();
  final BangumiService _bangumiService = BangumiService();
  final ScrollController _scrollController = ScrollController();

  // Search State
  List<BangumiCharacterDto> _searchResults = [];
  List<BangumiSubjectDto> _subjectResults = [];
  bool _isSearching = false;
  bool _isLoadingSearch = false;
  bool _hasMoreSearch = true;
  int _searchOffset = 0;
  int _searchTotal = 0;
  static const int _limit = 20;
  String _currentKeyword = '';
  _AddBangumiView _activeView = _AddBangumiView.search;
  _SearchType _searchType = _SearchType.character;

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
      _subjectResults = [];
      _searchOffset = 0;
      _searchTotal = 0;
      _hasMoreSearch = true;
      _currentKeyword = _searchController.text;
    });

    if (_searchType == _SearchType.character) {
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
    } else {
      final response = await _bangumiService.searchSubjects(
        _currentKeyword,
        limit: _limit,
        offset: _searchOffset,
      );
      if (!mounted) return;
      setState(() {
        _subjectResults = response.data;
        _searchTotal = response.total;
        _isLoadingSearch = false;
        _searchOffset += response.data.length;
        _hasMoreSearch = _searchOffset < _searchTotal;
      });
    }
  }

  Future<void> _loadMoreSearch() async {
    setState(() {
      _isLoadingSearch = true;
    });

    if (_searchType == _SearchType.character) {
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
    } else {
      final response = await _bangumiService.searchSubjects(
        _currentKeyword,
        limit: _limit,
        offset: _searchOffset,
      );
      if (!mounted) return;
      setState(() {
        _subjectResults.addAll(response.data);
        _isLoadingSearch = false;
        _searchOffset += response.data.length;
        _hasMoreSearch = _searchOffset < _searchTotal;
      });
    }
  }

  // --- Add ---

  // 批量添加选中的角色（非阻塞，立即返回）
  void _addSelectedCharacters() {
    if (_selectedIds.isEmpty) return;

    final provider = Provider.of<CharacterProvider>(context, listen: false);

    final selectedList = _searchResults
        .where((c) => _selectedIds.contains(c.id))
        .toList();

    final count = selectedList.length;

    // 非阻塞：后台异步获取详情并入库
    provider.addBangumiCharactersAsync(selectedList);

    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已创建 $count 个添加任务，将在后台处理')));
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
    if (_isLoadingSearch && _searchResults.isEmpty && _subjectResults.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchType == _SearchType.subject) {
      return _buildSubjectSearchList();
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

  Widget _buildSubjectSearchList() {
    if (_subjectResults.isEmpty) {
      return _buildEmptySearchState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _subjectResults.length + (_hasMoreSearch ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _subjectResults.length) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final subject = _subjectResults[index];
        return BangumiSubjectListItem(
          subject: subject,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SubjectDetailScreen(
                  subjectId: subject.id,
                  subjectName: subject.displayName,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptySearchState() {
    final theme = Theme.of(context);
    final isInitial = _currentKeyword.isEmpty;
    final isCharacter = _searchType == _SearchType.character;
    final title = isInitial
        ? (isCharacter ? '搜索 Bangumi 角色' : '搜索 Bangumi 番剧')
        : (isCharacter ? '没有匹配的角色' : '没有匹配的番剧');
    final subtitle = isInitial
        ? (isCharacter
              ? '支持角色名、中文别名或作品名关键字\n长按可进入多选模式批量添加'
              : '输入番剧名称搜索，点击条目可查看并导入角色')
        : '可以尝试更换关键字，或切换搜索类型';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isInitial
                  ? (isCharacter ? Icons.travel_explore : Icons.movie_outlined)
                  : Icons.sentiment_dissatisfied,
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _searchType == _SearchType.character
                        ? '搜索角色、中文名或作品名'
                        : '搜索番剧名称',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isSearching
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              FocusScope.of(context).unfocus();
                              setState(() {
                                _searchResults = [];
                                _subjectResults = [];
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedButton<_SearchType>(
            showSelectedIcon: false,
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment<_SearchType>(
                value: _SearchType.character,
                label: Text('角色'),
                icon: Icon(Icons.person_search),
              ),
              ButtonSegment<_SearchType>(
                value: _SearchType.subject,
                label: Text('番剧'),
                icon: Icon(Icons.movie_outlined),
              ),
            ],
            selected: <_SearchType>{_searchType},
            onSelectionChanged: (selection) {
              final next = selection.first;
              if (next == _searchType) return;
              setState(() {
                _searchType = next;
                _searchResults = [];
                _subjectResults = [];
                _currentKeyword = '';
                _searchOffset = 0;
                _searchTotal = 0;
                _hasMoreSearch = true;
                _searchController.clear();
                _isSearching = false;
              });
            },
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
                context.push(AppRoutes.settingsBangumiPath);
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
              onPressed: _addSelectedCharacters,
              icon: const Icon(Icons.add),
              label: Text('添加 ${_selectedIds.length} 个'),
            )
          : null,
      body: Column(
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
    );
  }
}
