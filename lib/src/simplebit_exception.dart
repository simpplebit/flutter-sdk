/// Thrown when a SimpleBit API request fails.
class SimpleBitException implements Exception {
  const SimpleBitException(this.message, {this.statusCode, this.body});

  final String message;

  /// HTTP status code, when the failure came from a response.
  final int? statusCode;

  /// Raw response body, for debugging.
  final String? body;

  @override
  String toString() => statusCode == null
      ? 'SimpleBitException: $message'
      : 'SimpleBitException($statusCode): $message';
}
