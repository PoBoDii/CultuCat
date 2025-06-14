import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'otherprofile.dart';

class FriendsList extends StatefulWidget {
  final List<String> initialFriends;
  final Future<bool> Function(String) onRemoveFriend;
  final VoidCallback? onFriendRemoved;

  const FriendsList({
    super.key,
    required this.initialFriends,
    required this.onRemoveFriend,
    this.onFriendRemoved,
  });

  @override
  State<FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends State<FriendsList> {
  late List<String> _friends;

  @override
  void initState() {
    super.initState();
    _friends = List.from(widget.initialFriends);
  }

  void _removeFriend(String username) async {
    final success = await widget.onRemoveFriend(username);
    if (success) {
      setState(() {
        _friends.remove(username);
      });
      // Aquí ya NO mostramos snackbar, solo llamamos callback
      widget.onFriendRemoved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints(maxHeight: 450),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'friends_title'.tr(namedArgs: {'count': _friends.length.toString()}),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _friends.isEmpty
                  ? Text(
                'no_friends_yet'.tr(),
                style: TextStyle(color: Colors.grey[600]),
              )
                  : ListView.separated(
                itemCount: _friends.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final username = _friends[index];
                  return ListTile(
                    leading: const Icon(Icons.person, color: Colors.blue),
                    title: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OtherProfilePage(username: username),
                          ),
                        );
                      },
                      child: Text(
                        username,
                        style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.blue),
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      tooltip: 'remove_friend_tooltip'.tr(),
                      onPressed: () => _removeFriend(username),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.close),
                label: Text('close'.tr()),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  backgroundColor: Colors.blue[50],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
