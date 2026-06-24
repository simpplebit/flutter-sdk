import 'package:flutter_test/flutter_test.dart';
import 'package:simplebit_flutter/simplebit_flutter.dart';

void main() {
  group('InvoiceStatus.parse', () {
    test('maps known statuses case-insensitively', () {
      expect(InvoiceStatus.parse('PAID'), InvoiceStatus.paid);
      expect(InvoiceStatus.parse('pending'), InvoiceStatus.pending);
      expect(InvoiceStatus.parse('EXPIRED'), InvoiceStatus.expired);
      expect(InvoiceStatus.parse('CANCELLED'), InvoiceStatus.cancelled);
      expect(InvoiceStatus.parse('AUTHORIZED'), InvoiceStatus.authorized);
    });

    test('falls back to unknown', () {
      expect(InvoiceStatus.parse('something'), InvoiceStatus.unknown);
      expect(InvoiceStatus.parse(null), InvoiceStatus.unknown);
    });

    test('isTerminal', () {
      expect(InvoiceStatus.paid.isTerminal, isTrue);
      expect(InvoiceStatus.expired.isTerminal, isTrue);
      expect(InvoiceStatus.cancelled.isTerminal, isTrue);
      expect(InvoiceStatus.pending.isTerminal, isFalse);
      expect(InvoiceStatus.authorized.isTerminal, isFalse);
    });
  });

  group('CreatedInvoice.fromJson', () {
    test('parses the POST /invoices response shape', () {
      final inv = CreatedInvoice.fromJson({
        'id': 'cabc123def456ghi789jkl012',
        'paymentLink': 'aBcD1234Ef',
        'status': 'PENDING',
        'expiresAt': '2026-06-24T10:00:00.000Z',
        'totals': {
          'subtotal': 100,
          'taxesTotal': 5,
          'serviceFee': 0,
          'total': 105
        },
      });
      expect(inv.id, 'cabc123def456ghi789jkl012');
      expect(inv.paymentLink, 'aBcD1234Ef');
      expect(inv.status, InvoiceStatus.pending);
      expect(inv.total, 105.0);
      expect(inv.currency, 'AED');
      expect(inv.expiresAt, isNotNull);
    });
  });

  group('InvoiceStatusResult.fromJson', () {
    test('parses the public-key slim status body', () {
      final r = InvoiceStatusResult.fromJson({
        'id': 'cabc123def456ghi789jkl012',
        'status': 'PAID',
        'amount': 105.0,
        'currency': 'AED',
      });
      expect(r.id, 'cabc123def456ghi789jkl012');
      expect(r.status, InvoiceStatus.paid);
      expect(r.isPaid, isTrue);
      expect(r.amount, 105.0);
    });
  });

  group('SimpleBit URL building', () {
    test('derives checkout host and builds the hosted page URL', () {
      final sb = SimpleBit(
        publishableKey: 'sb_pub_test',
        apiBaseUrl: 'https://pay.simplebit.io/api',
      );
      expect(sb.checkoutUrlFor('aBcD1234Ef').toString(),
          'https://pay.simplebit.io/pay/aBcD1234Ef');
      sb.close();
    });

    test('honours an explicit checkout base', () {
      final sb = SimpleBit(
        publishableKey: 'sb_pub_test',
        apiBaseUrl: 'https://api.simplebit.io/api',
        checkoutBaseUrl: 'https://app.simplebit.io',
      );
      expect(sb.checkoutUrlFor('xyz').toString(),
          'https://app.simplebit.io/pay/xyz');
      sb.close();
    });
  });
}
