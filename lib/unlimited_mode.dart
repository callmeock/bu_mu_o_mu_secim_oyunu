import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/ad_service.dart';
import 'main.dart';

class UnlimitedModePage extends StatefulWidget {
  const UnlimitedModePage({super.key, this.analyticsSource = 'bottom_tab'});

  /// [AnalyticsHelper.unlimitedOpen] için: `bottom_tab` | `home_card` vb.
  final String analyticsSource;

  @override
  State<UnlimitedModePage> createState() => _UnlimitedModePageState();
}

class _UnlimitedModePageState extends State<UnlimitedModePage> {
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
  bool? _selectedIsA; // Hangi seçenek seçildi (true = A, false = B, null = henüz seçilmedi)

  // kimin sırası? (kullanıcı)
  late final String _uid;

  // Banner Ad
  BannerAd? _bannerAd;
  bool _isBannerReady = false;
  Timer? _bannerRefreshTimer;
  bool _bannerReloadInFlight = false;

  /// Periyodik banner yenileme aralığı (manuel istek; politika için çok agresif yapmayın).
  static const Duration _bannerRefreshInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    AnalyticsHelper.unlimitedOpen(source: widget.analyticsSource);
    _uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    _boot();
    // İlk yükleme başarısız olsa bile sayfada kalındıkça yeniden dene.
    _startBannerRefreshTimer();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerRefreshTimer?.cancel();
    _bannerRefreshTimer = null;
    AdService.disposeBannerAd();
    _bannerAd = null;
    super.dispose();
  }

  void _startBannerRefreshTimer() {
    _bannerRefreshTimer?.cancel();
    _bannerRefreshTimer = Timer.periodic(_bannerRefreshInterval, (_) {
      if (!mounted) return;
      _reloadBannerAd();
    });
  }

  /// Ağaçtan kaldırdıktan sonra eski reklamı dispose edip yenisini yükler.
  void _reloadBannerAd() {
    if (!mounted || _bannerReloadInFlight) return;
    _bannerReloadInFlight = true;
    setState(() {
      _bannerAd = null;
      _isBannerReady = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _bannerReloadInFlight = false;
        return;
      }
      AdService.loadBannerAd(
        adSize: AdSize.banner,
        forceNewLoad: true,
        onAdLoaded: (ad) {
          _bannerReloadInFlight = false;
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad;
            _isBannerReady = true;
          });
        },
        onAdFailedToLoad: (error) {
          _bannerReloadInFlight = false;
          debugPrint('Banner yenileme başarısız: ${error.message}');
          if (!mounted) return;
          Future<void>.delayed(const Duration(seconds: 30), () {
            if (!mounted) return;
            _reloadBannerAd();
          });
        },
      );
    });
  }

  void _loadBannerAd({bool isRefresh = false}) {
    AdService.loadBannerAd(
      adSize: AdSize.banner,
      forceNewLoad: isRefresh,
      onAdLoaded: (ad) {
        if (!mounted) {
          ad.dispose();
          return;
        }
        setState(() {
          _bannerAd = ad;
          _isBannerReady = true;
        });
      },
      onAdFailedToLoad: (error) {
        debugPrint('Banner ad yüklenemedi: ${error.message}');
        if (!mounted) return;
        // İlk yükleme de başarısız olursa kısa bekleme sonrası tekrar dene.
        Future<void>.delayed(const Duration(seconds: 30), () {
          if (!mounted) return;
          _reloadBannerAd();
        });
      },
    );
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
      await AnalyticsHelper.unlimitedVoteSubmitted(
        questionId: q.id,
        choseA: chooseA,
        selected: chooseA ? q.optionA : q.optionB,
        opponent: chooseA ? q.optionB : q.optionA,
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
        _selectedIsA = chooseA;
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
        _selectedIsA = null;
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
        appBar: AppBar(
          title: const Text('Sınırsız Mod'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF3C26FF), // Sol mavi
                  Color(0xFFFF0000), // Sağ kırmızı
                ],
              ),
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sınırsız Mod'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF3C26FF), // Sol mavi
                  Color(0xFFFF0000), // Sağ kırmızı
                ],
              ),
            ),
          ),
        ),
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
        appBar: AppBar(
          title: const Text('Sınırsız Mod'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF3C26FF), // Sol mavi
                  Color(0xFFFF0000), // Sağ kırmızı
                ],
              ),
            ),
          ),
        ),
        body: const Center(child: Text('Soru bulunamadı.')),
      );
    }

    final q = _current!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sınırsız Mod'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF3C26FF), // Sol mavi
                Color(0xFFFF0000), // Sağ kırmızı
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Ana içerik
            Expanded(
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
                    selectedIsA: _selectedIsA,
                    onVoteA: () => _vote(true),
                    onVoteB: () => _vote(false),
                    onSkip: _skip,
                  ),
                ),
              ),
            ),
            // Banner reklam - sadece ad yüklendiyse ve hazırsa göster
            if (_isBannerReady && _bannerAd != null)
              Container(
                alignment: Alignment.center,
                width: double.infinity,
                height: _bannerAd!.size.height.toDouble(),
                color: Colors.transparent,
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
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
  final bool? selectedIsA; // true = A seçildi, false = B seçildi, null = henüz seçilmedi
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
    this.selectedIsA,
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
            showResults: showResults,
            pct: pctA,
            isSelected: selectedIsA == true,
            isOpponentSelected: selectedIsA == false,
            questionId: data.id,
            isOptionA: true,
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
            showResults: showResults,
            pct: pctB,
            isSelected: selectedIsA == false,
            isOpponentSelected: selectedIsA == true,
            questionId: data.id,
            isOptionA: false,
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
  final bool showResults;
  final int? pct;
  final bool isSelected; // Bu seçenek seçildi mi?
  final bool isOpponentSelected; // Diğer seçenek seçildi mi?
  final String questionId;
  final bool isOptionA; // Bu seçenek A mı B mi?

  const _ChoiceTile({
    Key? key,
    required this.label,
    required this.imageUrl,
    required this.onTap,
    required this.bgColor,
    required this.showResults,
    required this.pct,
    required this.isSelected,
    required this.isOpponentSelected,
    required this.questionId,
    required this.isOptionA,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Overlay yoğunluğu: seçilmeyen kart = koyu (0.80), seçilen kart = açık (0.05)
    final double overlayOpacity = showResults
        ? (isSelected ? 0.05 : (isOpponentSelected ? 0.80 : 0.0))
        : 0.0;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: bgColor,
          border: Border.all(
            color: Colors.black.withOpacity(0.15),
            width: 1,
          ),
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
            // Ana içerik
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [
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

            // Overlay efekti (kategorilerdeki gibi)
            if (overlayOpacity > 0)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      color: Colors.black.withOpacity(overlayOpacity),
                    ),
                  ),
                ),
              ),

            // Yüzdelik yazısı - ORTADA (kategorilerdeki gibi)
            if (showResults && pct != null)
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('unlimited_polls')
                    .doc(questionId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }
                  final data = snapshot.data!.data()!;
                  final aCount = (data['aCount'] ?? 0) as int;
                  final bCount = (data['bCount'] ?? 0) as int;
                  final total = aCount + bCount;
                  if (total == 0) return const SizedBox.shrink();

                  final thisPct = pct!;
                  
                  // Renkler: eşitse mavi, kazanan yeşil (#008000), kaybeden kırmızı
                  Color textColor;
                  if (aCount == bCount) {
                    textColor = Colors.blue;
                  } else {
                    // Bu seçenek A mı B mi?
                    final thisCount = isOptionA ? aCount : bCount;
                    final oppCount = isOptionA ? bCount : aCount;
                    textColor = (thisCount > oppCount)
                        ? const Color(0xFF008000)
                        : Colors.red;
                  }

                  return Center(
                    child: Text(
                      "%$thisPct",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        shadows: const [
                          Shadow(
                            blurRadius: 6,
                            color: Colors.black,
                            offset: Offset(2, 2),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}