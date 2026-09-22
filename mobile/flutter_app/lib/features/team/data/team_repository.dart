import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class TeamMember {
  const TeamMember({
    required this.id,
    required this.email,
    required this.fullName,
    required this.roleId,
    required this.roleName,
    required this.status,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
    id: json['id'] as String,
    email: json['email'] as String?,
    fullName: json['fullName'] as String?,
    roleId: json['roleId'] as String,
    roleName: json['roleName'] as String,
    status: json['status'] as String,
  );

  final String id;
  final String? email;
  final String? fullName;
  final String roleId;
  final String roleName;
  final String status;
}

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => TeamRepository(ref.read(dioProvider)),
);

final teamMembersProvider = FutureProvider<List<TeamMember>>(
  (ref) => ref.read(teamRepositoryProvider).listMembers(),
);

class TeamRepository {
  TeamRepository(this._dio);

  final Dio _dio;

  Future<List<TeamMember>> listMembers() async {
    try {
      final response = await _dio.get<List<dynamic>>('/organizations/members');
      return (response.data ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TeamMember.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<TeamMember> updateRole({
    required String memberId,
    required String roleId,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/organizations/members/$memberId/role',
        data: {'roleId': roleId},
      );
      return TeamMember.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
