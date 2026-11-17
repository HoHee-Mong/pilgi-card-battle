import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/models/card.dart';
import '../../core/models/source.dart';
import 'notebook_model.dart';

/// 족보 내보내기 범위.
enum ExportScope {
  /// 내 카드 중 검수 완료만
  myVerified,

  /// 내 카드 전부 (초안 포함)
  myAll,

  /// 이 과목 방에 올라온 카드 (친구 카드 포함, 투표 수 표시)
  room,
}

/// 내보낼 카드 한 장. 방 카드면 [votes]·[author]가 있다.
typedef ExportCard = ({QuizCard card, int? votes, String? author});

/// 주차 하나: 자료 요약 + 카드.
typedef ExportWeek = ({
  int week,
  List<({String label, String summary})> summaries,
  List<ExportCard> cards,
});

/// 원본 파일(PDF·녹음·사진)은 넣지 않는다. 요약·출처 이름·카드만 넣는다.
class NotebookExport {
  const NotebookExport({
    required this.subjectName,
    required this.scope,
    required this.withAnswers,
    required this.weeks,
    required this.createdAt,
  });

  final String subjectName;
  final ExportScope scope;
  final bool withAnswers;
  final List<ExportWeek> weeks;
  final DateTime createdAt;

  int get cardCount => weeks.fold(0, (n, w) => n + w.cards.length);
  bool get isEmpty => cardCount == 0;

  static const notice = '수업 자료로 우리가 만든 예상 문제예요. 실제 기출문제가 아니에요.';

  String get scopeLabel => switch (scope) {
    ExportScope.myVerified => '내 카드 (검수 완료)',
    ExportScope.myAll => '내 카드 (초안 포함)',
    ExportScope.room => '스터디 방 카드',
  };

  String get fileName {
    final d = createdAt;
    final ymd = '${d.year}${_two(d.month)}${_two(d.day)}';
    final safe = subjectName.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
    return '족보_${safe}_$ymd.pdf';
  }

  /// 주차별로 묶는다. 카드가 있는 주차만 넣고, 그 주차의 자료 요약을 같이 넣는다.
  factory NotebookExport.build({
    required String subjectName,
    required ExportScope scope,
    required bool withAnswers,
    required List<ExportCard> cards,
    required List<StudySource> sources,
    DateTime? now,
  }) {
    final byWeek = groupByWeek(cards, (c) => c.card.week);
    final sourcesByWeek = groupByWeek(
      sources.where((s) => (s.summary ?? '').trim().isNotEmpty),
      (s) => s.week,
    );
    return NotebookExport(
      subjectName: subjectName,
      scope: scope,
      withAnswers: withAnswers,
      createdAt: now ?? DateTime.now(),
      weeks: [
        for (final e in byWeek.entries)
          (
            week: e.key,
            summaries: [
              for (final s in sourcesByWeek[e.key] ?? const <StudySource>[])
                (label: s.fileName, summary: s.summary!.trim()),
            ],
            cards: e.value,
          ),
      ],
    );
  }

  /// 메신저에 붙여 넣기 좋은 텍스트.
  String toText() {
    final b = StringBuffer()
      ..writeln('📒 $subjectName 족보')
      ..writeln('$scopeLabel · 문제 $cardCount개 · ${_date(createdAt)}')
      ..writeln('※ $notice');
    var no = 0;
    for (final w in weeks) {
      b
        ..writeln()
        ..writeln('━━ ${w.week}주차 ━━');
      for (final s in w.summaries) {
        b.writeln('[요약] ${s.label}: ${s.summary}');
      }
      for (final c in w.cards) {
        no++;
        final card = c.card;
        b
          ..writeln()
          ..writeln(
            '$no. [${typeLabel(card.type)}] ${card.question}${_meta(c)}',
          );
        if (card.type == CardType.mcq) {
          for (final (i, ch) in card.choices.indexed) {
            b.writeln('   ${_circled(i)} $ch');
          }
        }
        if (withAnswers) {
          b.writeln('   정답: ${card.answer}');
          if (card.explanation.trim().isNotEmpty) {
            b.writeln('   해설: ${card.explanation.trim()}');
          }
          if (card.sourceLabel.trim().isNotEmpty) {
            b.writeln('   출처: ${card.sourceLabel.trim()}');
          }
        }
      }
    }
    return b.toString().trimRight();
  }

