import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../bangumi/bangumi.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/bangumi_subject_list_item.dart';
import 'subject_detail_screen.dart';

class BangumiAnimeListScreen extends StatefulWidget {
  const BangumiAnimeListScreen({super.key});

  @override
  State<BangumiAnimeListScreen> createState() => _BangumiAnimeListScreenState();
}

class _BangumiAnimeListScreenState extends State<BangumiAnimeListScreen> {
  final BangumiService _bangumiService = BangumiService();
  final ScrollController _scrollController = ScrollController();

  final List<BangumiSubjectDto> _collections = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 30;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCollections();
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
      _loadCollections();
    }
  }

  Future<void> _loadCollections() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) return;

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final newItems = await _bangumiService.getUserCollections(
      authProvider.user!.username,
      limit: _limit,
      offset: _offset,
    );

    if (!mounted) return;

    setState(() {
      _collections.addAll(newItems);
      _isLoading = false;
      _offset += newItems.length;
      _hasMore = newItems.length >= _limit;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的番剧收藏')),
      body: _collections.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _collections.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _collections.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final subject = _collections[index];
                return BangumiSubjectListItem(
                  subject: subject,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SubjectDetailScreen(
                          subjectId: subject.id,
                          subjectName: subject.nameCn.isNotEmpty
                              ? subject.nameCn
                              : subject.name,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
