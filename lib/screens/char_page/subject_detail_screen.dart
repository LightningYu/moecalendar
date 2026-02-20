import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../bangumi/bangumi.dart';
import '../../providers/character_provider.dart';
import '../../widgets/bangumi_character_list_item.dart';
import 'character_detail_screen.dart';

class SubjectDetailScreen extends StatefulWidget {
  final int subjectId;
  final String subjectName;

  const SubjectDetailScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  final BangumiService _bangumiService = BangumiService();
  List<BangumiCharacterDto> _characters = [];
  final Set<int> _selectedIds = {};
  bool _isLoading = true;
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    try {
      final characters = await _bangumiService.getSubjectCharacters(
        widget.subjectId,
      );
      if (mounted) {
        setState(() {
          _characters = characters;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载角色失败: $e')));
      }
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
          _isSelectionMode
              ? '已选择 ${_selectedIds.length} 个'
              : widget.subjectName,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _characters.isEmpty
          ? const Center(child: Text('该番剧暂无角色数据'))
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: _characters.length,
              itemBuilder: (context, index) {
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
