import 'package:flutter/material.dart';

import '../../models/item_model.dart';
import '../../models/question_model.dart';
import '../../models/quiz_set_model.dart';
import '../../models/topic_model.dart';

Future<Map<String, dynamic>?> showTopicEditor(
  BuildContext context, {
  Topic? topic,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _TopicEditor(topic: topic),
  );
}

Future<Map<String, dynamic>?> showItemEditor(
  BuildContext context, {
  ItemModel? item,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _ItemEditor(item: item),
  );
}

Future<Map<String, dynamic>?> showQuestionEditor(
  BuildContext context, {
  required List<Topic> topics,
  Question? question,
  String? initialTopicId,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _QuestionEditor(
      topics: topics,
      question: question,
      initialTopicId: initialTopicId,
    ),
  );
}

Future<Map<String, dynamic>?> showQuizSetEditor(
  BuildContext context, {
  required List<Topic> topics,
  required Future<List<Question>> Function(String topicId) loadQuestions,
  QuizSet? quizSet,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _QuizSetEditor(
      topics: topics,
      loadQuestions: loadQuestions,
      quizSet: quizSet,
    ),
  );
}

class _TopicEditor extends StatefulWidget {
  const _TopicEditor({this.topic});

  final Topic? topic;

  @override
  State<_TopicEditor> createState() => _TopicEditorState();
}

class _TopicEditorState extends State<_TopicEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _icon;
  late final TextEditingController _imageUrl;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final topic = widget.topic;
    _name = TextEditingController(text: topic?.name ?? '');
    _description = TextEditingController(text: topic?.description ?? '');
    _icon = TextEditingController(text: topic?.icon ?? '');
    _imageUrl = TextEditingController(text: topic?.imageUrl ?? '');
    _isActive = topic?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _icon.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.topic == null ? 'Thêm chủ đề' : 'Sửa chủ đề'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Tên chủ đề'),
                validator: _required,
              ),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Mô tả'),
                maxLines: 2,
              ),
              TextFormField(
                controller: _icon,
                decoration: const InputDecoration(labelText: 'Biểu tượng'),
              ),
              TextFormField(
                controller: _imageUrl,
                decoration: const InputDecoration(
                  labelText: 'URL ảnh đại diện',
                ),
                keyboardType: TextInputType.url,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Đang hiển thị'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _save, child: const Text('Lưu')),
      ],
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Không được để trống' : null;

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'icon': _icon.text.trim(),
      'imageUrl': _imageUrl.text.trim(),
      'isActive': _isActive,
    });
  }
}

class _ItemEditor extends StatefulWidget {
  const _ItemEditor({this.item});

  final ItemModel? item;

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _effect;
  late final TextEditingController _price;
  late final TextEditingController _description;
  late String _type;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _effect = TextEditingController(text: item?.lifelineCode ?? '');
    _price = TextEditingController(text: item?.price.toString() ?? '');
    _description = TextEditingController(text: item?.description ?? '');
    _type = item?.type ?? 'help';
    _isActive = item?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _effect.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Thêm vật phẩm' : 'Sửa vật phẩm'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Tên vật phẩm'),
                validator: _required,
              ),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Loại'),
                items: const [
                  DropdownMenuItem(value: 'help', child: Text('Trợ giúp')),
                  DropdownMenuItem(value: 'frame', child: Text('Khung avatar')),
                  DropdownMenuItem(value: 'title', child: Text('Danh hiệu')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              if (_type == 'help')
                TextFormField(
                  controller: _effect,
                  decoration: const InputDecoration(
                    labelText: 'Mã hiệu ứng (vd: fifty_fifty)',
                  ),
                  validator: _required,
                ),
              TextFormField(
                controller: _price,
                decoration: const InputDecoration(labelText: 'Giá (xu)'),
                keyboardType: TextInputType.number,
                validator: _positiveInteger,
              ),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Mô tả'),
                maxLines: 2,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Đang bán'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _save, child: const Text('Lưu')),
      ],
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Không được để trống' : null;

  String? _positiveInteger(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number < 0 ? 'Nhập số nguyên từ 0 trở lên' : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'name': _name.text.trim(),
      'type': _type,
      'lifelineCode': _type == 'help' ? _effect.text.trim() : '',
      'price': int.parse(_price.text),
      'description': _description.text.trim(),
      'isActive': _isActive,
    });
  }
}

class _QuestionEditor extends StatefulWidget {
  const _QuestionEditor({
    required this.topics,
    this.question,
    this.initialTopicId,
  });

