import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/stripe_config.dart';

class StripeServices {
  static const Map<String, String> _testTokens = {
    '1234562532685216': 'tok_visa',
    '2563485926154325': 'tok_visa_debit',
    '4856256425875152': 'tok_mastercard',
    '2563485795123654': 'tok_master_debit',
    '5632549587512456': 'tok_chargeDeclined', 
    '2565257962514879': 'tok_chargeDeclineInsufficientFunds',
  };

  static Future<Map<String, dynamic>> processPayment({
    required double amount,
    required String cardNumber,
    required String expMonth,
    required String expYear,
    required String cvc,
  }) async {
   
    final cleanCard = cardNumber.replaceAll(' ', '');
    final token = _testTokens[cleanCard];

    if (token == null) {
      return <String, dynamic>{
        'success': false,
        'error': 'Unknown test card. Please use a valid test card number.'
      };
    }

    
    if (token.contains('Decline')) {
      return <String, dynamic>{
        'success': false,
        'error': 'This card was declined by the provider.'
      };
    }

    final amountInCentavos = (amount * 100).round().toString();

    // 🧪 SANDBOX MODE: Skip HTTP if no backend (apiUrl empty)
    if (StripeConfig.apiUrl.isEmpty) {
      return {
        'success': true,
        'id': 'pi_test_${DateTime.now().millisecondsSinceEpoch}',
        'amount': amount,
        'status': 'succeeded (sandbox)',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('${StripeConfig.apiUrl}/payment_intents'),
        headers: <String, String>{
          'Authorization': 'Bearer ${StripeConfig.secretKey}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: <String, String>{
          'amount': amountInCentavos,
          'currency': 'php',
          'payment_method_data[type]': 'card',
          'payment_method_data[card][token]': token,
          'confirm': 'true', 
          'off_session': 'true', 
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && (data['status'] == 'succeeded')) {
        final paidAmount = (data['amount'] as num) / 100;
        return <String, dynamic>{
          'success': true,
          'id': data['id'].toString(),
          'amount': paidAmount,
          'status': data['status'].toString(),
        };
      } else {
        String errorMsg = 'Payment failed';
        if (data['error'] != null) {
          errorMsg = data['error']['message'] ?? 'Payment failed';
        }
        return <String, dynamic>{
          'success': false,
          'error': errorMsg,
        };
      }
    } catch (e) {
      return <String, dynamic>{
        'success': false,
        'error': 'Connection error: ${e.toString()}',
      };
    }
  }
}
