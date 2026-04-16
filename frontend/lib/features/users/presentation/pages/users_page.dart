import 'package:flutter/material.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/users/data/datasources/users_remote_data_source.dart';
import 'package:shopxy/features/users/data/repositories/users_repository_impl.dart';
import 'package:shopxy/features/users/domain/entities/user.dart';
import 'package:shopxy/features/users/domain/usecases/fetch_users.dart';
import 'package:shopxy/features/users/presentation/widgets/user_tile.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late final FetchUsers _fetchUsers;
  late final Future<List<User>> _usersFuture;

  @override
  void initState() {
    super.initState();
    final repository = UsersRepositoryImpl(
      UsersRemoteDataSource(const ApiClient()),
    );
    _fetchUsers = FetchUsers(repository);
    _usersFuture = _fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: FutureBuilder<List<User>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load users',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('No users yet'));
          }

          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return UserTile(user: users[index]);
            },
          );
        },
      ),
    );
  }
}
