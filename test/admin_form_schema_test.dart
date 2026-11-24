import 'package:do_vui_ai_thuong/models/topic_model.dart';
import 'package:do_vui_ai_thuong/screens/admin/admin_edit_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('topic form includes generated ID and read-only question count', (
    tester,
  ) async {
    Map<String, dynamic>? savedTopic;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                savedTopic = await showTopicEditor(context);
              },
              child: const Text('Open topic editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open topic editor'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Tên chủ đề'), 'Chủ đề địa lý');
    await tester.pump();

    expect(
      tester.widget<TextField>(_field('ID')).controller!.text,
      'topic_chu_de_dia_ly',
    );
    expect(tester.widget<TextField>(_field('Số câu hỏi')).readOnly, isTrue);
    await tester.enterText(_field('ID'), 'topic_geo');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(savedTopic?['id'], 'topic_geo');
    expect(savedTopic?['name'], 'Chủ đề địa lý');
  });

  testWidgets('quiz set form includes database fields and computed stats', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const topic = Topic(
      id: 'topic_geo',
      name: 'Đố dân gian & Câu đố mẹo — Bộ 1',
      description: '',
      icon: '🌍',
      questionCount: 8,
    );
    Map<String, dynamic>? savedSet;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                savedSet = await showQuizSetEditor(
                  context,
                  topics: const [topic],
                  loadQuestions: (_) async => [],
                );
              },
              child: const Text('Open set editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open set editor'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(_field('Tên bộ đề'), 'Đề địa lý');
    await tester.pump();

    expect(
      tester.widget<TextField>(_field('ID')).controller!.text,
      'set_de_dia_ly',
    );
    expect(tester.widget<TextField>(_field('Số lượt thi')).readOnly, isTrue);
    expect(
      tester.widget<TextField>(_field('Điểm trung bình')).readOnly,
      isTrue,
    );

    await tester.enterText(_field('ID'), 'set_geo_quiz');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(savedSet?['id'], 'set_geo_quiz');
    expect(savedSet?['topicId'], 'topic_geo');
    expect(savedSet?['title'], 'Đề địa lý');
    expect(savedSet?['questionCount'], 10);
  });
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);
