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
  bool _isAdding = false;
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

  Future<void> _addSelectedCharacters() async {
    if (_selectedIds.isEmpty) return;

    setState(() {
      _isAdding = true;
    });

    final provider = Provider.of<CharacterProvider>(context, listen: false);
    int addedCount = 0;
    int skippedCount = 0;

    final selectedList = _characters
        .where((c) => _selectedIds.contains(c.id))
        .toList();

    for (final simpleDto in selectedList) {
      // Fetch full details to get birthday
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

      // 下载 grid 和 large 两个图片
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
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已添加 $addedCount 个角色，跳过 $skippedCount 个（无生日信息）'),
        ),
      );
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
          _characters.isEmpty && _isLoading
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
                            builder: (context) =>
                                CharacterDetailScreen.fromBangumi(
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
