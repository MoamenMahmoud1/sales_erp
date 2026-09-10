class AuthUser {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final bool isStaff;
  final bool isSuperuser;
  final int roleLevel;
  final Set<String> permissions;
  final AuthRole? role;

  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.isStaff,
    required this.isSuperuser,
    required this.roleLevel,
    required this.permissions,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final roleJson = json['role'];
    return AuthUser(
      id: _readInt(json['id']),
      username: _readString(json['username']),
      email: _readString(json['email']),
      firstName: _readString(json['first_name']),
      lastName: _readString(json['last_name']),
      isStaff: json['is_staff'] == true,
      isSuperuser: json['is_superuser'] == true,
      roleLevel: _readInt(json['role_level']),
      permissions: {
        for (final permission in (json['permissions'] as List? ?? const []))
          if (permission is String && permission.trim().isNotEmpty) permission,
      },
      role: roleJson is Map<String, dynamic>
          ? AuthRole.fromJson(roleJson)
          : null,
    );
  }

  bool hasPermission(String permission) {
    return isSuperuser || permissions.contains(permission);
  }

  bool hasAnyPermissionWithPrefix(Iterable<String> prefixes) {
    if (isSuperuser) return true;
    return prefixes.any(
      (prefix) => permissions.any((permission) => permission.startsWith(prefix)),
    );
  }

  bool get hasAnyPermission => isSuperuser || permissions.isNotEmpty;

  static AuthUser localDevelopmentUser() {
    return const AuthUser(
      id: 0,
      username: 'local',
      email: '',
      firstName: 'Local',
      lastName: 'User',
      isStaff: true,
      isSuperuser: true,
      roleLevel: 1000,
      permissions: {
        'dashboard.view',
        'sales.view',
        'products.view',
        'customers.view',
      },
      role: AuthRole(
        id: 0,
        name: 'Local Development',
        level: 1000,
        scope: 'company',
        requiresShift: false,
        description: 'Local development session.',
      ),
    );
  }

  static String _readString(dynamic value) => value?.toString() ?? '';

  static int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AuthRole {
  final int id;
  final String name;
  final int level;
  final String scope;
  final bool requiresShift;
  final String description;

  const AuthRole({
    required this.id,
    required this.name,
    required this.level,
    required this.scope,
    required this.requiresShift,
    required this.description,
  });

  factory AuthRole.fromJson(Map<String, dynamic> json) {
    return AuthRole(
      id: AuthUser._readInt(json['id']),
      name: AuthUser._readString(json['name']),
      level: AuthUser._readInt(json['level']),
      scope: AuthUser._readString(json['scope']),
      requiresShift: json['requires_shift'] == true,
      description: AuthUser._readString(json['description']),
    );
  }
}