  final List<Topic> topics;
  final Question? question;
  final String? initialTopicId;

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _content;
  late final TextEditingController _explanation;
  late final List<TextEditingController> _options;
  late String? _topicId;
  late String _level;
  late int _correctIndex;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final question = widget.question;
    _content = TextEditingController(text: question?.content ?? '');
    _explanation = TextEditingController(text: question?.explanation ?? '');
    _options = List.generate(
      4,
      (index) => TextEditingController(
        text: question != null && index < question.options.length
            ? question.options[index]
            : '',
      ),
    );
    _topicId =
        question?.topicId ??
        widget.initialTopicId ??
        (widget.topics.isEmpty ? null : widget.topics.first.id);
    _level = question?.level ?? 'easy';
    _correctIndex = question != null && question.correctIndex >= 0
        ? question.correctIndex
        : 0;
    _isActive = question?.isActive ?? true;
  }

  @override
  void dispose() {
    _content.dispose();
    _explanation.dispose();
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.question == null ? 'Thêm câu hỏi' : 'Sửa câu hỏi'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _topicId,
                decoration: const InputDecoration(labelText: 'Chủ đề'),
                items: widget.topics
                    .map(
                      (topic) => DropdownMenuItem(
                        value: topic.id,
                        child: Text(topic.name),
                      ),
                    )
                    .toList(),
                validator: (value) => value == null ? 'Hãy chọn chủ đề' : null,
                onChanged: (value) => setState(() => _topicId = value),
              ),
              TextFormField(
                controller: _content,
                decoration: const InputDecoration(
                  labelText: 'Nội dung câu hỏi',
                ),
                maxLines: 3,
                validator: _required,
              ),
              for (var index = 0; index < _options.length; index++)
                TextFormField(
                  controller: _options[index],
                  decoration: InputDecoration(
                    labelText: 'Phương án ${index + 1}',
                  ),
                  validator: _required,
                ),
              DropdownButtonFormField<int>(
                initialValue: _correctIndex,
                decoration: const InputDecoration(labelText: 'Đáp án đúng'),
                items: List.generate(
                  4,
                  (index) => DropdownMenuItem(
                    value: index,
                    child: Text('Phương án ${index + 1}'),
                  ),
                ),
                onChanged: (value) {
                  if (value != null) setState(() => _correctIndex = value);
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _level,
                decoration: const InputDecoration(labelText: 'Độ khó'),
                items: const [
                  DropdownMenuItem(value: 'easy', child: Text('Dễ')),
                  DropdownMenuItem(value: 'medium', child: Text('Trung bình')),
                  DropdownMenuItem(value: 'hard', child: Text('Khó')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _level = value);
                },
              ),
              TextFormField(
                controller: _explanation,
                decoration: const InputDecoration(labelText: 'Giải thích'),
                maxLines: 2,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Đang sử dụng'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _save, child: const Text('Lưu')),
      ],
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Không được để trống' : null;

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'topicId': _topicId,
      'content': _content.text.trim(),
      'options': _options.map((option) => option.text.trim()).toList(),
      'correctIndex': _correctIndex,
      'level': _level,
      'explanation': _explanation.text.trim(),
      'isActive': _isActive,
    });
  }
}

class _QuizSetEditor extends StatefulWidget {
  const _QuizSetEditor({
    required this.topics,
    required this.loadQuestions,
    this.quizSet,
  });

  final List<Topic> topics;
  final Future<List<Question>> Function(String topicId) loadQuestions;
  final QuizSet? quizSet;

  @override
  State<_QuizSetEditor> createState() => _QuizSetEditorState();
}

