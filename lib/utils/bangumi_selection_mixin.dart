import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bangumi/bangumi.dart';
import '../providers/character_provider.dart';

/// 为 Bangumi 角色列表屏幕提供多选功能的 Mixin
///
/// 使用方法：
/// 1. 在 State 中 `with BangumiSelectionMixin`
/// 2. 实现 [selectableCharacters] getter 返回当前列表数据源
/// 3. UI 中使用 [isSelectionMode]、[selectedIds] 控制显示
/// 4. 绑定事件：[enterSelectionMode]、[toggleSelection]、[exitSelectionMode]、[selectAll]
/// 5. 添加按钮调用 [addSelectedCharacters]
mixin BangumiSelectionMixin<T extends StatefulWidget> on State<T> {
  final Set<int> selectedIds = {};
  bool isSelectionMode = false;

  /// 子类必须实现：返回当前可选的角色列表
  List<BangumiCharacterDto> get selectableCharacters;

  void enterSelectionMode(int id) {
    setState(() {
      isSelectionMode = true;
      selectedIds.add(id);
    });
  }

  void exitSelectionMode() {
    setState(() {
      isSelectionMode = false;
      selectedIds.clear();
    });
  }

  void toggleSelection(int id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
        if (selectedIds.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedIds.add(id);
      }
    });
  }

  void selectAll() {
    final chars = selectableCharacters;
    setState(() {
      if (selectedIds.length == chars.length) {
        selectedIds.clear();
        isSelectionMode = false;
      } else {
        selectedIds.addAll(chars.map((e) => e.id));
        isSelectionMode = true;
      }
    });
  }

  /// 批量添加选中的角色（逐个拉取详情后入库）
  void addSelectedCharacters() {
    if (selectedIds.isEmpty) return;

    final provider = Provider.of<CharacterProvider>(context, listen: false);
    final selectedList = selectableCharacters
        .where((c) => selectedIds.contains(c.id))
        .toList();
    final count = selectedList.length;

    // 异步执行，不阻塞 UI
    provider.addBangumiCharactersAsync(selectedList);

    setState(() {
      selectedIds.clear();
      isSelectionMode = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('正在添加 $count 个角色，请稍候…')));
    }
  }

  /// 全选按钮文字
  String get selectAllText {
    final chars = selectableCharacters;
    return selectedIds.length == chars.length && chars.isNotEmpty
        ? '取消全选'
        : '全选';
  }
}
