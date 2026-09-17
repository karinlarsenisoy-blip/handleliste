import 'dart:async';

import 'package:flutter/material.dart';

import '../models/product_suggestion.dart';
import '../services/product_suggestion_service.dart';

/// A text field for typing a product/item name that shows a dropdown of
/// known products (with photos) as you type — e.g. typing "melk" lists the
/// milk variants known to Open Food Facts. Picking one fills the field with
/// its name; you can otherwise just keep typing free text and ignore it.
typedef ProductNameSubmitted = void Function(String name, {String? imageUrl});

class ProductNameField extends StatefulWidget {
  const ProductNameField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onSubmitted,
    this.suggestionService,
  });

  final TextEditingController controller;
  final String hintText;

  /// Called with the entered/picked name, and — only when the user picked a
  /// suggestion rather than typing free text — its photo.
  final ProductNameSubmitted onSubmitted;
  final ProductSuggestionService? suggestionService;

  @override
  State<ProductNameField> createState() => _ProductNameFieldState();
}

class _ProductNameFieldState extends State<ProductNameField> {
  late final ProductSuggestionService _service = widget.suggestionService ?? ProductSuggestionService();
  Timer? _debounce;
  List<ProductSuggestion> _suggestions = [];
  bool _isLoading = false;

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isLoading = true);
      final results = await _service.search(text.trim());
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
    });
  }

  void _selectSuggestion(ProductSuggestion suggestion) {
    widget.controller.text = suggestion.name;
    setState(() => _suggestions = []);
    widget.onSubmitted(suggestion.name, imageUrl: suggestion.imageUrl);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(hintText: widget.hintText),
          onChanged: _onChanged,
          onSubmitted: (value) {
            setState(() => _suggestions = []);
            widget.onSubmitted(value);
          },
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: suggestion.imageUrl == null
                      ? const CircleAvatar(child: Icon(Icons.shopping_basket_outlined, size: 18))
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            suggestion.imageUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.shopping_basket_outlined),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return SizedBox(
                                width: 40,
                                height: 40,
                                child: Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                  title: Text(suggestion.name),
                  subtitle: [
                    if (suggestion.brand != null) suggestion.brand!,
                    if (suggestion.quantity != null) suggestion.quantity!,
                  ].isEmpty
                      ? null
                      : Text([
                          if (suggestion.brand != null) suggestion.brand!,
                          if (suggestion.quantity != null) suggestion.quantity!,
                        ].join(' · ')),
                  trailing: suggestion.price == null
                      ? null
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${suggestion.price!.toStringAsFixed(2)} kr',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (suggestion.storeName != null)
                              Text(suggestion.storeName!, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}
