import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

enum WorkspaceKind { personal, organization }

class WorkspaceSummary {
  const WorkspaceSummary({
    required this.id,
    required this.kind,
    required this.name,
    required this.role,
    required this.permissions,
    this.slug,
  });

  factory WorkspaceSummary.fromJson(Map<String, dynamic> json) {
    final permissions = json['permissions'];
    return WorkspaceSummary(
      id: json['id'] as String,
      kind: json['kind'] == 'organization'
          ? WorkspaceKind.organization
          : WorkspaceKind.personal,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      role: json['role'] as String?,
      permissions: permissions is List
          ? permissions.whereType<String>().toSet()
          : const <String>{},
    );
  }

  final String id;
  final WorkspaceKind kind;
  final String name;
  final String? slug;
  final String? role;
  final Set<String> permissions;
}

final workspaceRepositoryProvider = Provider<WorkspaceRepository>(
  (ref) => WorkspaceRepository(ref.read(dioProvider)),
);

final workspacesProvider = FutureProvider<List<WorkspaceSummary>>((ref) async {
  return ref.read(workspaceRepositoryProvider).list();
});

class WorkspaceRepository {
  WorkspaceRepository(this._dio);

  final Dio _dio;

  Future<List<WorkspaceSummary>> list() async {
    final response = await _dio.get<List<dynamic>>('/workspaces');
    return (response.data ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(WorkspaceSummary.fromJson)
        .toList();
  }

  Future<void> select(WorkspaceSummary workspace) async {
    await _dio.patch<void>(
      '/workspaces/active',
      data: {'kind': workspace.kind.name, 'id': workspace.id},
    );
  }

  Future<WorkspaceSummary> createOrganization(String name) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/workspaces',
      data: {'name': name},
    );
    return WorkspaceSummary.fromJson(response.data!);
  }
}
