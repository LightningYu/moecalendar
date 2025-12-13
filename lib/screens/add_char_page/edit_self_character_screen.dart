import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lunar/lunar.dart';
import '../../models/character_model.dart';
import '../../providers/character_provider.dart';

/// 编辑自己生日页面
/// 只能修改，不能删除
class EditSelfCharacterScreen extends StatefulWidget {
  final ManualCharacter character;

  const EditSelfCharacterScreen({super.key, required this.character});

  @override
  State<EditSelfCharacterScreen> createState() =>
      _EditSelfCharacterScreenState();
}

class _EditSelfCharacterScreenState extends State<EditSelfCharacterScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late bool _isLunar;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.character.birthYear ?? DateTime.now().year,
      widget.character.birthMonth,
      widget.character.birthDay,
    );
    _isLunar = widget.character.isLunar;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _getDateText() {
    if (_isLunar) {
      try {
        final lunar = Lunar.fromYmd(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        );
        return '农历 ${lunar.getYearInGanZhi()}年 ${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
      } catch (e) {
        return '无效的农历日期';
      }
    } else {
      return DateFormat('yyyy年MM月dd日').format(_selectedDate);
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<CharacterProvider>(context, listen: false);
      await provider.upsertSelfCharacter(
        birthday: _selectedDate,
        isLunar: _isLunar,
        displayName: widget.character.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('生日已更新')));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑我的生日')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('出生日期'),
                      subtitle: Text(_getDateText()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _selectDate(context),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.brightness_2),
                      title: const Text('农历生日'),
                      subtitle: const Text('上方日期将被视为农历日期'),
                      value: _isLunar,
                      onChanged: (val) => setState(() => _isLunar = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Text('保存'),
              ),
              const SizedBox(height: 16),
              // 说明文字
              Text(
                '你的生日信息用于显示专属的生日页面和计算年龄',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
