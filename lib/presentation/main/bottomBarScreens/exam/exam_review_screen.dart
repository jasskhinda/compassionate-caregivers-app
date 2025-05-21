import 'dart:io' as io;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:healthcare/utils/app_utils/AppUtils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;

class ExamReviewScreen extends StatefulWidget {
  final String examId;
  final String userId;

  const ExamReviewScreen({
    Key? key,
    required this.examId,
    required this.userId,
  }) : super(key: key);

  @override
  State<ExamReviewScreen> createState() => _ExamReviewScreenState();
}

class _ExamReviewScreenState extends State<ExamReviewScreen> {
  Map<String, dynamic>? examData;
  Map<String, dynamic> selectedAnswers = {};
  bool isLoading = true;
  List<Map<String, dynamic>> allQuestions = [];

  @override
  void initState() {
    super.initState();
    fetchExamSubmission();
  }

  Future<void> fetchExamSubmission() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .collection('exams')
          .doc(widget.examId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final items = data['items'] as List<dynamic>? ?? [];

        final List<Map<String, dynamic>> questionList = [];
        Map<String, dynamic> selectedOption = data['selectedOption'] as Map<String, dynamic>? ?? {};

        for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
          final item = items[itemIndex];
          final questions = item['questions'] as List<dynamic>? ?? [];
          for (int questionIndex = 0; questionIndex < questions.length; questionIndex++) {
            final q = questions[questionIndex];
            if (q is Map<String, dynamic>) {
              q['indexKey'] = '${itemIndex}_${questionIndex}';
              questionList.add(q);
            }
          }
        }

        setState(() {
          examData = data;
          allQuestions = questionList;
          selectedAnswers = selectedOption;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No submission found for this exam.')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    }
  }

  Future<pw.Document> generatePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text('Exam Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Text('Exam Title: ${examData?['examTitle'] ?? 'N/A'}', style: const pw.TextStyle(fontSize: 18)),
          pw.Text('Grade: ${examData?['score'] ?? 'N/A'}', style: const pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 20),

          pw.Column(
            children: List.generate(allQuestions.length, (index) {
              final question = allQuestions[index];
              final questionText = question['questionTitle'] ?? '';
              final options = question['options'] as List<dynamic>? ?? [];
              final indexKey = question['indexKey'] ?? '';
              final userAnswerRaw = selectedAnswers[indexKey];
              final userAnswers = userAnswerRaw is List ? userAnswerRaw.cast<String>() : [userAnswerRaw?.toString()];
              final correctAnswersRaw = question['correctAnswers'] ?? [];
              final correctAnswers = correctAnswersRaw is List ? correctAnswersRaw.cast<String>() : [correctAnswersRaw?.toString()];

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Q${index + 1}: $questionText', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: List.generate(options.length, (optIndex) {
                      final optionText = options[optIndex];
                      final isCorrect = correctAnswers.contains(optionText);
                      final isSelected = userAnswers.contains(optionText);

                      pw.TextStyle style;
                      if (isCorrect) {
                        style = pw.TextStyle(color: PdfColors.black, fontWeight: pw.FontWeight.bold);
                      } else if (isSelected && !isCorrect) {
                        style = pw.TextStyle(color: PdfColors.black, fontWeight: pw.FontWeight.bold);
                      } else {
                        style = const pw.TextStyle();
                      }

                      return pw.Text(
                        'Option ${optIndex + 1}: $optionText',
                        style: style,
                      );
                    }),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('User Input: ${userAnswers.join(', ')}'),
                  pw.Text('Correct Answer: ${correctAnswers.join(', ')}'),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                ],
              );
            }),
          ),
        ],
      ),
    );

    return pdf;
  }

  Future<void> downloadPdf() async {
    if (examData == null) return;

    final pdf = await generatePdf();
    final bytes = await pdf.save();
    final fileName = 'ExamReport_${widget.examId}.pdf';

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      return;
    }

    if (io.Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to save PDF')),
        );
        return;
      }
    }

    final dir = io.Platform.isAndroid
        ? io.Directory('/storage/emulated/0/Download')
        : await getApplicationDocumentsDirectory();

    if (!await dir.exists()) await dir.create(recursive: true);

    final file = io.File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF saved to ${file.path}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Exam Report'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : examData == null
          ? const Center(child: Text('No exam submission found.'))
          : Center(
        child: ElevatedButton.icon(
          onPressed: downloadPdf,
          icon: const Icon(Icons.download),
          label: const Text('Download PDF Report'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppUtils.getColorScheme(context).tertiaryContainer, // Button background color
            foregroundColor: Colors.white, // Text and icon color
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // optional
            textStyle: const TextStyle(fontSize: 16), // optional
          ),
        ),
      ),
    );
  }
}