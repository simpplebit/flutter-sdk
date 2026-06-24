import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simplebit_flutter/simplebit_flutter.dart';

void main() {
  group('createInvoice', () {
    test('sends a POST to /api/invoices with auth header and body', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'id': 'cabc123def456ghi789jkl012',
            'paymentLink': 'aBcD1234Ef',
            'status': 'PENDING',
            'totals': {'total': 105},
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final sb = SimpleBit(
        publishableKey: 'sb_pub_test',
        apiBaseUrl: 'https://pay.simplebit.io/api',
        httpClient: mock,
      );

      final inv = await sb.createInvoice(
        items: const [InvoiceItem(itemId: 'itm_1', quantity: 2)],
        customerEmail: 'buyer@example.com',
      );

      expect(captured.method, 'POST');
      expect(captured.url.toString(), 'https://pay.simplebit.io/api/invoices');
      expect(captured.headers['Authorization'], 'Bearer sb_pub_test');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['items'], [
        {'itemId': 'itm_1', 'quantity': 2}
      ]);
      expect(body['municipalityTax'], false);
      expect(body['customerPaysFee'], false);
      expect(body['customerEmail'], 'buyer@example.com');
      // omitted optionals are not sent
      expect(body.containsKey('customerPhone'), isFalse);

      expect(inv.id, 'cabc123def456ghi789jkl012');
      expect(inv.paymentLink, 'aBcD1234Ef');
      expect(inv.total, 105.0);

      sb.close();
    });

    test('throws without items, without hitting the network', () async {
      var called = false;
      final mock = MockClient((req) async {
        called = true;
        return http.Response('{}', 200);
      });
      final sb = SimpleBit(
        publishableKey: 'sb_pub_test',
        apiBaseUrl: 'https://pay.simplebit.io/api',
        httpClient: mock,
      );
      expect(() => sb.createInvoice(items: const []),
          throwsA(isA<SimpleBitException>()));
      expect(called, isFalse);
      sb.close();
    });
  });

  group('getInvoiceStatus', () {
    test('GETs /api/invoices/:id and parses the slim body', () async {
      late Uri url;
      final mock = MockClient((req) async {
        url = req.url;
        return http.Response(
          jsonEncode({
            'id': 'inv_1',
            'status': 'PAID',
            'amount': 105.0,
            'currency': 'AED',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final sb = SimpleBit(
        publishableKey: 'sb_pub_test',
        apiBaseUrl: 'https://pay.simplebit.io/api',
        httpClient: mock,
      );

      final r = await sb.getInvoiceStatus('inv_1');
      expect(url.toString(), 'https://pay.simplebit.io/api/invoices/inv_1');
      expect(r.isPaid, isTrue);
      expect(r.amount, 105.0);
      sb.close();
    });
  });

  group('error mapping', () {
    test('non-2xx becomes a SimpleBitException carrying status + message',
        () async {
      final mock = MockClient((req) async => http.Response(
            jsonEncode({'message': 'This endpoint requires a secret key'}),
            403,
            headers: {'content-type': 'application/json'},
          ));
      final sb = SimpleBit(
        publishableKey: 'sb_pub_test',
        apiBaseUrl: 'https://pay.simplebit.io/api',
        httpClient: mock,
      );

      try {
        await sb.getInvoiceStatus('inv_1');
        fail('expected SimpleBitException');
      } on SimpleBitException catch (e) {
        expect(e.statusCode, 403);
        expect(e.message, 'This endpoint requires a secret key');
      }
      sb.close();
    });
  });
}
