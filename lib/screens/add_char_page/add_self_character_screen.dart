import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lunar/lunar.dart';
import '../../providers/character_provider.dart';

class AddSelfCharacterScreen extends StatefulWidget {
  const AddSelfCharacterScreen({super.key});

  @override
  State<AddSelfCharacterScreen> createState() => _AddSelfCharacterScreenState();
}

class _AddSelfCharacterScreenState extends State<AddSelfCharacterScreen> {
  final _formKey = GlobalKey<FormState>();
  // Name is hardcoded to "我自己" internally, but user doesn't see input
  final String _name = '我自己';
  DateTime _selectedDate = DateTime.now();
  bool _isLunar = false;
  // bool _notify = true; // Always true

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
        displayName: _name,
      );

      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加我自己')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // No Name input
              const SizedBox(height: 20),
              ListTile(
                title: const Text('出生日期'),
                subtitle: Text(_getDateText()),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              SwitchListTile(
                title: const Text('按农历计算'),
                subtitle: const Text('开启后，上方日期将被视为农历日期'),
                value: _isLunar,
                onChanged: (val) => setState(() => _isLunar = val),
              ),
              // No Notify switch
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
