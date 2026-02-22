import 'package:flutter/material.dart';
import '../../bangumi/bangumi.dart';
import '../../utils/bangumi_selection_mixin.dart';
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

class _SubjectDetailScreenState extends State<SubjectDetailScreen>
    with BangumiSelectionMixin {
  final BangumiService _bangumiService = BangumiService();
  List<BangumiCharacterDto> _characters = [];
  bool _isLoading = true;

  @override
  List<BangumiCharacterDto> get selectableCharacters => _characters;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSelectionMode ? '已选择 ${selectedIds.length} 个' : widget.subjectName,
        ),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _characters.isEmpty
          ? const Center(child: Text('该番剧暂无角色数据'))
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: _characters.length,
              itemBuilder: (context, index) {
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
