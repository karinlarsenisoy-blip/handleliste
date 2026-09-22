import '../models/receipt_item.dart';
import '../models/store.dart';

/// Best-effort line-item parser for raw receipt text — whether that text
/// came from OCR on a photographed receipt, or was pasted in by hand (e.g.
/// copied out of a store app that has no receipt photo, just a scrolling
/// purchase list). Both sources feed the same parser, since once it's text
/// the format problem is the same: find `name ... price` per line.
///
/// Receipt layouts vary a lot between chains and printers, so this is
/// deliberately simple and imperfect — its output is always shown to the
/// user for review/correction before a receipt is saved, never trusted
/// blindly.
class ReceiptParser {
  static final RegExp _trailingPrice = RegExp(
    r'(-?\d+(?:[.,]\d{1,2})?)\s*(?:kr|,-)?\s*$',
    caseSensitive: false,
  );
  static final RegExp _quantityOnly = RegExp(r'^\d+([.,]\d+)?\s*(stk|kg|x)\b', caseSensitive: false);

  static const List<String> _skipKeywords = [
    'SUM',
    'TOTAL',
    'TOTALT',
    'MVA',
    'KONTANT',
    'BANKAXEPT',
    'KORTKJØP',
    'VIPPS',
    'KVITTERING',
    'ORG.NR',
    'ORGNR',
    'KASSERER',
    'BUTIKK NR',
    'TAKK FOR',
    'TERMINAL',
    'KASSE ',
  ];

  /// Guesses which known chain a receipt is from by looking for its name
  /// printed literally in the text — real receipts (photographed or
  /// exported from a store's own app) almost always print the chain's name
  /// near the top ("KIWI STORGATA", "COOP EXTRA X", ...), so the user
  /// shouldn't have to tell the app something it can just read. Returns
  /// null (never "Annet") when nothing matches, so the caller can fall back
  /// to whatever was already selected rather than guessing wrong — this is
  /// a convenience default, not something to trust blindly, which is why
  /// the store picker stays visible and editable regardless.
  static Store? detectStore(String rawText) {
    final upperText = rawText.toUpperCase();
    for (final store in knownStores) {
      if (store.id == 'annet') continue;
      if (upperText.contains(store.name.toUpperCase())) return store;
    }
    return null;
  }

  /// Parses [rawText] into a best-effort list of purchased items.
  static List<ReceiptItem> parse(String rawText) {
    final items = <ReceiptItem>[];
    String? pendingName;

    for (final rawLine in rawText.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final upper = line.toUpperCase();
      if (_skipKeywords.any(upper.contains)) continue;

      final match = _trailingPrice.firstMatch(line);
      if (match == null) {
        // No price on this line — remember it in case the *next* line is
        // just "<qty> stk x <price>" with the product name on the line above.
        pendingName = line;
        continue;
      }

      final price = num.tryParse(match.group(1)!.replaceAll(',', '.'));
      if (price == null) continue;
      // A negative trailing amount is a discount or a bottle-deposit refund
      // (e.g. "Rabatt -5,00", "Pant -2,00") — not a purchasable item, so it
      // shouldn't become a fake line item worth +5,00 kr.
      if (price < 0) {
        pendingName = null;
        continue;
      }

      var name = line.substring(0, match.start).trim();
      if (name.isEmpty || _quantityOnly.hasMatch(name)) {
        name = pendingName ?? name;
      }
      pendingName = null;

      if (name.isEmpty) continue;
      items.add(ReceiptItem(name: name, price: price));
    }

    return items;
  }
}
