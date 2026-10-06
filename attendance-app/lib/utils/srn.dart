/// Mirrors backend/src/utils/srn.js. The barcode value IS the SRN; we only normalise it.
final _srnPattern = RegExp(r'^[A-Z0-9][A-Z0-9\-_/.]{3,29}$');

String normalizeSrn(String raw) => raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();

bool isValidSrn(String normalized) => _srnPattern.hasMatch(normalized);
