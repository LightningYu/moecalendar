import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'models/character_dto.dart';
import 'models/subject_dto.dart';

/// Bangumi API 服务
class BangumiService {
  static final BangumiService _instance = BangumiService._internal();
  factory BangumiService() => _instance;

  final Dio _dio = Dio();

  BangumiService._internal() {
    _dio.options.baseUrl = ApiConfig.bangumiBaseUrl;
    _dio.options.headers = {
      'User-Agent': ApiConfig.userAgent,
      'Accept': 'application/json',
    };
  }

  /// 搜索角色
  Future<BangumiSearchResponse> searchCharacters(
    String keyword, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.post(
        '/v0/search/characters',
        data: {'keyword': keyword},
        queryParameters: {'limit': limit, 'offset': offset},
      );

      if (response.statusCode == 200) {
        return BangumiSearchResponse.fromJson(response.data);
      }
      return BangumiSearchResponse(
        total: 0,
        limit: limit,
        offset: offset,
        data: [],
      );
    } catch (e) {
      debugPrint('Bangumi Search Error: $e');
      return BangumiSearchResponse(
        total: 0,
        limit: limit,
        offset: offset,
        data: [],
      );
    }
  }

  /// 获取角色详情
  Future<BangumiCharacterDto?> getCharacterDetail(int id) async {
    try {
      final response = await _dio.get('/v0/characters/$id');
      if (response.statusCode == 200) {
        return BangumiCharacterDto.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('Bangumi Detail Error: $e');
      return null;
    }
  }

  /// 获取用户收藏的条目 (Anime)
  Future<List<BangumiSubjectDto>> getUserCollections(
    String username, {
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/v0/users/$username/collections',
        queryParameters: {
          'subject_type': 2, // Anime
          'limit': limit,
          'offset': offset,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        return data
            .map((e) => BangumiSubjectDto.fromJson(e['subject']))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get User Collections Error: $e');
      return [];
    }
  }

  /// 获取条目的角色
  Future<List<BangumiCharacterDto>> getSubjectCharacters(int subjectId) async {
    try {
      final response = await _dio.get('/v0/subjects/$subjectId/characters');
      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.map((e) => BangumiCharacterDto.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get Subject Characters Error: $e');
      return [];
    }
  }

  /// 获取用户收藏的角色
  Future<List<BangumiCharacterDto>> getUserCharacterCollections(
    String username, {
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/v0/users/$username/collections/-/characters',
        queryParameters: {'limit': limit, 'offset': offset},
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        return data.map((e) => BangumiCharacterDto.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get User Character Collections Error: $e');
      return [];
    }
  }
}
