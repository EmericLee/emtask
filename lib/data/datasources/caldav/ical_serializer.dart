import '../../../domain/entities/task.dart';
import '../../../domain/entities/task_status.dart';

/// iCalendar VTODO 序列化器。
///
/// 实现 RFC 5545 中 VTODO 组件的解析与生成，满足 Nextcloud Tasks 同步需求。
/// 支持行折叠 / 反折叠、TEXT 转义、UTC 时间格式化。
class IcalSerializer {
  const IcalSerializer._();

  /// 解析整段 iCalendar 文本，返回其中第一个 VTODO 对应的 [Task]。
  /// 若无 VTODO 返回 null。
  static Task? parseVTodo(
    String icalText, {
    required String calendarUrl,
    String? href,
    String? etag,
  }) {
    final unfolded = _unfold(icalText);
    final lines = _splitLines(unfolded);
    if (lines.isEmpty) return null;

    final props = <String, _IcalProperty>{};
    final categories = <String>[];

    var inVtodo = false;
    for (final line in lines) {
      final prop = _parseLine(line);
      if (prop == null) continue;

      switch (prop.name) {
        case 'BEGIN':
          if (prop.value == 'VTODO') inVtodo = true;
          break;
        case 'END':
          if (prop.value == 'VTODO') inVtodo = false;
          break;
        default:
          if (inVtodo) {
            if (prop.name == 'CATEGORIES') {
              categories.addAll(_splitCategories(prop.value));
            } else {
              props[prop.name] = prop;
            }
          }
      }
    }

    final uid = props['UID']?.value;
    if (uid == null || uid.isEmpty) return null;

    return Task(
      localId: 0,
      calendarUrl: calendarUrl,
      uid: uid,
      summary: _unescapeText(props['SUMMARY']?.value ?? ''),
      description: _unescapeText(props['DESCRIPTION']?.value ?? ''),
      start: _parseDate(props['DTSTART']),
      due: _parseDate(props['DUE']),
      completed: _parseDate(props['COMPLETED']),
      status: TaskStatus.fromIcal(props['STATUS']?.value),
      priority: TaskPriority.fromIcal(int.tryParse(props['PRIORITY']?.value ?? '')),
      percent: int.tryParse(props['PERCENT-COMPLETE']?.value ?? '') ?? 0,
      categories: categories,
      parentUid: props['RELATED-TO']?.value,
      href: href,
      etag: etag,
      created: _parseDate(props['CREATED']),
      lastModified: _parseDate(props['LAST-MODIFIED']),
      sortOrder: int.tryParse(props['X-APPLE-SORT-ORDER']?.value ?? ''),
    );
  }

  /// 将 [Task] 序列化为完整 iCalendar 文本（VCALENDAR 包裹 VTODO）。
  ///
  /// [allDayDates] 为 true 时，DTSTART / DUE 使用 VALUE=DATE 格式（仅日期），
  /// 与"日期字段不显示时间"的设置绑定。COMPLETED 始终为 DATE-TIME（RFC 5545 要求）。
  static String serialize(Task task, {bool allDayDates = false}) {
    final buf = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//EM Task//CalDAV Client//ZH')
      ..writeln('CALSCALE:GREGORIAN')
      ..writeln('BEGIN:VTODO');

    buf
      ..writeln('UID:${task.uid}')
      ..writeln('SUMMARY:${_escapeText(task.summary)}');
    if (task.description.isNotEmpty) {
      buf.writeln('DESCRIPTION:${_escapeText(task.description)}');
    }
    if (task.start != null) {
      if (allDayDates) {
        buf.writeln('DTSTART;VALUE=DATE:${_formatDateOnly(task.start!)}');
      } else {
        buf.writeln('DTSTART:${_formatDate(task.start!)}');
      }
    }
    if (task.due != null) {
      if (allDayDates) {
        buf.writeln('DUE;VALUE=DATE:${_formatDateOnly(task.due!)}');
      } else {
        buf.writeln('DUE:${_formatDate(task.due!)}');
      }
    }
    if (task.completed != null) {
      buf.writeln('COMPLETED:${_formatDate(task.completed!)}');
    }
    buf
      ..writeln('STATUS:${task.status.icalValue}')
      ..writeln('PRIORITY:${task.priority.icalValue}');
    if (task.percent > 0) {
      buf.writeln('PERCENT-COMPLETE:${task.percent}');
    }
    if (task.categories.isNotEmpty) {
      buf.writeln('CATEGORIES:${task.categories.map(_escapeText).join(',')}');
    }
    if (task.parentUid != null && task.parentUid!.isNotEmpty) {
      buf.writeln('RELATED-TO:${task.parentUid}');
    }
    if (task.sortOrder != null) {
      buf.writeln('X-APPLE-SORT-ORDER:${task.sortOrder}');
    }
    final now = DateTime.now().toUtc();
    buf
      ..writeln('CREATED:${_formatDate(task.created ?? now)}')
      ..writeln('LAST-MODIFIED:${_formatDate(task.lastModified ?? now)}')
      ..writeln('END:VTODO')
      ..writeln('END:VCALENDAR');
    return _fold(buf.toString());
  }

