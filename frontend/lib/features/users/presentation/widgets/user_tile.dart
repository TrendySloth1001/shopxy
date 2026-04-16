import 'package:flutter/material.dart';
import 'package:shopxy/features/users/domain/entities/user.dart';

class UserTile extends StatelessWidget {
  const UserTile({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final displayName = (user.name == null || user.name!.isEmpty)
        ? user.email
        : user.name!;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
        child: Text(user.email.isNotEmpty ? user.email[0].toUpperCase() : '?'),
      ),
      title: Text(displayName),
      subtitle: user.name == null ? null : Text(user.email),
    );
  }
}
