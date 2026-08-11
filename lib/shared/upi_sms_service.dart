// ignore_for_file: dead_code

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telephony/telephony.dart';

class UpiSmsService {
  static const List<String> _upiSenders = [
    'GPAY',
    'PHONEPE',
    'PHNPE',
    'PAYTM',
    'PYTM',
    'AMAZONPAY',
    'AMZPAY',
    'BHIM',
    'AXIS',
    'AXISBK',
    'HDFC',
    'HDFCBK',
    'ICICI',
    'ICICIB',
    'ICICIBNK',
    'SBI',
    'SBIINB',
    'SBIPSG',
    'IPPB',
    'INDPST',
    'KOTAK',
    'KOTAKBK',
    'YESBNK',
    'YESBK',
    'INDUSIND',
    'INDUSB',
    'FEDERAL',
    'FEDBNK',
    'IDFCFIRST',
    'IDFCBK',
    'AUBANK',
    'AUBK',
    'CANBNK',
    'CANARA',
    'PNBSMS',
    'PNBREM',
    'BOISMS',
    'BOISMSB',
    'UNIONBK',
    'UBISMS',
    'CENTBK',
    'CBSSMS',
    'IDBI',
    'IDBIBK',
    'RBL',
    'RBLBNK',
    'DCBBNK',
    'KVBBNK',
    'TMBBNK',
    'JKBBNK',
    'BARODA',
    'BARODISMS',
  ];

  static double? parseAmount(String message) {
    final patterns = [
      RegExp(
        r'debited (?:by |for |with )?(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?) (?:debited|deducted|spent|paid)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:paid|sent|transferred) (?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:payment|txn|transaction) of (?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:Rs\.?|INR|₹)\.?\s*([0-9,]+(?:\.[0-9]{1,2})?) (?:has been |is )?(?:debited|deducted)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:INR|Rs\.?|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)(?:\s+(?:has been\s+)?(?:debited|deducted|paid|sent))',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:amount|amt)[:\s]+(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'debit of (?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final amountText = match.group(1)?.replaceAll(',', '');
        if (amountText != null) {
          final amount = double.tryParse(amountText);
          if (amount != null && amount > 0) return amount;
        }
      }
    }
    return null;
  }

  static String? parseSender(String sender) {
    final upperSender = sender
        .toUpperCase()
        .replaceAll('-', '')
        .replaceAll('.', '');
    for (final candidate in _upiSenders) {
      if (upperSender.contains(candidate)) return candidate;
    }
    return null;
  }

  static bool isUpiDebitMessage(String message, String sender) {
    if (parseSender(sender) == null) return false;

    final lowerMessage = message.toLowerCase();

    const debitKeywords = [
      'debited',
      'deducted',
      'paid',
      'sent',
      'payment of',
      'debit of',
      'amount debited',
      'withdrawn',
    ];
    const creditKeywords = [
      'credited',
      'received',
      'credit',
      'added to',
      'deposited',
    ];

    final hasDebitKeyword = debitKeywords.any((k) => lowerMessage.contains(k));
    final hasCreditKeyword =
        creditKeywords.any((k) => lowerMessage.contains(k));

    return hasDebitKeyword && !hasCreditKeyword;
  }

  // Scans SMS inbox for recent UPI transactions (last 24 hours)
  // Call this when the expense screen opens
  static Future<void> scanRecentSms(
    Function(double amount, String sender) onUpiDetected,
  ) async {
    try {
      final telephony = Telephony.instance;
      final hasPermission = await telephony.requestSmsPermissions ?? false;
      if (!hasPermission) return;

      final cutoff = DateTime.now()
          .subtract(const Duration(hours: 24))
          .millisecondsSinceEpoch
          .toString();

      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
        filter: SmsFilter.where(SmsColumn.DATE).greaterThan(cutoff),
      );

      final Set<String> processedKeys = {};

      for (final sms in messages) {
        final body = sms.body ?? '';
        final sender = sms.address ?? '';

        if (!isUpiDebitMessage(body, sender)) continue;

        final amount = parseAmount(body);
        final parsedSender = parseSender(sender);

        if (amount == null || amount <= 0) continue;

        // Deduplicate by amount + sender
        final key = '${amount.toStringAsFixed(0)}_$parsedSender';
        if (processedKeys.contains(key)) continue;
        processedKeys.add(key);

        onUpiDetected(amount, parsedSender ?? 'UPI');
      }
    } catch (e) {
      // Silent fail — UPI scanning is a bonus feature
    }
  }

  // Listens for incoming SMS while app is open
  static Future<void> initialize(
    BuildContext context,
    Function(double amount, String sender) onUpiDetected,
  ) async {
    final telephony = Telephony.instance;
    final hasPermission = await telephony.requestSmsPermissions ?? false;
    if (!hasPermission) return;

    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        final body = message.body ?? '';
        final sender = message.address ?? '';

        if (!isUpiDebitMessage(body, sender)) return;

        final amount = parseAmount(body);
        final parsedSender = parseSender(sender);

        if (amount != null && amount > 0) {
          onUpiDetected(amount, parsedSender ?? 'UPI');
        }
      },
      listenInBackground: false,
    );
  }
}

final upiSmsServiceProvider = Provider((ref) => UpiSmsService());