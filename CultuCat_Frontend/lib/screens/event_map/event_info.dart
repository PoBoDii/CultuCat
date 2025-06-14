import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'event.dart';

class EventInfo extends StatelessWidget {
  final int eventId;
  final EventService eventService = EventService();

  EventInfo({required this.eventId});

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  void _showModal(BuildContext context, String titleKey, List<Widget> content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(titleKey.tr(), style: const TextStyle(color: Colors.blue)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300, maxHeight: 200),
            child: SingleChildScrollView(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: content,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("close".tr(), style: const TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  Widget _iconButton(BuildContext context, IconData icon, String titleKey, List<Widget> content) {
    if (content.isEmpty || (content.length == 1 && content[0] is Text && (content[0] as Text).data == '---')) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () => _showModal(context, titleKey, content),
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.blue),
      ),
    );
  }

  String _formatCategory(String value) {
    return value.split('/').last;
  }

  List<Widget> buildCategoriesContent(String? categories, String? tematiques) {
    List<String> categoryList = categories?.split(', ') ?? [];
    List<String> ambitsList = tematiques?.split(', ') ?? [];

    List<Widget> content = [];

    if (categoryList.isNotEmpty) {
      content.add(Text('categories_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)));
      for (var cat in categoryList) {
        content.add(Text(_formatCategory(cat)));
      }
    }

    if (ambitsList.isNotEmpty) {
      content.add(const SizedBox(height: 8));
      content.add(Text('ambits_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)));
      for (var amb in ambitsList) {
        content.add(Text(_formatCategory(amb)));
      }
    }

    return content.isNotEmpty ? content : [Text('no_data_symbol'.tr())];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
      future: eventService.fetchEventDetail(eventId).then(
            (data) => data.map((key, value) => MapEntry(key, value?.toString())),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("error".tr() + ": ${snapshot.error}"));
        } else if (!snapshot.hasData) {
          return Center(child: Text("no_data_available".tr()));
        }

        final event = snapshot.data!;
        String locationText = (event['zipcode'] == null || event['zipcode']!.isEmpty)
            ? event['address'] ?? ''
            : "${event['address']}, ${event['zipcode']}";

        String dateRange = _formatDate(event['inidate']);
        if (event['inidate'] != event['enddate']) dateRange += " - ${_formatDate(event['enddate'])}";

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (locationText.isNotEmpty && locationText != "Desconocida")
                              _iconButton(context, Icons.location_on, "location", [Text(locationText)]),
                            if (event['tickets'] != null && event['tickets']!.isNotEmpty)
                              _iconButton(context, Icons.confirmation_number, "tickets", [Text(event['tickets']!)]),
                            if (event['schedule'] != null && event['schedule']!.isNotEmpty)
                              _iconButton(context, Icons.access_time, "schedule", [Text(event['schedule']!)]),
                            if (event['telefon'] != null && event['telefon']!.isNotEmpty)
                              _iconButton(context, Icons.phone, "phone", [Text(event['telefon']!)]),
                            if (event['email'] != null && event['email']!.isNotEmpty)
                              _iconButton(context, Icons.email, "email", [Text(event['email']!)]),
                            if ((event['categories'] != null && event['categories']!.isNotEmpty) ||
                                (event['tematiques'] != null && event['tematiques']!.isNotEmpty))
                              _iconButton(
                                context,
                                Icons.category,
                                "categories_and_ambits",
                                buildCategoriesContent(event['categories'], event['tematiques']),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      dateRange,
                      style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ExpandableDescription(description: event['description'] ?? ''),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ExpandableDescription extends StatefulWidget {
  final String description;

  const ExpandableDescription({required this.description, super.key});

  @override
  State<ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isExpanded
              ? widget.description
              : (widget.description.length > 300
              ? "${widget.description.substring(0, 300)}..."
              : widget.description),
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () {
            setState(() {
              isExpanded = !isExpanded;
            });
          },
          child: Text(
            isExpanded ? "see_less".tr() : "see_more".tr(),
            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
