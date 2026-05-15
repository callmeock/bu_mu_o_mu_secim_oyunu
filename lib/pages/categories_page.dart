import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';
import '../analytics/analytics_constants.dart';
import '../services/unlock_ad_flow.dart';
import '../models/category.dart';
import 'quiz_page.dart';

/// Kategoriler sayfası - Quiz tipindeki kategoriler (50 soruluk)
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<Category> categories = [];
  bool _loading = true;
  String? _error;
  Set<String> _unlockedCategories = {};
  bool _loadingUnlocked = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadUnlockedCategories();
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Read from categories collection where type == "quiz"
      // Composite index required: categories (type, createdAt desc)
      final snapshot = await FirebaseFirestore.instance
          .collection('categories')
          .where('type', isEqualTo: 'quiz')
          .orderBy('createdAt', descending: true)
          .get();

      final List<Category> loadedCategories = [];
      for (var doc in snapshot.docs) {
        try {
          final category = Category.fromFirestore(doc);
          loadedCategories.add(category);
        } catch (e) {
          // Skip invalid categories
          debugPrint('Error parsing category ${doc.id}: $e');
        }
      }

      // If no categories with createdAt, fallback: get all and sort by name
      if (loadedCategories.isEmpty) {
        final fallbackSnapshot = await FirebaseFirestore.instance
            .collection('categories')
            .where('type', isEqualTo: 'quiz')
            .get();
        
        loadedCategories.clear();
        for (var doc in fallbackSnapshot.docs) {
          try {
            final category = Category.fromFirestore(doc);
            loadedCategories.add(category);
          } catch (e) {
            debugPrint('Error parsing category ${doc.id}: $e');
          }
        }
        
        // Sort by name as fallback
        loadedCategories.sort((a, b) => a.name.compareTo(b.name));
      }

      if (!mounted) return;
      setState(() {
        categories = loadedCategories;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Kategoriler yüklenemedi. (${e.toString()})";
        _loading = false;
      });
    }
  }

  Future<void> _loadUnlockedCategories() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _unlockedCategories = {};
          _loadingUnlocked = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('user_progress')
          .doc(user.uid)
          .get();

      final unlocked = doc.data()?['unlockedCategories'] as List<dynamic>?;
      if (!mounted) return;
      setState(() {
        _unlockedCategories = (unlocked ?? []).map((e) => e.toString()).toSet();
        _loadingUnlocked = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _unlockedCategories = {};
        _loadingUnlocked = false;
      });
    }
  }

  Future<void> _unlockCategory(String categoryKey, String categoryName) async {
    if (!mounted) return;
    try {
      final watched = await UnlockAdFlow.showRewardedForCategory(
        context,
        categoryKey: categoryKey,
        categoryName: categoryName,
      );
      if (!mounted) return;
      if (watched) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('user_progress')
              .doc(user.uid)
              .set({
            'unlockedCategories': FieldValue.arrayUnion([categoryKey]),
            'lastUnlock': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await AnalyticsHelper.categoryUnlocked(
            categoryKey: categoryKey,
            categoryName: categoryName,
            method: 'rewarded_interstitial',
            gameMode: 'quiz',
          );

          setState(() {
            _unlockedCategories.add(categoryKey);
          });

          final category = categories.firstWhere(
            (c) => c.id == categoryKey,
            orElse: () => categories.first,
          );

          final items = category.items;
          if (items.length < 2) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bu kategoride henüz yeterli öğe yok.'),
              ),
            );
            return;
          }

          final int pairCount = items.length ~/ 2;
          final List<Map<String, dynamic>> questions = [];
          for (int i = 0; i < pairCount; i++) {
            final int idx = i * 2;
            if (idx + 1 < items.length) {
              questions.add({
                'itemA': items[idx],
                'itemB': items[idx + 1],
              });
            }
          }

          if (questions.isEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bu kategoride henüz soru yok.'),
              ),
            );
            return;
          }

          AnalyticsHelper.categoryPlayed(
            categoryKey: categoryKey,
            categoryName: categoryName,
            gameMode: 'quiz',
          );

          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: AnalyticsScreenNames.quiz),
              builder: (_) => QuizPage(
                categoryName: categoryName,
                categoryKey: categoryKey,
                questions: questions,
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Reklam izlenemedi. Lütfen tekrar deneyin.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategoriler'),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadCategories)
              : categories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.category, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'Henüz kategori yok',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Yakında eklenecek!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCategories,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: categories.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 1,
                            mainAxisSpacing: 16,
                            childAspectRatio: 64 / 27,
                          ),
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            final isLocked =
                                !_unlockedCategories.contains(category.id);

                            return _FrostedCategoryCard(
                              title: category.name,
                              imageUrl: category.image,
                              categoryKey: category.id,
                              isLocked: isLocked,
                              onTap: isLocked
                                  ? () => _unlockCategory(category.id, category.name)
                                  : () {
                                      // Generate pairs from items
                                      final items = category.items;
                                      if (items.length < 2) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Bu kategoride henüz yeterli öğe yok.'),
                                          ),
                                        );
                                        return;
                                      }

                                      // Generate pairs: (items[0],items[1]), (items[2],items[3]), ...
                                      // If odd length, ignore last item
                                      final int pairCount = items.length ~/ 2;
                                      final List<Map<String, dynamic>> questions = [];
                                      for (int i = 0; i < pairCount; i++) {
                                        final int idx = i * 2;
                                        if (idx + 1 < items.length) {
                                          questions.add({
                                            'itemA': items[idx],
                                            'itemB': items[idx + 1],
                                          });
                                        }
                                      }
                                      
                                      if (questions.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Bu kategoride henüz soru yok.'),
                                          ),
                                        );
                                        return;
                                      }

                                      AnalyticsHelper.categoryPlayed(
                                        categoryKey: category.id,
                                        categoryName: category.name,
                                        gameMode: 'quiz',
                                      );

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          settings: const RouteSettings(
                                            name: AnalyticsScreenNames.quiz,
                                          ),
                                          builder: (_) => QuizPage(
                                            categoryName: category.name,
                                            categoryKey: category.id,
                                            questions: questions,
                                          ),
                                        ),
                                      );
                                    },
                            );
                          },
                        ),
                      ),
                    ),
    );
  }
}