  // ----- 行折叠 / 反折叠（RFC 5545 §3.1）-----

  static String _unfold(String text) {
    // 折叠行：CRLF + (空格 | 制表符) 表示续行
    return text.replaceAll(RegExp(r'\r?\n[ \t]'), '');
  }

  static String _fold(String text) {
    // 按 75 字节折叠（简化版：按字符）
    final out = StringBuffer();
    for (final line in text.split('\n')) {
      if (line.isEmpty) {
        out.writeln();
        continue;
      }
      var remaining = line;
      while (remaining.length > 75) {
        out.writeln(remaining.substring(0, 75));
        remaining = ' ${remaining.substring(75)}';
      }
      out.writeln(remaining);
    }
    return out.toString();
  }

  static List<String> _splitLines(String text) {
    return text.split(RegExp(r'\r?\n')).where((l) => l.isNotEmpty).toList();
  }

  // ----- 行解析 -----

  static _IcalProperty? _parseLine(String line) {
    if (line.isEmpty) return null;
    var rest = line;

    // 名字（可能带参数，如 DUE;TZID=...:value）
    final colon = rest.indexOf(':');
    if (colon < 0) return null;

    final nameAndParams = rest.substring(0, colon);
    final value = rest.substring(colon + 1);

    final semi = nameAndParams.indexOf(';');
    final name = semi < 0 ? nameAndParams : nameAndParams.substring(0, semi);
    final params = semi < 0
        ? <String, String>{}
        : _parseParams(nameAndParams.substring(semi + 1));

    return _IcalProperty(
      name: name.toUpperCase(),
      value: value,
      params: params,
    );
  }

  static Map<String, String> _parseParams(String s) {
    final result = <String, String>{};
    for (final part in s.split(';')) {
      final eq = part.indexOf('=');
      if (eq > 0) {
        result[part.substring(0, eq).toUpperCase()] = part.substring(eq + 1);
      }
    }
    return result;
  }

  // ----- 日期时间 -----

  static String _formatDate(DateTime dt) {
    final utc = dt.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}'
        '${two(utc.month)}${two(utc.day)}'
        'T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  /// 仅日期格式（VALUE=DATE）：YYYYMMDD，无时间部分。
  static String _formatDateOnly(DateTime dt) {
    final utc = dt.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}'
        '${two(utc.month)}${two(utc.day)}';
  }

  static DateTime? _parseDate(_IcalProperty? prop) {
    if (prop == null) return null;
    final v = prop.value;
    if (v.isEmpty) return null;

    // 支持 YYYYMMDDTHHMMSSZ 与 YYYYMMDDTHHMMSS
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$',
    ).firstMatch(v);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
        int.parse(match.group(6)!),
      ).toUtc();
    }

    // 仅日期 YYYYMMDD
    final dateOnly = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(v);
    if (dateOnly != null) {
      return DateTime(
        int.parse(dateOnly.group(1)!),
        int.parse(dateOnly.group(2)!),
        int.parse(dateOnly.group(3)!),
      ).toUtc();
    }
    return null;
  }

  // ----- TEXT 转义（RFC 5545 §3.3.11）-----

  static String _escapeText(String s) {
    return s
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\n', r'\n');
  }

  static String _unescapeText(String s) {
    final buf = StringBuffer();
    var i = 0;
    while (i < s.length) {
      final ch = s[i];
      if (ch == r'\' && i + 1 < s.length) {
        final next = s[i + 1];
        switch (next) {
          case 'n':
          case 'N':
            buf.writeln();
            break;
          case r'\':
          case ';':
          case ',':
            buf.write(next);
            break;
          default:
            buf.write(next);
        }
        i += 2;
      } else {
        buf.write(ch);
        i++;
      }
    }
    return buf.toString().trimRight();
  }

  static List<String> _splitCategories(String value) {
    if (value.isEmpty) return const [];
    final result = <String>[];
    var buf = StringBuffer();
    var i = 0;
    while (i < value.length) {
      final ch = value[i];
      if (ch == r'\' && i + 1 < value.length) {
        buf.write(value[i + 1]);
        i += 2;
      } else if (ch == ',') {
        final s = buf.toString().trim();
        if (s.isNotEmpty) result.add(s);
        buf = StringBuffer();
        i++;
      } else {
        buf.write(ch);
        i++;
      }
    }
    final s = buf.toString().trim();
    if (s.isNotEmpty) result.add(s);
    return result;
  }
}

/// 解析后的单个 iCalendar 属性。
class _IcalProperty {
  const _IcalProperty({
    required this.name,
    required this.value,
    required this.params,
  });

  final String name;
  final String value;
  final Map<String, String> params;
}
