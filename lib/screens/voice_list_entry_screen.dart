import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/shopping_list.dart';
import '../services/item_service.dart';
import '../services/list_service.dart';
import '../widgets/list_picker.dart';

/// Builds up a shopping list by speaking item names one at a time, with a
/// pause between each — deliberately not "say a whole sentence and parse
/// out the items", which is much harder to get right reliably. Each
/// recognized phrase becomes an editable candidate the user can fix or
/// remove before anything is actually saved.
///
/// Uses the Web Speech API on web (via the speech_to_text package) — only
/// Chrome and Edge expose that to the browser; Safari and Firefox don't
/// support it at all, so this may simply report itself unavailable there.
class VoiceListEntryScreen extends StatefulWidget {
  VoiceListEntryScreen({
    super.key,
    required this.uid,
    ListService? listService,
    ItemService? itemService,
  })  : listService = listService ?? ListService(),
        itemService = itemService ?? ItemService();

  final String uid;
  final ListService listService;
  final ItemService itemService;

  @override
  State<VoiceListEntryScreen> createState() => _VoiceListEntryScreenState();
}

class _VoiceListEntryScreenState extends State<VoiceListEntryScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final List<TextEditingController> _candidates = [];
  ShoppingList? _list;
  bool _speechInitialized = false;
  bool _isListening = false;
  bool _pickingList = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickListAndPrepare());
  }

  @override
  void dispose() {
    _speech.stop();
    for (final controller in _candidates) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickListAndPrepare() async {
    final lists = await widget.listService.watchLists(widget.uid).first;
    if (!mounted) return;
    if (lists.isEmpty) {
      setState(() {
        _pickingList = false;
        _errorMessage = 'Du har ingen lister ennå — lag en først.';
      });
      return;
    }

    final list = await pickList(context, lists, title: 'Si varenavn til hvilken liste?');
    if (!mounted) return;
    if (list == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _list = list;
      _pickingList = false;
    });
  }

  void _onStatus(String status) {
    if ((status == 'done' || status == 'notListening') && _isListening) {
      // The recognizer stops itself after each pause — immediately start a
      // fresh session so the next spoken item gets its own clean result,
      // rather than trying to segment one long continuous recording.
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_isListening && mounted) _listenOnce();
      });
    }
  }

  void _onError(dynamic error) {
    if (mounted) setState(() => _errorMessage = 'Klarte ikke å høre deg akkurat nå — prøv igjen.');
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!result.finalResult) return;
    final words = result.recognizedWords.trim();
    if (words.isEmpty) return;
    setState(() => _candidates.add(TextEditingController(text: words)));
  }

  void _listenOnce() {
    _speech.listen(
      onResult: _onResult,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 2),
        listenFor: const Duration(seconds: 10),
        localeId: 'nb-NO',
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      setState(() => _isListening = false);
      await _speech.stop();
      return;
    }

    if (!_speechInitialized) {
      final available = await _speech.initialize(onStatus: _onStatus, onError: _onError);
      if (!mounted) return;
      _speechInitialized = available;
      if (!available) {
        setState(() {
          _errorMessage = 'Talegjenkjenning er ikke tilgjengelig i denne nettleseren (fungerer i Chrome/Edge).';
        });
        return;
      }
    }

    setState(() {
      _isListening = true;
      _errorMessage = null;
    });
    _listenOnce();
  }

  void _removeCandidate(int index) {
    setState(() => _candidates.removeAt(index).dispose());
  }

  Future<void> _saveAll() async {
    final list = _list;
    if (list == null) return;
    if (_isListening) await _toggleListening();

    for (final controller in _candidates) {
      final name = controller.text.trim();
      if (name.isEmpty) continue;
      await widget.itemService.addItem(widget.uid, list.id, name);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Scaffold(
      appBar: AppBar(title: Text(list == null ? 'Si varenavn' : 'Si varenavn til «${list.name}»')),
      body: _pickingList
          ? const Center(child: CircularProgressIndicator())
          : list == null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(_errorMessage ?? '')),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          IconButton.filled(
                            iconSize: 32,
                            padding: const EdgeInsets.all(18),
                            icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                            onPressed: _toggleListening,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isListening
                                ? 'Lytter — si en vare, så en kort pause, så neste'
                                : 'Trykk på mikrofonen og begynn å si varenavn',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _candidates.isEmpty
                          ? const Center(child: Text('Ingenting sagt ennå'))
                          : ListView.builder(
                              itemCount: _candidates.length,
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(child: TextField(controller: _candidates[index])),
                                    IconButton(
                                      icon: const Icon(Icons.close),
                                      tooltip: 'Fjern',
                                      onPressed: () => _removeCandidate(index),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                        onPressed: _candidates.isEmpty ? null : _saveAll,
                        child: Text('Legg til ${_candidates.length} varer i «${list.name}»'),
                      ),
                    ),
                  ],
                ),
    );
  }
}
