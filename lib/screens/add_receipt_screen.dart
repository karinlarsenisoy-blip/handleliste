import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/price_observation.dart';
import '../models/receipt.dart';
import '../models/receipt_item.dart';
import '../models/store.dart';
import '../services/ocr_service.dart';
import '../services/price_service.dart';
import '../services/receipt_parser.dart';
import '../services/receipt_service.dart';
import '../widgets/product_name_field.dart';

/// Captures one receipt: pick a store and date, then get the raw text in
/// either by pasting it (works everywhere — used for stores with no real
/// receipt, just a scrolling purchase list you copy) or by photographing a
/// physical/app receipt and running on-device OCR (Android/iOS only). Both
/// paths feed the same [ReceiptParser] and the same editable review list —
/// the parser is a best guess, never trusted blindly.
///
/// Saving always keeps the receipt in the user's own private history.
/// Whether its prices also get contributed anonymously to the shared price
/// database is the user's explicit, per-receipt choice (see [_shareAnonymously]).
class AddReceiptScreen extends StatefulWidget {
  AddReceiptScreen({
    super.key,
    required this.uid,
    required this.receiptService,
    PriceService? priceService,
  }) : priceService = priceService ?? PriceService();

  final String uid;
  final ReceiptService receiptService;
  final PriceService priceService;

  @override
  State<AddReceiptScreen> createState() => _AddReceiptScreenState();
}

class _EditableItem {
  _EditableItem({required String name, required num price, num quantity = 1})
      : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: _formatNumber(price)),
        quantityController = TextEditingController(text: _formatNumber(quantity));

  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController quantityController;

  static String _formatNumber(num value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    quantityController.dispose();
  }
}

class _AddReceiptScreenState extends State<AddReceiptScreen> {
  final TextEditingController _rawTextController = TextEditingController();
  Store _store = knownStores.first;
  DateTime _purchasedAt = DateTime.now();
  final List<_EditableItem> _items = [];
  bool _isSaving = false;
  bool _isScanning = false;
  bool _shareAnonymously = true;
  ReceiptSource _source = ReceiptSource.pastedText;
  final ImagePicker _imagePicker = ImagePicker();
  final OcrService _ocrService = OcrService();

  @override
  void dispose() {
    _rawTextController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _parseText() {
    final parsed = ReceiptParser.parse(_rawTextController.text);
    setState(() {
      for (final item in _items) {
        item.dispose();
      }
      _items
        ..clear()
        ..addAll(parsed.map((i) => _EditableItem(name: i.name, price: i.price, quantity: i.quantity)));
    });
    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fant ingen varelinjer — legg til varer manuelt under.')),
      );
    }
  }

  Future<void> _scanReceiptPhoto(ImageSource source) async {
    final photo = await _imagePicker.pickImage(source: source, imageQuality: 90);
    if (photo == null || !mounted) return;

    setState(() => _isScanning = true);
    try {
      final text = await _ocrService.recognizeText(photo.path);
      _rawTextController.text = text;
      _source = ReceiptSource.photo;
      _parseText();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Klarte ikke å lese kvitteringen: $e')));
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _addEmptyRow() {
    setState(() => _items.add(_EditableItem(name: '', price: 0)));
  }

  void _removeRow(int index) {
    setState(() => _items.removeAt(index).dispose());
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchasedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _purchasedAt = picked);
  }

  num get _total => _items.fold<num>(
        0,
        (accumulated, i) => accumulated + (num.tryParse(i.priceController.text.replaceAll(',', '.')) ?? 0),
      );

  Future<void> _save() async {
    final items = <ReceiptItem>[];
    for (final item in _items) {
      final name = item.nameController.text.trim();
      final price = num.tryParse(item.priceController.text.replaceAll(',', '.'));
      final quantity = num.tryParse(item.quantityController.text.replaceAll(',', '.')) ?? 1;
      if (name.isEmpty || price == null || quantity <= 0) continue;
      items.add(ReceiptItem(name: name, price: price, quantity: quantity));
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Legg til minst én vare med navn og pris først.')));
      return;
    }

    setState(() => _isSaving = true);
    final receipt = Receipt(
      id: '',
      storeId: _store.id,
      storeName: _store.name,
      purchasedAt: _purchasedAt,
      source: _source,
      items: items,
      rawText: _rawTextController.text.trim().isEmpty ? null : _rawTextController.text.trim(),
    );
    await widget.receiptService.addReceipt(widget.uid, receipt);

    if (_shareAnonymously) {
      for (final item in items) {
        // The price on a receipt line is the total for that line, not a
        // per-unit price — dividing by quantity here is what keeps the
        // shared price database meaningful (a "3 for 30 kr" line must not
        // be recorded as a single item costing 30 kr).
        await widget.priceService.contributeObservation(
          PriceObservation(
            storeChainId: _store.id,
            itemName: item.name,
            price: item.price / item.quantity,
            observedAt: _purchasedAt,
          ),
        );
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ny kvittering')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<Store>(
                  initialValue: _store,
                  decoration: const InputDecoration(labelText: 'Butikk'),
                  items: knownStores
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                      .toList(),
                  onChanged: (value) => setState(() => _store = value ?? _store),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _pickDate,
                child: Text('${_purchasedAt.day}.${_purchasedAt.month}.${_purchasedAt.year}'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (OcrService.isSupported) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isScanning ? null : () => _scanReceiptPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Ta bilde av kvittering'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isScanning ? null : () => _scanReceiptPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Velg bilde'),
                  ),
                ),
              ],
            ),
            if (_isScanning) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Leser kvitteringen...'),
                ],
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('eller')),
                  Expanded(child: Divider()),
                ],
              ),
            ),
          ],
          TextField(
            controller: _rawTextController,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Lim inn tekst fra kvitteringen eller kjøpslisten',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                _source = ReceiptSource.pastedText;
                _parseText();
              },
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Tolk tekst'),
            ),
          ),
          const Divider(height: 32),
          Text('Varer (${_items.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < _items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: ProductNameField(
                      controller: _items[i].nameController,
                      hintText: 'Varenavn',
                      onSubmitted: (_, {imageUrl}) {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _items[i].quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: 'Antall'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _items[i].priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: 'Pris totalt'),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => _removeRow(i)),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addEmptyRow,
              icon: const Icon(Icons.add),
              label: const Text('Legg til vare'),
            ),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Totalt', style: Theme.of(context).textTheme.titleMedium),
              Text('${_total.toStringAsFixed(2)} kr', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _shareAnonymously,
            onChanged: (value) => setState(() => _shareAnonymously = value),
            title: const Text('Del prisene anonymt'),
            subtitle: const Text(
              'Vare og pris (ikke hvem du er) blir synlig for alle i prisoversikten.',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Lagre kvittering'),
          ),
        ],
      ),
    );
  }
}
