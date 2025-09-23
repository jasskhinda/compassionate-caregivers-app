// Stub implementation for non-web platforms
import 'dart:typed_data';

void downloadWebPdf(Uint8List bytes, String fileName) {
  throw UnsupportedError('Web download is not supported on this platform');
}