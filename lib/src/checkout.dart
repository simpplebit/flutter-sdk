import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'models.dart';
import 'simplebit_client.dart';

/// Drop-in hosted checkout.
///
/// Opens the SimpleBit payment page for an invoice inside an in-app WebView and
/// resolves once the invoice reaches a terminal state (paid / expired /
/// cancelled) or the buyer dismisses the screen.
///
/// Completion is detected by polling the invoice status with the same public
/// key — the hosted page is shown as-is, untouched.
///
/// ```dart
/// final invoice = await sb.createInvoice(items: [InvoiceItem(itemId: 'itm_1')]);
/// final result = await SimpleBitCheckout.present(
///   context,
///   client: sb,
///   invoice: invoice,
/// );
/// if (result.isPaid) { /* fulfil order */ }
/// ```
class SimpleBitCheckout {
  const SimpleBitCheckout._();

  static Future<PaymentResult> present(
    BuildContext context, {
    required SimpleBit client,
    required CreatedInvoice invoice,
    String title = 'Checkout',
    Duration pollInterval = const Duration(seconds: 3),
  }) async {
    final result = await Navigator.of(context).push<PaymentResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CheckoutScreen(
          client: client,
          invoice: invoice,
          title: title,
          pollInterval: pollInterval,
        ),
      ),
    );
    return result ??
        PaymentResult(
            outcome: CheckoutOutcome.dismissed, invoiceId: invoice.id);
  }
}

class _CheckoutScreen extends StatefulWidget {
  const _CheckoutScreen({
    required this.client,
    required this.invoice,
    required this.title,
    required this.pollInterval,
  });

  final SimpleBit client;
  final CreatedInvoice invoice;
  final String title;
  final Duration pollInterval;

  @override
  State<_CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<_CheckoutScreen> {
  late final WebViewController _controller;
  Timer? _timer;
  bool _loading = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(widget.client.checkoutUrlFor(widget.invoice.paymentLink));

    _timer = Timer.periodic(widget.pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_finished) return;
    try {
      final status = await widget.client.getInvoiceStatus(widget.invoice.id);
      if (status.status.isTerminal) {
        _complete(_outcomeFor(status.status), status.status);
      }
    } catch (_) {
      // Ignore transient errors; the next tick retries.
    }
  }

  CheckoutOutcome _outcomeFor(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.paid:
        return CheckoutOutcome.paid;
      case InvoiceStatus.expired:
        return CheckoutOutcome.expired;
      case InvoiceStatus.cancelled:
        return CheckoutOutcome.cancelled;
      default:
        return CheckoutOutcome.dismissed;
    }
  }

  void _complete(CheckoutOutcome outcome, InvoiceStatus status) {
    if (_finished || !mounted) return;
    _finished = true;
    _timer?.cancel();
    Navigator.of(context).pop(
      PaymentResult(
          outcome: outcome, invoiceId: widget.invoice.id, status: status),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _dismiss() {
    if (_finished || !mounted) return;
    _finished = true;
    _timer?.cancel();
    Navigator.of(context).pop(
      PaymentResult(
          outcome: CheckoutOutcome.dismissed, invoiceId: widget.invoice.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _dismiss,
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
