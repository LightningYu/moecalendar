import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lunar/lunar.dart';
import '../../models/character_model.dart';
import '../../providers/character_provider.dart';

class AddManualCharacterScreen extends StatefulWidget {
  const AddManualCharacterScreen({super.key});

  @override
  State<AddManualCharacterScreen> createState() =>
      _AddManualCharacterScreenState();
}

class _AddManualCharacterScreenState extends State<AddManualCharacterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _hasYear = true;
  bool _isLunar = false;

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
      return _hasYear
          ? DateFormat('yyyy年MM月dd日').format(_selectedDate)
          : DateFormat('MM月dd日').format(_selectedDate);
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<CharacterProvider>(context, listen: false);

      final String id = DateTime.now().millisecondsSinceEpoch.toString();
      final int notificationId =
          DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;

      final newCharacter = ManualCharacter(
        id: id,
        notificationId: notificationId,
        name: _nameController.text,
        birthYear: _hasYear ? _selectedDate.year : null,
        birthMonth: _selectedDate.month,
        birthDay: _selectedDate.day,
        notify: true, 
        isLunar: _isLunar,
      );

      await provider.addCharacter(newCharacter);

      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('手动添加人物')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '姓名',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? '请输入姓名' : null,
              ),
              const SizedBox(height: 20),
              ListTile(
                title: const Text('生日日期'),
                subtitle: Text(_getDateText()),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              SwitchListTile(
                title: const Text('按农历计算'),
                subtitle: const Text('开启后，上方日期将被视为农历日期'),
                value: _isLunar,
                onChanged: (val) {
                  if (val && !_hasYear) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('农历计算需要包含年份')));
                    return;
                  }
                  setState(() => _isLunar = val);
                },
              ),
              SwitchListTile(
                title: const Text('包含年份'),
                value: _hasYear,
                onChanged: (val) {
                  if (!val && _isLunar) {
                    setState(() => _isLunar = false);
                  }
                  setState(() => _hasYear = val);
                },
              ),
              // Notify switch removed
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Text('保存'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
