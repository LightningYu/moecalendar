import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:moecalendar/bangumi/models/character_dto.dart'
    show BangumiCharacterDto;
import '../../widgets/bangumi_character_list_item.dart';

class BangumiBirthdayTodayScreen extends StatefulWidget {
  final int month;
  final int day;
  const BangumiBirthdayTodayScreen({
    super.key,
    required this.month,
    required this.day,
  });

  @override
  State<BangumiBirthdayTodayScreen> createState() =>
      _BangumiBirthdayTodayScreenState();
}

class _BangumiBirthdayTodayScreenState
    extends State<BangumiBirthdayTodayScreen> {
  final List<dynamic> _characters = [];
  bool _isLoading = false;
  int _currentPage = 1;
  bool _hasMore = true;
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchCharacters();
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
      _fetchCharacters();
    }
  }

  Future<void> _fetchCharacters() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    final url =
        'https://bangumi.tv/character?month=${widget.month}&day=${widget.day}&page=$_currentPage';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final document = html_parser.parse(response.body);
      final items = document.querySelectorAll('.browserItem');
      if (items.isEmpty) {
        setState(() => _hasMore = false);
      } else {
        for (final item in items) {
          final avatar =
              item.querySelector('.avatar img')?.attributes['src'] ?? '';
          final name = item.querySelector('.l')?.text ?? '';
          final detailUrl = item.querySelector('.l')?.attributes['href'] ?? '';
          final info = item.querySelector('.info')?.text ?? '';
          // 解析id
          final idMatch = RegExp(r'/character/(\d+)').firstMatch(detailUrl);
          final id = idMatch != null
              ? int.tryParse(idMatch.group(1) ?? '')
              : null;
          if (id != null) {
            _characters.add(
              BangumiCharacterDto(
                id: id,
                name: name,
                nameCn: null,
                avatarGridUrl: avatar,
                avatarLargeUrl: avatar,
                birthYear: null,
                birthMon: widget.month,
                birthDay: widget.day,
                roleName: null,
                originalData: {
                  'id': id,
                  'name': name,
                  'avatar': avatar,
                  'detailUrl': detailUrl,
                  'info': info,
                },
              ),
            );
          }
        }
        _currentPage++;
      }
    } else {
      setState(() => _hasMore = false);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.month}月${widget.day}日生日角色')),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: _characters.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _characters.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final c = _characters[index] as BangumiCharacterDto;
          return BangumiCharacterListItem(
            character: c,
            isSelected: false,
            isSelectionMode: false,
            onTap: () {
              // 可跳转到webview或详情
            },
          );
        },
      ),
    );
  }
}
