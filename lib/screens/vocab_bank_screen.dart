import 'package:flutter/material.dart';
import '../core/app_database.dart';
import '../models/vocab_word.dart';

class VocabBankScreen extends StatefulWidget {
  const VocabBankScreen({super.key});

  @override
  State<VocabBankScreen> createState() => _VocabBankScreenState();
}

class _VocabBankScreenState extends State<VocabBankScreen> {
  List<VocabWord> _words = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    final rows = await AppDatabase.instance.getAllWords();
    if (!mounted) return;
    setState(() {
      _words = rows.map(VocabWord.fromMap).toList();
      _loading = false;
    });
  }

  Future<void> _deleteWord(VocabWord word) async {
    await AppDatabase.instance.deleteWord(word.id);
    if (!mounted) return;
    setState(() => _words.removeWhere((w) => w.id == word.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: Text('Vocabulary (${_words.length})', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _words.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No saved words yet.\nTap any subtitle word while watching to save it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 15),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _words.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (context, index) {
                    final word = _words[index];
                    return Dismissible(
                      key: ValueKey(word.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.redAccent.withOpacity(0.8),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteWord(word),
                      child: ListTile(
                        title: Text(
                          word.word,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: word.sourceSentence != null && word.sourceSentence!.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  word.sourceSentence!,
                                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : null,
                        trailing: word.videoTitle != null
                            ? SizedBox(
                                width: 90,
                                child: Text(
                                  word.videoTitle!,
                                  style: const TextStyle(color: Colors.white30, fontSize: 11),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}
