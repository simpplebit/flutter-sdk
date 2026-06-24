import 'package:flutter/material.dart';
import 'package:simplebit_flutter/simplebit_flutter.dart';

// Replace with your public key and host.
const _publicKey = 'sb_pub_xxxxxxxxxxxxxxxxxxxx';
const _apiBaseUrl = 'https://pay.simplebit.io/api';
const _itemId = 'itm_123';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SimpleBit Example',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const CheckoutDemo(),
    );
  }
}

class CheckoutDemo extends StatefulWidget {
  const CheckoutDemo({super.key});

  @override
  State<CheckoutDemo> createState() => _CheckoutDemoState();
}

class _CheckoutDemoState extends State<CheckoutDemo> {
  final _sb = SimpleBit(publishableKey: _publicKey, apiBaseUrl: _apiBaseUrl);
  String _status = 'Tap to pay';
  bool _busy = false;

  Future<void> _checkout() async {
    setState(() {
      _busy = true;
      _status = 'Creating invoice…';
    });
    try {
      final invoice = await _sb.createInvoice(
        items: const [InvoiceItem(itemId: _itemId)],
        customerPaysFee: false,
      );
      if (!mounted) return;
      final result = await SimpleBitCheckout.present(
        context,
        client: _sb,
        invoice: invoice,
      );
      setState(() => _status = result.isPaid
          ? 'Paid ✅ (${invoice.total} ${invoice.currency})'
          : 'Outcome: ${result.outcome.name}');
    } on SimpleBitException catch (e) {
      setState(() => _status = 'Error: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _sb.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SimpleBit Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _checkout,
              child: const Text('Pay now'),
            ),
          ],
        ),
      ),
    );
  }
}
