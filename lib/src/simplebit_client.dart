import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'simplebit_exception.dart';

/// Client for the SimpleBit API.
///
/// Construct it with a **public** key (`sb_pub_…`), which is safe to embed in a
/// mobile app. A public key can only create invoices and read a single
/// invoice's status — exactly what the checkout flow needs.
///
/// ```dart
/// final sb = SimpleBit(
///   publishableKey: 'sb_pub_xxx',
///   apiBaseUrl: 'https://pay.simplebit.io/api',
/// );
/// ```
class SimpleBit {
  SimpleBit({
    required this.publishableKey,
    required String apiBaseUrl,
    String? checkoutBaseUrl,
    http.Client? httpClient,
  })  : _api = _normalize(apiBaseUrl),
        _checkout =
            _normalize(checkoutBaseUrl ?? _deriveCheckoutBase(apiBaseUrl)),
        _http = httpClient ?? http.Client();

  /// The public (`sb_pub_…`) or secret key used as the bearer token.
  final String publishableKey;

  final Uri _api;
  final Uri _checkout;
  final http.Client _http;

  static Uri _normalize(String base) =>
      Uri.parse(base.endsWith('/') ? base.substring(0, base.length - 1) : base);

  /// If only the API base (`…/api`) is given, the checkout host is the same
  /// origin without the `/api` suffix.
  static String _deriveCheckoutBase(String apiBaseUrl) {
    var b = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    if (b.endsWith('/api')) b = b.substring(0, b.length - '/api'.length);
    return b;
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $publishableKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// The hosted payment page URL for a given [paymentLink].
  Uri checkoutUrlFor(String paymentLink) =>
      Uri.parse('$_checkout/pay/$paymentLink');

  /// Create an invoice and return it (including its [CreatedInvoice.paymentLink]).
  ///
  /// [items] reference existing catalog items on the merchant account.
  Future<CreatedInvoice> createInvoice({
    required List<InvoiceItem> items,
    bool municipalityTax = false,
    bool customerPaysFee = false,
    List<String>? customTaxIds,
    String? customerEmail,
    String? customerName,
    String? customerPhone,
    int? expiresInHours,
  }) async {
    if (items.isEmpty) {
      throw const SimpleBitException(
          'createInvoice requires at least one item');
    }
    final body = <String, dynamic>{
      'items': items.map((i) => i.toJson()).toList(),
      'municipalityTax': municipalityTax,
      'customerPaysFee': customerPaysFee,
      if (customTaxIds != null) 'customTaxIds': customTaxIds,
      if (customerEmail != null) 'customerEmail': customerEmail,
      if (customerName != null) 'customerName': customerName,
      if (customerPhone != null) 'customerPhone': customerPhone,
      if (expiresInHours != null) 'expiresInHours': expiresInHours,
    };
    final json = await _post('/invoices', body);
    return CreatedInvoice.fromJson(json);
  }

  /// Fetch the current status of an invoice by id.
  ///
  /// With a public key the response is reduced to `{ id, status, amount, currency }`.
  Future<InvoiceStatusResult> getInvoiceStatus(String invoiceId) async {
    final json = await _get('/invoices/$invoiceId');
    return InvoiceStatusResult.fromJson(json);
  }

  /// Release the underlying HTTP client. Call when you are done with this
  /// instance (e.g. you created it just for one checkout).
  void close() => _http.close();

  // --- internals -----------------------------------------------------------

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await _http.get(_api.replace(path: '${_api.path}$path'),
        headers: _headers);
    return _decode(res);
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final res = await _http.post(
      _api.replace(path: '${_api.path}$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic>? parsed;
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) parsed = decoded;
      } catch (_) {
        // fall through to error handling below
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (parsed == null) {
        throw SimpleBitException('Unexpected response',
            statusCode: res.statusCode, body: res.body);
      }
      return parsed;
    }
    final message = (parsed?['message'] as String?) ?? 'Request failed';
    throw SimpleBitException(message,
        statusCode: res.statusCode, body: res.body);
  }
}
