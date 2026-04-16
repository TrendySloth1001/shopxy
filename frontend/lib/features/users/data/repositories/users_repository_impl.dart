import 'package:shopxy/features/users/data/datasources/users_remote_data_source.dart';
import 'package:shopxy/features/users/domain/entities/user.dart';
import 'package:shopxy/features/users/domain/repositories/users_repository.dart';

class UsersRepositoryImpl implements UsersRepository {
  UsersRepositoryImpl(this._remoteDataSource);

  final UsersRemoteDataSource _remoteDataSource;

  @override
  Future<List<User>> fetchUsers() async {
    final dtos = await _remoteDataSource.fetchUsers();
    return dtos.map((dto) => dto.toEntity()).toList();
  }
}