  /// PDF 파일 바이트. 한글 글꼴(Noto Sans KR)은 처음 한 번 인터넷에서 받는다.
  Future<Uint8List> toPdf() async {
    final regular = await PdfGoogleFonts.notoSansKRRegular();
    final bold = await PdfGoogleFonts.notoSansKRBold();
    final doc = pw.Document(title: '$subjectName 족보', author: '필기 카드 배틀');
    final grey = PdfColor.fromHex('#666666');
    final line = PdfColor.fromHex('#DDDDDD');

    var no = 0;
    final body = <pw.Widget>[];
    for (final w in weeks) {
      body.add(
        pw.Header(
          level: 1,
          child: pw.Text(
            '${w.week}주차',
            style: pw.TextStyle(font: bold, fontSize: 16),
          ),
        ),
      );
      for (final s in w.summaries) {
        body.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F4F4F4'),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '요약 · ${s.label}',
                  style: pw.TextStyle(font: bold, fontSize: 9, color: grey),
                ),
                pw.SizedBox(height: 2),
                pw.Text(s.summary, style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
        );
      }
      for (final c in w.cards) {
        no++;
        final card = c.card;
        body.add(
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: line)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '$no. ${card.question}',
                  style: pw.TextStyle(font: bold, fontSize: 11),
                ),
                pw.Text(
                  '${typeLabel(card.type)}${_meta(c)}',
                  style: pw.TextStyle(fontSize: 8, color: grey),
                ),
                if (card.type == CardType.mcq)
                  for (final (i, ch) in card.choices.indexed)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 10, top: 2),
                      child: pw.Text(
                        '${_circled(i)} $ch',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                if (withAnswers) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    '정답: ${card.answer}',
                    style: pw.TextStyle(font: bold, fontSize: 10),
                  ),
                  if (card.explanation.trim().isNotEmpty)
                    pw.Text(
                      '해설: ${card.explanation.trim()}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  if (card.sourceLabel.trim().isNotEmpty)
                    pw.Text(
                      '출처: ${card.sourceLabel.trim()}',
                      style: pw.TextStyle(fontSize: 8, color: grey),
                    ),
                ],
              ],
            ),
          ),
        );
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '$subjectName 족보',
                    style: pw.TextStyle(font: bold, fontSize: 22),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '$scopeLabel · 문제 $cardCount개 · ${_date(createdAt)}',
                    style: pw.TextStyle(fontSize: 10, color: grey),
                  ),
                  pw.Text(
                    notice,
                    style: pw.TextStyle(fontSize: 9, color: grey),
                  ),
                  pw.SizedBox(height: 8),
                ],
              )
            : pw.SizedBox(),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: grey),
          ),
        ),
        build: (_) => body,
      ),
    );
    return doc.save();
  }

  /// 웹은 파일 다운로드, 폰은 공유 창(카톡 등).
  Future<void> sharePdf() async {
    await Printing.sharePdf(bytes: await toPdf(), filename: fileName);
  }

  static String typeLabel(CardType t) => switch (t) {
    CardType.mcq => '객관식',
    CardType.ox => 'OX',
    CardType.short => '단답형',
  };

  static String _meta(ExportCard c) {
    final parts = [
      if (c.author != null && c.author!.isNotEmpty) c.author!,
      if (c.votes != null && c.votes! > 0) '나올 것 같아요 ${c.votes}',
    ];
    return parts.isEmpty ? '' : ' (${parts.join(' · ')})';
  }

  static String _circled(int i) =>
      i < 10 ? String.fromCharCode(0x2460 + i) : '${i + 1})';

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _date(DateTime d) =>
      '${d.year}.${_two(d.month)}.${_two(d.day)}';
}
