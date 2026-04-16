import 'package:shopxy/features/users/domain/entities/user.dart';
import 'package:shopxy/features/users/domain/repositories/users_repository.dart';

class FetchUsers {
  FetchUsers(this._repository);

  final UsersRepository _repository;

  Future<List<User>> call() {
    return _repository.fetchUsers();
  }
}
