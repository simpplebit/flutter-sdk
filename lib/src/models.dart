/// Lifecycle status of an invoice, mirroring the SimpleBit backend.
enum InvoiceStatus {
  pending,
  authorized,
  paid,
  expired,
  cancelled,
  unknown;

  /// Parse the server's uppercase status string (e.g. `"PAID"`).
  static InvoiceStatus parse(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'PENDING':
        return InvoiceStatus.pending;
      case 'AUTHORIZED':
        return InvoiceStatus.authorized;
      case 'PAID':
        return InvoiceStatus.paid;
      case 'EXPIRED':
        return InvoiceStatus.expired;
      case 'CANCELLED':
        return InvoiceStatus.cancelled;
      default:
        return InvoiceStatus.unknown;
    }
  }

  /// Whether this status is final (no further payment expected).
  bool get isTerminal =>
      this == InvoiceStatus.paid ||
      this == InvoiceStatus.expired ||
      this == InvoiceStatus.cancelled;
}

/// A single line item when creating an invoice.
///
/// [itemId] references a catalog item that already exists on the merchant
/// account; [quantity] must be at least 1.
class InvoiceItem {
  const InvoiceItem({required this.itemId, this.quantity = 1});

  final String itemId;
  final int quantity;

  Map<String, dynamic> toJson() => {'itemId': itemId, 'quantity': quantity};
}

/// An invoice returned from [SimpleBit.createInvoice].
class CreatedInvoice {
  const CreatedInvoice({
    required this.id,
    required this.paymentLink,
    required this.status,
    required this.total,
    required this.currency,
    this.expiresAt,
    required this.raw,
  });

  /// Invoice id — use it with [SimpleBit.getInvoiceStatus].
  final String id;

  /// Opaque token identifying the hosted payment page (`/pay/<paymentLink>`).
  final String paymentLink;

  final InvoiceStatus status;

  /// Total amount payable.
  final double total;

  /// ISO currency, always `AED` today.
  final String currency;

  final DateTime? expiresAt;

  /// The full decoded JSON body, for fields not surfaced as typed getters.
  final Map<String, dynamic> raw;

  factory CreatedInvoice.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'];
    final total =
        totals is Map<String, dynamic> ? totals['total'] : json['amount'];
    final expires = json['expiresAt'];
    return CreatedInvoice(
      id: json['id'] as String,
      paymentLink: json['paymentLink'] as String,
      status: InvoiceStatus.parse(json['status'] as String?),
      total: (total as num?)?.toDouble() ?? 0,
      currency: (json['currency'] as String?) ?? 'AED',
      expiresAt: expires is String ? DateTime.tryParse(expires) : null,
      raw: json,
    );
  }
}

/// The minimal, PII-free status view returned for a public key from
/// `GET /invoices/:id`.
class InvoiceStatusResult {
  const InvoiceStatusResult({
    required this.id,
    required this.status,
    required this.amount,
    required this.currency,
  });

  final String id;
  final InvoiceStatus status;
  final double amount;
  final String currency;

  bool get isPaid => status == InvoiceStatus.paid;

  factory InvoiceStatusResult.fromJson(Map<String, dynamic> json) {
    return InvoiceStatusResult(
      id: json['id'] as String,
      status: InvoiceStatus.parse(json['status'] as String?),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] as String?) ?? 'AED',
    );
  }
}

/// How a checkout flow ended.
enum CheckoutOutcome {
  /// The invoice was fully paid.
  paid,

  /// The invoice expired before being paid.
  expired,

  /// The invoice was cancelled.
  cancelled,

  /// The buyer dismissed the checkout screen without completing payment.
  dismissed,
}

/// Result of [SimpleBitCheckout.present].
class PaymentResult {
  const PaymentResult({
    required this.outcome,
    required this.invoiceId,
    this.status,
  });

  final CheckoutOutcome outcome;
  final String invoiceId;

  /// The last known invoice status, when available.
  final InvoiceStatus? status;

  bool get isPaid => outcome == CheckoutOutcome.paid;
}
