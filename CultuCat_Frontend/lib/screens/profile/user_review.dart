import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/user_preferences.dart';
import '../event_map/event.dart';
import '/utils/server_url.dart';

class UserReviewsScreen extends StatefulWidget {
  final String username;
  final VoidCallback? onReviewsChanged;

  const UserReviewsScreen({Key? key, required this.username, this.onReviewsChanged}) : super(key: key);

  @override
  _UserReviewsScreenState createState() => _UserReviewsScreenState();
}

class _UserReviewsScreenState extends State<UserReviewsScreen> {
  List<dynamic> _reviews = [];
  Map<int, String> _eventNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    fetchUserReviews();
  }

  Future<void> fetchUserReviews() async {
    setState(() => _loading = true);

    final token = await UserPreferences.getToken();
    final response = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/reviews/user-sorted/${widget.username}'),
      headers: {"Authorization": "Token $token"},
    );

    print('fetchUserReviews RESPONSE BODY: ${response.body}');  // PONLO AQUÍ para ver la respuesta JSON

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      List<dynamic> reviewsList;

      if (decoded is List) {
        reviewsList = decoded; // si es lista, ok
      } else if (decoded is Map && decoded.containsKey('reviews')) {
        reviewsList = decoded['reviews']; // si es mapa con clave 'reviews'
      } else {
        reviewsList = []; // fallback, vacía
      }

      final eventIds = reviewsList.map<int>((r) => r['event_id'] as int).toSet();

      await fetchAllEventNames(eventIds);

      setState(() {
        _reviews = reviewsList;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_loading_reviews'.tr())),
      );
    }
  }

  Future<List<void>> fetchAllEventNames(Set<int> eventIds) {
    return Future.wait(eventIds.map((id) => fetchEventName(id)).toList());
  }

  Future<void> fetchEventName(int eventId) async {
    final token = await UserPreferences.getToken();

    final response = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/events/$eventId/'),
      headers: {"Authorization": "Token $token"},
    );

    if (response.statusCode == 200) {
      final eventData = jsonDecode(response.body);
      setState(() {
        _eventNames[eventId] = eventData['event'] != null && eventData['event']['name'] != null
            ? eventData['event']['name']
            : 'event_with_id'.tr(namedArgs: {'eventId': eventId.toString()});
      });
    } else {
      setState(() {
        _eventNames[eventId] = 'event_with_id'.tr(namedArgs: {'eventId': eventId.toString()});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Devuelve true para indicar que hubo cambios (o false si no quieres refrescar)
        Navigator.pop(context, true);
        return false; // porque ya hiciste el pop manualmente
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'reviews_of_username'.tr(namedArgs: {'username': widget.username}),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator())
            : _reviews.isEmpty
            ? Center(child: Text('no_reviews_yet'.tr()))
            : ListView.builder(
          itemCount: _reviews.length,
          itemBuilder: (context, index) {
            final review = _reviews[index];
            final eventId = review['event_id'];
            final eventName = _eventNames[eventId] ?? 'loading'.tr();

            return ListTile(
              title: Text(eventName, style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(review['text'] ?? 'Sin texto'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Likes: ${review['likes_count'] ?? 0}'),
                  Text('Dislikes: ${review['dislikes_count'] ?? 0}'),
                ],
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventScreen(
                      texto: eventName,
                      id: eventId.toString(),
                    ),
                  ),
                );
                // Recarga las reviews al volver
                fetchUserReviews();
              },
            );
          },
        ),
      ),
    );
  }
}

