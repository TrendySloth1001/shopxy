import 'package:shopxy/features/users/domain/entities/user.dart';

abstract class UsersRepository {
  Future<List<User>> fetchUsers();
}
