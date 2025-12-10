import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UnlimitedModePage extends StatefulWidget {
  const UnlimitedModePage({Key? key}) : super(key: key);

  @override
  State<UnlimitedModePage> createState() => _UnlimitedModePageState();
}

class _UnlimitedModePageState extends State<UnlimitedModePage> {
  final _analytics = FirebaseAnalytics.instance;

  bool _loading = true;
  String? _error;

  // Firestore veri modeli
  List<_UQ> _questions = [];          // tüm sorular (id, text, options)
  List<String> _order = [];           // soru id'lerinin sırası (kullanıcıya özel)
  int _cursor = 0;                    // sıradaki soru index’i
  _UQ? _current;                      // ekranda görünen soru

  // oy / sonuç state
  bool _voting = false;
  bool _showResults = false;
  int? _pctA;
  int? _pctB;

  // kimin sırası? (kullanıcı)
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    _boot();
  }

  Future<void> _boot() async {
    try {
      setState(() { _loading = true; _error = null; });

      // 1) Soruları Firestore'dan çek
      await _loadQuestions();

      if (_questions.isEmpty) {
        throw Exception('Soru bulunamadı (unlimited_questions boş)'); 
      }

      // 2) Kullanıcıya özel sıra / cursor yükle veya oluştur
      await _loadOrCreateUserOrder();

      // 3) İlk soruyu seç
      _syncCurrentFromCursor();

      setState(() { _loading = false; });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadQuestions() async {
    final snap = await FirebaseFirestore.instance
        .collection('unlimited_questions')
        .where('active', isEqualTo: true)
        .get();

    final items = <_UQ>[];
    for (final d in snap.docs) {
      final m = d.data();
      items.add(_UQ(
        id: d.id,
        question: (m['question'] ?? '').toString(),
        optionA: (m['optionA'] ?? '').toString(),
        optionB: (m['optionB'] ?? '').toString(),
        imageA: (m['imageA'] ?? '')?.toString(),
        imageB: (m['imageB'] ?? '')?.toString(),
        weight: (m['weight'] is num) ? (m['weight'] as num).toDouble() : 1.0,
      ));
    }
    _questions = items;
  }

  Future<void> _loadOrCreateUserOrder() async {
    final stateRef = FirebaseFirestore.instance
        .collection('unlimited_users')
        .doc(_uid)
        .collection('state')
        .doc('default');

    final stateSnap = await stateRef.get();

    final allIds = _questions.map((q) => q.id).toList();

    if (stateSnap.exists) {
      final data = stateSnap.data()!;
      final List<dynamic> storedOrderDyn = (data['order'] ?? []) as List<dynamic>;
      final int storedCursor = (data['cursor'] ?? 0) as int;

      final storedOrder = storedOrderDyn.map((e) => e.toString()).toList();

      // Koleksiyondaki sorular değişmiş olabilir -> storedOrder'ı normalize et
      final validInOrder = storedOrder.where(allIds.contains).toList();

      // yeni eklenen soruları sona ekle
      final missing = allIds.where((id) => !validInOrder.contains(id)).toList();

      _order = [...validInOrder, ...missing];
      _cursor = _clampCursor(storedCursor, _order.length);

      // Eğer storedOrder boş ya da tutarsızsa, sıfırdan oluştur
      if (_order.isEmpty) {
        _order = _deterministicShuffle(allIds, seed: _uid.hashCode);
        _cursor = 0;
      }

      // normalize edilmiş halini kaydet
      await stateRef.set({
        'order': _order,
        'cursor': _cursor,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } else {
      // İlk kez giren kullanıcı -> deterministik karıştır
      _order = _deterministicShuffle(allIds, seed: _uid.hashCode);
      _cursor = 0;

      await stateRef.set({
        'order': _order,
        'cursor': _cursor,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  int _clampCursor(int c, int len) {
    if (len == 0) return 0;
    if (c < 0) return 0;
    if (c >= len) return len - 1;
    return c;
  }

  List<String> _deterministicShuffle(List<String> input, {required int seed}) {
    final list = List<String>.from(input);
    final rnd = Random(seed);
    // basit Fisher-Yates
    for (int i = list.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
    return list;
  }

  void _syncCurrentFromCursor() {
    if (_order.isEmpty) {
      _current = null;
      return;
    }
    final currentId = _order[_cursor % _order.length];
    _current = _questions.firstWhere((q) => q.id == currentId, orElse: () => _questions.first);
  }

  Future<void> _vote(bool chooseA) async {
    if (_current == null || _voting) return;
    setState(() { _voting = true; });

    final q = _current!;
    final pollRef = FirebaseFirestore.instance.collection('unlimited_polls').doc(q.id);

    try {
      // Sayaç artır (transaction)
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(pollRef);
        if (!snap.exists) {
          txn.set(pollRef, {
            'aCount': 0,
            'bCount': 0,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        txn.update(pollRef, {
          chooseA ? 'aCount' : 'bCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Analytics
      await _analytics.logEvent(
        name: 'unlimited_vote',
        parameters: {
          'question_id': q.id,
          'chose': chooseA ? 'A' : 'B',
        },
      );

      // Yüzdeleri oku ve göster
      final afterSnap = await pollRef.get();
      final aCount = (afterSnap.data()?['aCount'] ?? 0) as int;
      final bCount = (afterSnap.data()?['bCount'] ?? 0) as int;
      final total = (aCount + bCount).clamp(0, 1 << 31);

      int pctA = 0;
      int pctB = 0;
      if (total > 0) {
        pctA = ((aCount / total) * 100).round();
        pctB = ((bCount / total) * 100).round();
      }

      if (!mounted) return;
      setState(() {
        _pctA = pctA;
        _pctB = pctB;
        _showResults = true;
      });

      // Küçük gösterim süresi
      await Future.delayed(const Duration(milliseconds: 900));

      // Soru kuyruğunu döndür: Cevaplanan en sona gitsin
      await _rotateQueueAndPersist();

      if (!mounted) return;
      setState(() {
        _showResults = false;
        _pctA = null;
        _pctB = null;
        _voting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _voting = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Oy verirken hata oluştu: $e')),
      );
    }
  }

  Future<void> _rotateQueueAndPersist() async {
    if (_order.isEmpty) return;

    // mevcut index'teki soruyu kuyruğun sonuna taşı
    final currentId = _order[_cursor];
    final newOrder = List<String>.from(_order);
    newOrder.removeAt(_cursor);
    newOrder.add(currentId);

    // cursor aynı index'te kalsın (artık yeni soru orada)
    // yani bir sonraki soru otomatik olarak sıradaki olacak.
    _order = newOrder;

    // Firestore'a yaz
    final stateRef = FirebaseFirestore.instance
        .collection('unlimited_users')
        .doc(_uid)
        .collection('state')
        .doc('default');

    await stateRef.set({
      'order': _order,
      'cursor': _cursor,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // ekranda yeni current'ı yükle
    _syncCurrentFromCursor();
  }

  Future<void> _skip() async {
    if (_voting) return; // oy sırasında skip yok
    // Skip = oy kullanmadan sıradakine geç; aynı rotasyon kuralı
    await _rotateQueueAndPersist();
    setState(() {}); // UI refresh
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sınırsız Mod')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sınırsız Mod')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _boot,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar Dene'),
                )
              ],
            ),
          ),
        ),
      );
    }

    if (_current == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sınırsız Mod')),
        body: const Center(child: Text('Soru bulunamadı.')),
      );
    }

    final q = _current!;
    return Scaffold(
 
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: _QuestionCard(
              key: ValueKey(q.id),
              data: q,
              votingLocked: _voting,
              showResults: _showResults,
              pctA: _pctA,
              pctB: _pctB,
              onVoteA: () => _vote(true),
              onVoteB: () => _vote(false),
              onSkip: _skip,
            ),
          ),
        ),
      ),
    );
  }
}

class _UQ {
  final String id;
  final String question;
  final String optionA;
  final String optionB;
  final String? imageA;
  final String? imageB;
  final double weight;

  _UQ({
    required this.id,
    required this.question,
    required this.optionA,
    required this.optionB,
    this.imageA,
    this.imageB,
    this.weight = 1.0,
  });
}

class _QuestionCard extends StatelessWidget {
  final _UQ data;
  final bool votingLocked;
  final bool showResults;
  final int? pctA;
  final int? pctB;
  final VoidCallback onVoteA;
  final VoidCallback onVoteB;
  final VoidCallback onSkip;

  const _QuestionCard({
    Key? key,
    required this.data,
    required this.votingLocked,
    required this.showResults,
    required this.pctA,
    required this.pctB,
    required this.onVoteA,
    required this.onVoteB,
    required this.onSkip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.25);

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Soru metni
        Text(
          data.question,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 16),

        // A seçeneği
        Expanded(
          child: _ChoiceTile(
            label: data.optionA,
            imageUrl: data.imageA,
            onTap: votingLocked ? null : onVoteA,
            bgColor: bg,
            showBadge: showResults && pctA != null,
            badgeText: pctA != null ? "%${pctA!}" : null,
            highlight: showResults && (pctA ?? 0) >= (pctB ?? 0),
          ),
        ),
        const SizedBox(height: 12),

        // B seçeneği
        Expanded(
          child: _ChoiceTile(
            label: data.optionB,
            imageUrl: data.imageB,
            onTap: votingLocked ? null : onVoteB,
            bgColor: bg,
            showBadge: showResults && pctB != null,
            badgeText: pctB != null ? "%${pctB!}" : null,
            highlight: showResults && (pctB ?? 0) >= (pctA ?? 0),
          ),
        ),

        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: votingLocked ? null : onSkip,
          icon: const Icon(Icons.skip_next),
          label: const Text('Geç / Karıştır'),
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final VoidCallback? onTap;
  final Color bgColor;
  final bool showBadge;
  final String? badgeText;
  final bool highlight;

  const _ChoiceTile({
    Key? key,
    required this.label,
    required this.imageUrl,
    required this.onTap,
    required this.bgColor,
    required this.showBadge,
    required this.badgeText,
    required this.highlight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final borderColor =
        highlight ? const Color(0xFF15B21B) : Colors.black.withOpacity(0.15);
    final titleColor = Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: bgColor,
          border: Border.all(color: borderColor, width: highlight ? 2 : 1),
          image: (imageUrl != null && imageUrl!.isNotEmpty)
              ? DecorationImage(
                  image: CachedNetworkImageProvider(imageUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.35),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    shadows: const [
                      Shadow(
                        blurRadius: 6,
                        color: Colors.black,
                        offset: Offset(1, 1),
                      )
                    ],
                  ),
                ),
              ),
            ),
            if (showBadge && badgeText != null)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.35),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    badgeText!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}