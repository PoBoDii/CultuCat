import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '/utils/server_url.dart';
import '/utils/user_preferences.dart';
import '/screens/event_map/event.dart';
import 'package:easy_localization/easy_localization.dart';

class TopRatedEventsScreen extends StatefulWidget {
  const TopRatedEventsScreen({super.key});

  @override
  State<TopRatedEventsScreen> createState() => _TopRatedEventsScreenState();
}

class _TopRatedEventsScreenState extends State<TopRatedEventsScreen> {
  List<dynamic> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchTopEvents();
  }

  Future<void> _fetchTopEvents() async {
    final token = await UserPreferences.getToken();
    final resp = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/events/rated/'),
      headers: {'Authorization': 'Token $token'},
    );
    if (resp.statusCode == 200) {
      setState(() {
        _events = jsonDecode(resp.body)['events'];
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'top_events_title'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
          ? Center(child: Text('top_events_empty'.tr()))
          : ListView.builder(
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final event = _events[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EventScreen(
                      texto: event['name'],
                      id: event['eventid'].toString(),
                    ),
                  ),
                );

                // 🔄 Refresca la llista després de tornar
                if (mounted) {
                  _fetchTopEvents();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['name'],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.orange[400], size: 18),
                        const SizedBox(width: 4),
                        Text(
                          "${event['average_rate'].toStringAsFixed(1)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "(${event['num_reviews']} ${'top_events_reviews'.tr()})",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

