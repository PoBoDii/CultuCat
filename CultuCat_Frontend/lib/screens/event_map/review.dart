import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../utils/user_preferences.dart';
import '/utils/server_url.dart';

class ReviewTab extends StatefulWidget {
  final int eventId;
  final double averageRating;
  const ReviewTab({
    super.key,
    required this.eventId,
    required this.averageRating,
  });

  @override
  State<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<ReviewTab> {
  List<dynamic> _reviews = [];
  bool _loading = true;
  bool _hasMyReview = false;
  String? _myUsername;
  final TextEditingController _commentController = TextEditingController();
  double _rating = 3;
  late double averageRating;

  @override
  void initState() {
    super.initState();
    averageRating = widget.averageRating;
    _loadUsernameAndReviews();
  }

  Future<void> _loadUsernameAndReviews() async {
    final username = await UserPreferences.getUsername();
    if (!mounted) return;

    setState(() {
      _myUsername = username;
    });
    await fetchReviews();
  }

  Future<void> fetchReviews() async {
    try {
      final token = await UserPreferences.getToken();
      if (!mounted) return;

      final response = await http.get(
        Uri.parse('${ServerUrl.getBaseUrl()}/api/reviews/${widget.eventId}/sorted'),
        headers: {
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> reviews = jsonDecode(response.body);

        // Calcula la media aquí también
        double avg = 0;
        if (reviews.isNotEmpty) {
          double suma = 0;
          for (var r in reviews) {
            suma += (r['rating'] ?? 0).toDouble();
          }
          avg = suma / reviews.length;
        }

        setState(() {
          _reviews = reviews;
          averageRating = avg;  // <-- ACTUALIZA aquí SIEMPRE
          _hasMyReview = reviews.any((r) => r['username'] == _myUsername);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> sendReview() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final token = await UserPreferences.getToken();
    if (!mounted) return;

    final response = await http.post(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/reviews/${widget.eventId}/crear/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'rating': _rating.toInt(),
        'text': comment,
      }),
    );

    if (response.statusCode == 201) {
      _commentController.clear();
      setState(() => _rating = 3);
      await fetchReviews();

      // 🔄 Recalcular mitjana després d'enviar la review
      if (_reviews.isNotEmpty) {
        double suma = 0;
        for (var r in _reviews) {
          suma += (r['rating'] ?? 0).toDouble();
        }
        setState(() {
          averageRating = suma / _reviews.length;
        });
      }

      if (mounted) {
        showNiceSnackBar(
          context,
          message: 'reviews_sent_success'.tr(),
          color: Colors.greenAccent,
          icon: Icons.error,
        );
      }
    }
  }

  Future<void> deleteMyReview() async {
    final token = await UserPreferences.getToken();
    if (!mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final response = await http.delete(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/reviews/${widget.eventId}/borrar/'),
      headers: {
        'Authorization': 'Token $token',
      },
    );

    await fetchReviews();

    // 🔄 Recalcular mitjana després d'eliminar la review
    if (_reviews.isNotEmpty) {
      double suma = 0;
      for (var r in _reviews) {
        suma += (r['rating'] ?? 0).toDouble();
      }
      setState(() {
        averageRating = suma / _reviews.length;
        _hasMyReview = false;
      });
    } else {
      setState(() {
        averageRating = 0;
        _hasMyReview = false;
      });
    }

    if (response.statusCode == 200) {
      if (mounted) {
        showNiceSnackBar(
          context,
          message: 'reviews_deleted_success'.tr(),
          color: Colors.redAccent,
          icon: Icons.error,
        );
      }
    } else {
      if (mounted) {
        showNiceSnackBar(
          context,
          message: 'Error al eliminar la reseña',
          color: Colors.redAccent,
          icon: Icons.error,
        );
      }
    }
  }

  void showNiceSnackBar(BuildContext context, {
    required String message,
    required Color color,
    required IconData icon,
  }) {
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    ScaffoldMessenger.of(rootContext).clearSnackBars();
    ScaffoldMessenger.of(rootContext).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> handleLikeDislike(
      String reviewUsername, bool? userLiked, bool isLike) async {
    final token = await UserPreferences.getToken();
    final String usernameEncoded = Uri.encodeComponent(reviewUsername.trim());
    final url =
        '${ServerUrl.getBaseUrl()}/api/reviews/${widget.eventId}/$usernameEncoded/like/';

    try {
      http.Response response;
      if (userLiked != null && userLiked == isLike) {
        response = await http.delete(
          Uri.parse(url),
          headers: {
            'Authorization': 'Token $token',
            'Content-Type': 'application/json',
          },
        );
      } else {
        response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Token $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'is_like': isLike}),
        );
      }

      if (response.statusCode == 200) {
        await fetchReviews();
      } else {
        showNiceSnackBar(
          context,
          message: 'vote_error'.tr(args: [response.body]),
          color: Colors.redAccent,
          icon: Icons.error,
        );
      }
    } catch (e) {
      print("Excepción: $e");
      showNiceSnackBar(
        context,
        message: 'network_error'.tr(args: [e.toString()]),
        color: Colors.redAccent,
        icon: Icons.error,
      );
    }
}

  void _showReviewDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'escribereseña'.tr(),
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) =>
                    Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (rating) {
                  setState(() {
                    _rating = rating;
                  });
                },
              ),
              SizedBox(height: 10),
              TextField(
                controller: _commentController,
                cursorColor: Colors.blue,
                decoration: InputDecoration(
                  labelText: 'comentario'.tr(),
                  labelStyle: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancelar".tr(),
                style:
                TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                sendReview();
              },
              child: Text(
                "Enviar".tr(),
                style:
                TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      averageRating.toStringAsFixed(1),
                      style:
                      TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.star, color: Colors.amber, size: 32),
                  ],
                ),
                if (!_hasMyReview)
                  OutlinedButton(
                    onPressed: _showReviewDialog,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.blue),
                      foregroundColor: Colors.blue,
                    ),
                    child: Text("Escribirreseña".tr()),
                  ),
              ],
            ),
            SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _reviews.length,
              itemBuilder: (context, index) {
                final review = _reviews[index];
                final isMyReview = review['username'] == _myUsername;
                final String username = review['username'] ?? '';
                final int rating = review['rating'] ?? 0;
                final String text = review['text'] ?? '';
                final int likes = review['likes_count'] ?? 0;
                final int dislikes = review['dislikes_count'] ?? 0;
                final bool? userLiked = review['user_liked'];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.grey.shade300,
                            radius: 24,
                            child: Icon(Icons.person, color: Colors.black),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      username,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(width: 8),
                                    RatingBarIndicator(
                                      rating: rating.toDouble(),
                                      itemBuilder: (context, _) => Icon(
                                          Icons.star,
                                          color: Colors.amber),
                                      itemCount: 5,
                                      itemSize: 20,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2),
                                Text(text),
                              ],
                            ),
                          ),
                          if (isMyReview)
                            Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: Text("EliminarReseña".tr()),
                                        content: Text(
                                            "seguroElimina".tr()),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text("Cancelar".tr()),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              deleteMyReview();
                                            },
                                            child: Text("EliminarR".tr(),
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                      // Zona de like/dislike (todos pueden votar en todas las reviews, incluidas las propias)
                      Padding(
                        padding: const EdgeInsets.only(left: 60.0, top: 4),
                        child: Row(
                          children: [
                            // Botón Like
                            IconButton(
                              icon: Icon(
                                Icons.thumb_up,
                                color: userLiked == true
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                              onPressed: () => handleLikeDislike(
                                  username, userLiked, true),
                            ),
                            Text('$likes'),
                            SizedBox(width: 16),
                            // Botón Dislike
                            IconButton(
                              icon: Icon(
                                Icons.thumb_down,
                                color: userLiked == false
                                    ? Colors.red
                                    : Colors.grey,
                              ),
                              onPressed: () => handleLikeDislike(
                                  username, userLiked, false),
                            ),
                            Text('$dislikes'),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