// Favorin Hangisi ile aynı tasarım - _FrostedCard kullan
class _FrostedCategoryCard extends StatefulWidget {
  final String title;
  final String imageUrl;
  final String categoryKey;
  final bool isLocked;
  final VoidCallback onTap;

  const _FrostedCategoryCard({
    required this.title,
    required this.imageUrl,
    required this.categoryKey,
    required this.isLocked,
    required this.onTap,
  });

  @override
  State<_FrostedCategoryCard> createState() => _FrostedCategoryCardState();
}

class _FrostedCategoryCardState extends State<_FrostedCategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.isLocked) {
      _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat(reverse: true);
      _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ),
      );
    }
  }

  @override
  void dispose() {
    if (widget.isLocked) {
      _animationController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FrostedCard(
      onTap: widget.onTap,
      background: _CardBackground.image(url: widget.imageUrl),
      child: Stack(
        children: [
          // Kategori adı - her zaman göster
          Center(
            child: Text(
              widget.title,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: widget.isLocked
                    ? Colors.white.withOpacity(0.5)
                    : Colors.white,
                shadows: const [
                  Shadow(
                    color: Colors.black45,
                    blurRadius: 4,
                    offset: Offset(1, 2),
                  ),
                ],
              ),
            ),
          ),
          // Kilitli durum için minimal overlay
          if (widget.isLocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  children: [
                    // Sağ üst köşe - Kilit badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: AnimatedBuilder(
                        animation: _scaleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.lock,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Alt kısım - Video izle butonu
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFF6B35),
                              Color(0xFFF7931E),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onTap,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Oyna',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// _FrostedCard ve _CardBackground'ı favorin_hangisi_page'den kopyala
class _FrostedCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final _CardBackground background;

  const _FrostedCard({
    required this.child,
    required this.onTap,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = background.when(
      imageBuilder: (url) => BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.05),
        image: url.isNotEmpty
            ? DecorationImage(
                image: CachedNetworkImageProvider(url),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.35),
                  BlendMode.darken,
                ),
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      gradientBuilder: () => BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7F00FF), // mor
            Color(0xFF00B3FF), // mavi
            Color(0xFFFF6A00), // turuncu
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: decoration,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.black.withOpacity(0.08),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _CardBackground {
  final String? _imageUrl;
  final bool _isGradient;
  const _CardBackground._(this._imageUrl, this._isGradient);

  factory _CardBackground.image({required String url}) =>
      _CardBackground._(url, false);
  const _CardBackground.gradient() : this._(null, true);

  T when<T>({
    required T Function(String url) imageBuilder,
    required T Function() gradientBuilder,
  }) {
    if (_isGradient) return gradientBuilder();
    return imageBuilder(_imageUrl ?? '');
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            )
          ],
        ),
      ),
    );
  }
}

