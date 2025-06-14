import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'faq_title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Cada pregunta se define con este componente
          _FAQItem(
            question: 'faq_question_1'.tr(),
            answer: 'faq_answer_1'.tr(),
          ),
          const SizedBox(height: 16),

          _FAQItem(
            question: 'faq_question_2'.tr(),
            answer: 'faq_answer_2'.tr(),
          ),
          const SizedBox(height: 16),

          _FAQItem(
            question: 'faq_question_3'.tr(),
            answer: 'faq_answer_3'.tr(),
          ),
          const SizedBox(height: 16),

          _FAQItem(
            question: 'faq_question_4'.tr(),
            answer: 'faq_answer_4'.tr(),
          ),
          const SizedBox(height: 16),

          _FAQItem(
            question: 'faq_question_5'.tr(),
            answer: 'faq_answer_5'.tr(),
          ),
          const SizedBox(height: 16),

          _FAQItem(
            question: 'faq_question_6'.tr(),
            answer: 'faq_answer_6'.tr(),
          ),
          const SizedBox(height: 16),

          _FAQItem(
            question: 'faq_question_7'.tr(),
            answer: 'faq_answer_7'.tr(),
          ),
          const SizedBox(height: 16),

          _FAQItem(
            question: 'faq_question_8'.tr(),
            answer: 'faq_answer_8'.tr(),
          ),
          const SizedBox(height: 16),

          _FAQItem(
            question: 'faq_question_9'.tr(),
            answer: 'faq_answer_9'.tr(),
          ),
          const SizedBox(height: 16),

          _FAQItem(
            question: 'faq_question_10'.tr(),
            answer: 'faq_answer_10'.tr(),
          ),
          const SizedBox(height: 16),

          _FAQItem(
            question: 'faq_question_11'.tr(),
            answer: 'faq_answer_11'.tr(),
          ),
          const SizedBox(height: 16),

          // Puedes añadir más preguntas siguiendo el mismo patrón
        ],
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          // Cabecera de la pregunta (siempre visible)
          ListTile(
            title: Text(
              widget.question,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
          ),
          // Contenido de la respuesta (visible solo si está expandido)
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(widget.answer),
            ),
        ],
      ),
    );
  }
}