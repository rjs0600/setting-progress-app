import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

/// Data is stored in Hive as JSON Maps (no adapters needed).
/// Boxes:
/// - settings: Map<String, dynamic> per item
/// - logs: Map<String, dynamic> per item
///
/// Setting item schema:
/// { id, category, title, content, status, priority, tags(List<String>), updatedAt(int ms) }
///
/// Log schema:
/// { id, date(int ms, at 00:00 local), settingId, did, next }

const _boxSettings = 'settings';
const _boxLogs = 'logs';
const _uuid = Uuid();

const statusOrder = ['아이디어', '초안', '사용중', '완료', '수정필요'];
const priorityOrder = ['낮음', '보통', '높음'];

Color statusColor(String s, ColorScheme cs) {
  switch (s) {
    case '수정필요':
      return Colors.red;
    case '사용중':
      return Colors.green;
    case '초안':
      return Colors.amber;
    case '완료':
      return Colors.blue;
    case '아이디어':
    default:
      return cs.outline;
  }
}

Color priorityColor(String p) {
  switch (p) {
    case '높음':
      return Colors.red;
    case '보통':
      return Colors.amber;
    case '낮음':
    default:
      return Colors.grey;
  }
}

String tagsToString(List<String> tags) => tags.join(', ');

List<String> parseTags(String s) {
  return s
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();
}

DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

String fmtDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox(_boxSettings);
  await Hive.openBox(_boxLogs);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '설정/진행 관리',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const SettingsPage(),
      const LogsPage(),
      const FiltersPage(),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder_open), label: '자료'),
          NavigationDestination(icon: Icon(Icons.article), label: '로그'),
          NavigationDestination(icon: Icon(Icons.filter_alt), label: '필터'),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _query = '';
  String _statusFilter = '전체';
  String _categoryFilter = '전체';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final box = Hive.box(_boxSettings);

    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, _, __) {
        final items = <Map<String, dynamic>>[];
        for (final key in box.keys) {
          final raw = box.get(key);
          if (raw is Map) {
            items.add(Map<String, dynamic>.from(raw));
          } else if (raw is String) {
            items.add(Map<String, dynamic>.from(jsonDecode(raw)));
          }
        }

        final categories = <String>{'전체'};
        for (final it in items) {
          categories.add((it['category'] ?? '기타').toString());
        }

        List<Map<String, dynamic>> filtered = items;
        if (_categoryFilter != '전체') {
          filtered = filtered.where((e) => (e['category'] ?? '기타') == _categoryFilter).toList();
        }
        if (_statusFilter != '전체') {
          filtered = filtered.where((e) => (e['status'] ?? '아이디어') == _statusFilter).toList();
        }
        if (_query.trim().isNotEmpty) {
          final q = _query.trim().toLowerCase();
          filtered = filtered.where((e) {
            final title = (e['title'] ?? '').toString().toLowerCase();
            final content = (e['content'] ?? '').toString().toLowerCase();
            final tags = (e['tags'] is List) ? (e['tags'] as List).join(',').toLowerCase() : '';
            return title.contains(q) || content.contains(q) || tags.contains(q);
          }).toList();
        }

        filtered.sort((a, b) {
          final sa = statusOrder.indexOf((a['status'] ?? '아이디어').toString());
          final sb = statusOrder.indexOf((b['status'] ?? '아이디어').toString());
          if (sa != sb) return sa.compareTo(sb);
          final pa = priorityOrder.indexOf((a['priority'] ?? '보통').toString());
          final pb = priorityOrder.indexOf((b['priority'] ?? '보통').toString());
          if (pa != pb) return pb.compareTo(pa); // higher first
          final ua = (a['updatedAt'] ?? 0) as int;
          final ub = (b['updatedAt'] ?? 0) as int;
          return ub.compareTo(ua);
        });

        return Scaffold(
          appBar: AppBar(
            title: const Text('자료'),
            actions: [
              IconButton(
                tooltip: '새 자료',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SettingEditScreen(initial: null)),
                  );
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingEditScreen(initial: null)),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('추가'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '제목/내용/태그 검색',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _categoryFilter,
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _categoryFilter = v ?? '전체'),
                        decoration: const InputDecoration(
                          labelText: '분류',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        items: ['전체', ...statusOrder]
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _statusFilter = v ?? '전체'),
                        decoration: const InputDecoration(
                          labelText: '진행상태',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('자료가 아직 없어요. + 버튼으로 추가해봐!'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final it = filtered[i];
                            final title = (it['title'] ?? '(제목 없음)').toString();
                            final category = (it['category'] ?? '기타').toString();
                            final status = (it['status'] ?? '아이디어').toString();
                            final priority = (it['priority'] ?? '보통').toString();
                            final tags = (it['tags'] is List) ? (it['tags'] as List).cast<String>() : <String>[];
                            final updatedAt = DateTime.fromMillisecondsSinceEpoch((it['updatedAt'] ?? 0) as int);
                            return Card(
                              child: ListTile(
                                title: Row(
                                  children: [
                                    Text(
                                      priority == '높음'
                                          ? '🔴'
                                          : (priority == '보통' ? '🟡' : '⚪'),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(title)),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: -8,
                                      children: [
                                        Chip(
                                          label: Text(category),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        Chip(
                                          label: Text(status),
                                          visualDensity: VisualDensity.compact,
                                          side: BorderSide(color: statusColor(status, cs)),
                                        ),
                                        if (tags.isNotEmpty)
                                          ...tags.take(4).map((t) => Chip(
                                                label: Text(t),
                                                visualDensity: VisualDensity.compact,
                                              )),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('수정: ${fmtDate(updatedAt)}'),
                                  ],
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => SettingDetailScreen(setting: it)),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SettingDetailScreen extends StatelessWidget {
  final Map<String, dynamic> setting;

  const SettingDetailScreen({super.key, required this.setting});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final boxSettings = Hive.box(_boxSettings);
    final boxLogs = Hive.box(_boxLogs);
    final id = (setting['id'] ?? '').toString();

    Map<String, dynamic>? _getLatest() {
      final raw = boxSettings.get(id);
      if (raw is Map) return Map<String, dynamic>.from(raw);
      if (raw is String) return Map<String, dynamic>.from(jsonDecode(raw));
      return null;
    }

    return ValueListenableBuilder(
      valueListenable: Hive.box(_boxSettings).listenable(keys: [id]),
      builder: (context, _, __) {
        final latest = _getLatest() ?? setting;
        final title = (latest['title'] ?? '(제목 없음)').toString();
        final category = (latest['category'] ?? '기타').toString();
        final status = (latest['status'] ?? '아이디어').toString();
        final priority = (latest['priority'] ?? '보통').toString();
        final content = (latest['content'] ?? '').toString();
        final tags = (latest['tags'] is List) ? (latest['tags'] as List).cast<String>() : <String>[];
        final updatedAt = DateTime.fromMillisecondsSinceEpoch((latest['updatedAt'] ?? 0) as int);

        // Gather logs for this setting
        final logs = <Map<String, dynamic>>[];
        for (final key in boxLogs.keys) {
          final raw = boxLogs.get(key);
          Map<String, dynamic>? m;
          if (raw is Map) m = Map<String, dynamic>.from(raw);
          if (raw is String) m = Map<String, dynamic>.from(jsonDecode(raw));
          if (m != null && (m['settingId'] ?? '').toString() == id) logs.add(m);
        }
        logs.sort((a, b) => (b['date'] as int).compareTo(a['date'] as int));

        return Scaffold(
          appBar: AppBar(
            title: const Text('상세'),
            actions: [
              IconButton(
                tooltip: '수정',
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SettingEditScreen(initial: latest)),
                  );
                },
              ),
              IconButton(
                tooltip: '삭제',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('삭제할까?'),
                      content: const Text('이 자료와 연결된 로그는 남겨둘지, 같이 지울지 선택할 수 있어요.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('자료만 삭제')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await boxSettings.delete(id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LogEditScreen(settingId: id, initial: null)),
              );
            },
            icon: const Icon(Icons.post_add),
            label: const Text('로그 추가'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Row(
                  children: [
                    Text(
                      priority == '높음' ? '🔴' : (priority == '보통' ? '🟡' : '⚪'),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(category)),
                    Chip(
                      label: Text(status),
                      side: BorderSide(color: statusColor(status, cs)),
                    ),
                    Chip(label: Text('수정: ${fmtDate(updatedAt)}')),
                    if (tags.isNotEmpty) ...tags.map((t) => Chip(label: Text(t))),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('내용', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SelectableText(content.isEmpty ? '(내용 없음)' : content),
                const SizedBox(height: 18),
                const Divider(),
                const Text('진행 로그', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (logs.isEmpty)
                  const Text('아직 로그가 없어요. 아래 버튼으로 하나 추가해봐!')
                else
                  ...logs.map((l) {
                    final date = DateTime.fromMillisecondsSinceEpoch(l['date'] as int);
                    final did = (l['did'] ?? '').toString();
                    final next = (l['next'] ?? '').toString();
                    return Card(
                      child: ListTile(
                        title: Text(fmtDate(date)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (did.isNotEmpty) Text('한 일: $did'),
                            if (next.isNotEmpty) Text('다음: $next'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LogEditScreen(settingId: id, initial: l),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SettingEditScreen extends StatefulWidget {
  final Map<String, dynamic>? initial;

  const SettingEditScreen({super.key, required this.initial});

  @override
  State<SettingEditScreen> createState() => _SettingEditScreenState();
}

class _SettingEditScreenState extends State<SettingEditScreen> {
  late final TextEditingController _category;
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _tags;
  String _status = '아이디어';
  String _priority = '보통';

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _category = TextEditingController(text: (init?['category'] ?? '인물').toString());
    _title = TextEditingController(text: (init?['title'] ?? '').toString());
    _content = TextEditingController(text: (init?['content'] ?? '').toString());
    final tags = (init?['tags'] is List) ? (init?['tags'] as List).cast<String>() : <String>[];
    _tags = TextEditingController(text: tagsToString(tags));
    _status = (init?['status'] ?? '아이디어').toString();
    _priority = (init?['priority'] ?? '보통').toString();
  }

  @override
  void dispose() {
    _category.dispose();
    _title.dispose();
    _content.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box(_boxSettings);
    final isEdit = widget.initial != null;
    final id = isEdit ? (widget.initial!['id']).toString() : _uuid.v4();

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? '자료 수정' : '자료 추가')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _category,
              decoration: const InputDecoration(
                labelText: '분류 (예: 인물/사건/세계관/떡밥/기타)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _status,
              items: statusOrder.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _status = v ?? '아이디어'),
              decoration: const InputDecoration(
                labelText: '진행상태',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _priority,
              items: priorityOrder.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _priority = v ?? '보통'),
              decoration: const InputDecoration(
                labelText: '중요도',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tags,
              decoration: const InputDecoration(
                labelText: '태그 (쉼표로 구분)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _content,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: '내용',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () async {
                final data = <String, dynamic>{
                  'id': id,
                  'category': _category.text.trim().isEmpty ? '기타' : _category.text.trim(),
                  'title': _title.text.trim().isEmpty ? '(제목 없음)' : _title.text.trim(),
                  'content': _content.text,
                  'status': _status,
                  'priority': _priority,
                  'tags': parseTags(_tags.text),
                  'updatedAt': DateTime.now().millisecondsSinceEpoch,
                };
                await box.put(id, data);
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.save),
              label: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  @override
  Widget build(BuildContext context) {
    final box = Hive.box(_boxLogs);
    final boxSettings = Hive.box(_boxSettings);

    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, _, __) {
        final logs = <Map<String, dynamic>>[];
        for (final key in box.keys) {
          final raw = box.get(key);
          if (raw is Map) logs.add(Map<String, dynamic>.from(raw));
          if (raw is String) logs.add(Map<String, dynamic>.from(jsonDecode(raw)));
        }
        logs.sort((a, b) => (b['date'] as int).compareTo(a['date'] as int));

        Map<String, String> settingTitles = {};
        for (final k in boxSettings.keys) {
          final raw = boxSettings.get(k);
          Map<String, dynamic>? m;
          if (raw is Map) m = Map<String, dynamic>.from(raw);
          if (raw is String) m = Map<String, dynamic>.from(jsonDecode(raw));
          if (m != null) settingTitles[m['id'].toString()] = (m['title'] ?? '').toString();
        }

        return Scaffold(
          appBar: AppBar(title: const Text('진행 로그')),
          body: logs.isEmpty
              ? const Center(child: Text('로그가 아직 없어요. 자료 상세 화면에서 “로그 추가”를 눌러봐!'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: logs.length,
                  itemBuilder: (context, i) {
                    final l = logs[i];
                    final dt = DateTime.fromMillisecondsSinceEpoch(l['date'] as int);
                    final settingId = (l['settingId'] ?? '').toString();
                    final title = settingTitles[settingId] ?? '(삭제된 자료)';
                    final did = (l['did'] ?? '').toString();
                    final next = (l['next'] ?? '').toString();
                    return Card(
                      child: ListTile(
                        title: Text('${fmtDate(dt)} · $title'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (did.isNotEmpty) Text('한 일: $did'),
                            if (next.isNotEmpty) Text('다음: $next'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class LogEditScreen extends StatefulWidget {
  final String settingId;
  final Map<String, dynamic>? initial;

  const LogEditScreen({super.key, required this.settingId, required this.initial});

  @override
  State<LogEditScreen> createState() => _LogEditScreenState();
}

class _LogEditScreenState extends State<LogEditScreen> {
  late DateTime _date;
  late final TextEditingController _did;
  late final TextEditingController _next;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _date = init != null
        ? DateTime.fromMillisecondsSinceEpoch(init['date'] as int)
        : dateOnly(DateTime.now());
    _did = TextEditingController(text: (init?['did'] ?? '').toString());
    _next = TextEditingController(text: (init?['next'] ?? '').toString());
  }

  @override
  void dispose() {
    _did.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box(_boxLogs);
    final isEdit = widget.initial != null;
    final id = isEdit ? (widget.initial!['id']).toString() : _uuid.v4();

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? '로그 수정' : '로그 추가')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('날짜'),
              subtitle: Text(fmtDate(_date)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = dateOnly(picked));
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _did,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '작업내용 (오늘 한 일)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _next,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '다음할일',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () async {
                final data = <String, dynamic>{
                  'id': id,
                  'date': _date.millisecondsSinceEpoch,
                  'settingId': widget.settingId,
                  'did': _did.text.trim(),
                  'next': _next.text.trim(),
                };
                await box.put(id, data);
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.save),
              label: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}

class FiltersPage extends StatelessWidget {
  const FiltersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('필터 가이드')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              '색 규칙(확정)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            _LegendRow(label: '아이디어', color: statusColor('아이디어', cs)),
            _LegendRow(label: '초안', color: statusColor('초안', cs)),
            _LegendRow(label: '사용중', color: statusColor('사용중', cs)),
            _LegendRow(label: '완료', color: statusColor('완료', cs)),
            _LegendRow(label: '수정필요', color: statusColor('수정필요', cs)),
            const SizedBox(height: 16),
            const Divider(),
            Text(
              '빠른 사용 팁',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            const Text('• “자료” 탭에서 분류/진행상태로 필터링 가능\n'
                '• 자료 상세 화면에서 “로그 추가”로 날짜별 진행 기록\n'
                '• 중요도: 🔴 높음 / 🟡 보통 / ⚪ 낮음'),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendRow({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}