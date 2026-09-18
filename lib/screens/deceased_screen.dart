import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/theme.dart';
import '../data/adhkar_data.dart';
import '../l10n/strings.dart';
import '../widgets/adhkar_card.dart';
import '../widgets/dhikr_text.dart';
import '../widgets/tasbih_counter.dart';

class DeceasedPerson {
  final String id;
  final String name;
  final String? relation;
  final String? date;

  DeceasedPerson({
    required this.id,
    required this.name,
    this.relation,
    this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'relation': relation,
    'date': date,
  };
  factory DeceasedPerson.fromJson(Map<String, dynamic> j) => DeceasedPerson(
    id: j['id'],
    name: j['name'],
    relation: j['relation'],
    date: j['date'],
  );
}

class DeceasedScreen extends StatefulWidget {
  const DeceasedScreen({super.key});

  @override
  State<DeceasedScreen> createState() => _DeceasedScreenState();
}

class _DeceasedScreenState extends State<DeceasedScreen> {
  List<DeceasedPerson> _persons = [];
  final _nameController = TextEditingController();
  final _relationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('@noor_deceased');
    if (data != null) {
      final list = (jsonDecode(data) as List)
          .map((e) => DeceasedPerson.fromJson(e))
          .toList();
      if (mounted) setState(() => _persons = list);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '@noor_deceased',
      jsonEncode(_persons.map((e) => e.toJson()).toList()),
    );
  }

  void _addPerson() {
    _nameController.clear();
    _relationController.clear();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.goldBorder),
          ),
          title: Text(
            t('misc.addDeceasedTitle'),
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                textAlign: TextAlign.right,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: t('misc.deceasedNameHint'),
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.blackSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.goldBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.goldBorder),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _relationController,
                textAlign: TextAlign.right,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: t('misc.relationHintOptional'),
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.blackSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.goldBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.goldBorder),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                t('misc.cancel'),
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.trim().isEmpty) return;
                setState(() {
                  _persons.add(
                    DeceasedPerson(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: _nameController.text.trim(),
                      relation: _relationController.text.trim().isEmpty
                          ? null
                          : _relationController.text.trim(),
                      date: DateTime.now().toString().substring(0, 10),
                    ),
                  );
                });
                _save();
                Navigator.pop(ctx);
                HapticFeedback.lightImpact();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                t('misc.add'),
                style: const TextStyle(color: AppColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deletePerson(DeceasedPerson person) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.goldBorder),
          ),
          title: Text(
            t('misc.delete'),
            style: const TextStyle(color: AppColors.gold),
          ),
          content: Text(
            t('misc.deleteConfirmMessage').replaceAll('{name}', person.name),
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                t('misc.cancel'),
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _persons.removeWhere((p) => p.id == person.id));
                _save();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(
                t('misc.delete'),
                style: const TextStyle(color: AppColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duas = getAdhkarByCategory('deceased');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(t('misc.deceasedTitle')),
          centerTitle: true,
          actions: const [DhikrLangButton()],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addPerson,
          backgroundColor: AppColors.gold,
          child: const Icon(Icons.person_add, color: AppColors.black),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.goldBorder),
                  ),
                ),
                child: Text(
                  t('misc.deceasedPrayerHeader'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),

              // Persons list
              if (_persons.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    t('misc.deceasedListTitle'),
                    style: const TextStyle(
                      color: AppColors.textGold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ..._persons.map(
                  (person) => Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.blackCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.goldBorder),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.goldMuted,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppColors.gold,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        person.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: person.relation != null
                          ? Text(
                              person.relation!,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            )
                          : null,
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                        onPressed: () => _deletePerson(person),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.blackCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.goldBorder),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.person_add_alt_1,
                        color: AppColors.textMuted,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t('misc.deceasedEmptyState'),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],

              // Duas section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  t('misc.deceasedDuasTitle'),
                  style: const TextStyle(
                    color: AppColors.textGold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // onTasbih was left off here and nowhere else, so the counter
              // button on every dua for the deceased drew itself, took the
              // press, buzzed — and did nothing. A dead control that looks
              // exactly like a live one.
              ...duas.map(
                (d) => AdhkarCard(
                  dhikr: d,
                  fontSize: FontSizeOption.medium,
                  onTasbih: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TasbihCounter(dhikr: d)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
