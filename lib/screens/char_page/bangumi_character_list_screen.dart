import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../bangumi/bangumi.dart';
import '../../providers/character_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/bangumi_character_list_item.dart';
import 'character_detail_screen.dart';

class BangumiCharacterListScreen extends StatefulWidget {
  const BangumiCharacterListScreen({super.key});

  @override
  State<BangumiCharacterListScreen> createState() =>
      _BangumiCharacterListScreenState();
}

class _BangumiCharacterListScreenState
    extends State<BangumiCharacterListScreen> {
  final BangumiService _bangumiService = BangumiService();
  final ScrollController _scrollController = ScrollController();

  final List<BangumiCharacterDto> _characters = [];
  final Set<int> _selectedIds = {};
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 30;
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCharacters();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadCharacters();
    }
  }

  Future<void> _loadCharacters() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) return;

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final newItems = await _bangumiService.getUserCharacterCollections(
      authProvider.user!.username,
      limit: _limit,
      offset: _offset,
    );

    if (!mounted) return;

    setState(() {
      _characters.addAll(newItems);
      _isLoading = false;
      _offset += newItems.length;
      _hasMore = newItems.length >= _limit;
    });
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

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _characters.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(_characters.map((e) => e.id));
        _isSelectionMode = true;
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

  Future<void> _addSelectedCharacters() async {
    if (_selectedIds.isEmpty) return;

    final provider = Provider.of<CharacterProvider>(context, listen: false);

    final selectedList = _characters
        .where((c) => _selectedIds.contains(c.id))
        .toList();

    final count = selectedList.length;

    // 非阻塞：后台异步获取详情并入库
    provider.addBangumiCharactersAsync(selectedList);

    setState(() {
      _selectedIds.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已创建 $count 个添加任务，将在后台处理')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? '已选择 ${_selectedIds.length} 个' : '我的角色收藏',
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: [
          TextButton(
            onPressed: _selectAll,
            child: Text(
              _selectedIds.length == _characters.length &&
                      _characters.isNotEmpty
                  ? '取消全选'
                  : '全选',
            ),
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
      body: _characters.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: _characters.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _characters.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final character = _characters[index];
                final isSelected = _selectedIds.contains(character.id);

                return BangumiCharacterListItem(
                  character: character,
                  isSelected: isSelected,
                  isSelectionMode: _isSelectionMode,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CharacterDetailScreen.fromBangumi(
                          bangumiDto: character,
                        ),
                      ),
                    );
                  },
                  onLongPress: () => _enterSelectionMode(character.id),
                  onCheckChanged: (val) => _toggleSelection(character.id),
                );
              },
            ),
    );
  }
}
