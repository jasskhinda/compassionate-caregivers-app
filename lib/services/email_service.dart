import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> sendAssignedVideoEmail({required String recipientEmail, required String videoTitle, required String videoBody, required String type}) async {
  final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
  final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'service_id': 'service_c5xsba6',  // dotenv.env['SERVICE_ID'],
        'template_id': 'template_bc8mupd',  // dotenv.env['TEMPLATE_ID'],
        'user_id': 'srH_HtWKuCGvEwV3w',  // dotenv.env['USER_ID'],
        'template_params': {
          'user_email': recipientEmail,
          'video_body': videoBody,
          'video_title': videoTitle,
          'type': type
        },
      })
  );

  print(response.body);
}