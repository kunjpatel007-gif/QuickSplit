import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class IntentUtils {
  /// Launches a UPI payment intent.
  static Future<void> launchUpi(BuildContext context, String upiId, String name, double amount) async {
    final url = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': upiId,
        'pn': name,
        'am': amount.toStringAsFixed(2),
        'cu': 'INR',
      },
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No UPI app found. Please install Google Pay, PhonePe, or Paytm.')),
        );
      }
    }
  }

  /// Launches WhatsApp to send a reminder.
  static Future<void> launchWhatsApp(BuildContext context, String phone, double amount) async {
    final message = Uri.encodeComponent(
      'Hey! You owe me ₹${amount.toStringAsFixed(2)} for our shared expenses on Campus QuickSplit.',
    );
    final url = Uri.parse('https://wa.me/$phone?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp.')),
        );
      }
    }
  }
}