class _QuizSetEditorState extends State<_QuizSetEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _duration;
  late final TextEditingController _questionCount;
  late String? _topicId;
  late String _level;
  late String _selectionMode;
  late bool _isActive;
  Set<String> _selectedQuestions = {};
  List<Question> _availableQuestions = [];
  bool _loadingQuestions = false;
  String? _questionError;

  @override
  void initState() {
    super.initState();
    final set = widget.quizSet;
    _title = TextEditingController(text: set?.title ?? '');
    _description = TextEditingController(text: set?.description ?? '');
    _duration = TextEditingController(text: '${set?.durationSec ?? 300}');
    _questionCount = TextEditingController(text: '${set?.questionCount ?? 10}');
    _topicId =
        set?.topicId ?? (widget.topics.isEmpty ? null : widget.topics.first.id);
    _level = set?.level ?? 'mixed';
    _selectionMode = set?.selectionMode ?? 'random';
    _selectedQuestions = {...?set?.questionIds};
    _isActive = set?.isActive ?? true;
    if (_topicId != null) _fetchQuestions(_topicId!);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _duration.dispose();
    _questionCount.dispose();
    super.dispose();
  }

  Future<void> _fetchQuestions(String topicId) async {
    setState(() {
      _loadingQuestions = true;
      _questionError = null;
    });
    try {
      final questions = await widget.loadQuestions(topicId);
      if (!mounted || topicId != _topicId) return;
      setState(() => _availableQuestions = questions);
    } catch (error) {
      if (!mounted) return;
      setState(() => _questionError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingQuestions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.quizSet == null ? 'Thêm bộ đề' : 'Sửa bộ đề'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Tên bộ đề'),
                validator: _required,
              ),
              DropdownButtonFormField<String>(
                initialValue: _topicId,
                decoration: const InputDecoration(labelText: 'Chủ đề'),
                items: widget.topics
                    .map(
                      (topic) => DropdownMenuItem(
                        value: topic.id,
                        child: Text(topic.name),
                      ),
                    )
                    .toList(),
                validator: (value) => value == null ? 'Hãy chọn chủ đề' : null,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _topicId = value;
                    _selectedQuestions.clear();
                  });
                  _fetchQuestions(value);
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _level,
                decoration: const InputDecoration(labelText: 'Độ khó'),
                items: const [
                  DropdownMenuItem(value: 'easy', child: Text('Dễ')),
                  DropdownMenuItem(value: 'medium', child: Text('Trung bình')),
                  DropdownMenuItem(value: 'hard', child: Text('Khó')),
                  DropdownMenuItem(value: 'mixed', child: Text('Tổng hợp')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _level = value);
                },
              ),
              TextFormField(
                controller: _duration,
                decoration: const InputDecoration(
                  labelText: 'Thời gian (giây)',
                ),
                keyboardType: TextInputType.number,
                validator: _positiveInteger,
              ),
              DropdownButtonFormField<String>(
                initialValue: _selectionMode,
                decoration: const InputDecoration(labelText: 'Cách chọn câu'),
                items: const [
                  DropdownMenuItem(
                    value: 'random',
                    child: Text('Ngẫu nhiên theo số lượng'),
                  ),
                  DropdownMenuItem(
                    value: 'manual',
                    child: Text('Chọn câu hỏi thủ công'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectionMode = value;
                    _selectedQuestions.clear();
                  });
                },
              ),
              if (_selectionMode == 'random')
                TextFormField(
                  controller: _questionCount,
                  decoration: const InputDecoration(labelText: 'Số câu hỏi'),
                  keyboardType: TextInputType.number,
                  validator: _positiveInteger,
                )
              else
                _questionPicker(),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Mô tả'),
                maxLines: 2,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Đang hoạt động'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _save, child: const Text('Lưu')),
      ],
    );
  }

  Widget _questionPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _loadingQuestions ? null : _chooseQuestions,
            icon: const Icon(Icons.checklist),
            label: Text('Chọn câu hỏi (${_selectedQuestions.length})'),
          ),
        ),
        if (_loadingQuestions)
          const LinearProgressIndicator()
        else if (_questionError != null)
          Text(_questionError!, style: const TextStyle(color: Colors.red))
        else if (_availableQuestions.isEmpty)
          const Text('Chủ đề chưa có câu hỏi đang hoạt động.')
        else if (_selectedQuestions.isEmpty)
          const Text('Hãy chọn ít nhất một câu hỏi.')
        else
          Text('Đã chọn ${_selectedQuestions.length} câu.'),
      ],
    );
  }

  Future<void> _chooseQuestions() async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _QuestionPickerDialog(
        questions: _availableQuestions,
        selectedIds: _selectedQuestions,
      ),
    );
    if (selected != null) setState(() => _selectedQuestions = selected);
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Không được để trống' : null;

  String? _positiveInteger(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number <= 0 ? 'Nhập số nguyên lớn hơn 0' : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectionMode == 'manual' && _selectedQuestions.isEmpty) {
      return;
    }
    Navigator.pop(context, {
      'topicId': _topicId,
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'level': _level,
      'durationSec': int.parse(_duration.text),
      'questionCount': _selectionMode == 'manual'
          ? _selectedQuestions.length
          : int.parse(_questionCount.text),
      'isActive': _isActive,
      'selectionMode': _selectionMode,
      'questionIds': _selectionMode == 'manual'
          ? _selectedQuestions.toList()
          : <String>[],
    });
  }
}

class _QuestionPickerDialog extends StatefulWidget {
  const _QuestionPickerDialog({
    required this.questions,
    required this.selectedIds,
  });

  final List<Question> questions;
  final Set<String> selectedIds;

  @override
  State<_QuestionPickerDialog> createState() => _QuestionPickerDialogState();
}

class _QuestionPickerDialogState extends State<_QuestionPickerDialog> {
  late final Set<String> _selected = {...widget.selectedIds};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chọn câu hỏi cho bộ đề'),
      content: SizedBox(
        width: 440,
        height: 360,
        child: ListView.builder(
          itemCount: widget.questions.length,
          itemBuilder: (context, index) {
            final question = widget.questions[index];
            return CheckboxListTile(
              value: _selected.contains(question.id),
              title: Text(
                question.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(question.levelLabel),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selected.add(question.id);
                  } else {
                    _selected.remove(question.id);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text('Chọn (${_selected.length})'),
        ),
      ],
    );
  }
}
