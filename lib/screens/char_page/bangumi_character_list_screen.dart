import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../bangumi/bangumi.dart';
import '../../providers/auth_provider.dart';
import '../../utils/bangumi_selection_mixin.dart';
import '../../widgets/bangumi_character_list_item.dart';
import 'character_detail_screen.dart';

class BangumiCharacterListScreen extends StatefulWidget {
  const BangumiCharacterListScreen({super.key});

  @override
  State<BangumiCharacterListScreen> createState() =>
      _BangumiCharacterListScreenState();
}

class _BangumiCharacterListScreenState extends State<BangumiCharacterListScreen>
    with BangumiSelectionMixin {
  final BangumiService _bangumiService = BangumiService();
  final ScrollController _scrollController = ScrollController();

  final List<BangumiCharacterDto> _characters = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 30;

  @override
  List<BangumiCharacterDto> get selectableCharacters => _characters;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isSelectionMode ? '已选择 ${selectedIds.length} 个' : '我的角色收藏'),
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: exitSelectionMode,
              )
            : null,
        actions: [TextButton(onPressed: selectAll, child: Text(selectAllText))],
      ),
      floatingActionButton: isSelectionMode && selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: addSelectedCharacters,
              icon: const Icon(Icons.add),
              label: Text('添加 ${selectedIds.length} 个'),
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
                final isSelected = selectedIds.contains(character.id);

                return BangumiCharacterListItem(
                  character: character,
                  isSelected: isSelected,
                  isSelectionMode: isSelectionMode,
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
                  onLongPress: () => enterSelectionMode(character.id),
                  onCheckChanged: (val) => toggleSelection(character.id),
                );
              },
            ),
    );
  }
}
