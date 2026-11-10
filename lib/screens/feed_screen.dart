import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

// ─── Design tokens ─────────────────────────────────────────────────────────────
const _kPrimaryBlue = Color(0xFF2563EB);
const _kSecondaryBlue = Color(0xFF3B82F6);
const _kBrightBlue = Color(0xFF0EA5E9);
const _kDarkBlue = Color(0xFF1E3A8A);
const _kBackground = Color(0xFFF8FAFC);
const _kSoftBlue = Color(0xFFEFF6FF);
const _kTextDark = Color(0xFF111827);
const _kTextGrey = Color(0xFF6B7280);
const _kGreen = Color(0xFF22C55E);
const _kPurple = Color(0xFF8B5CF6);
const _kPink = Color(0xFFEC4899);
const _kOrange = Color(0xFFF97316);
const _kRed = Color(0xFFEF4444);

// ─── Focused medical API queries per category ──────────────────────────────────
// Uses NewsAPI boolean syntax: "phrase" for exact match, -term for exclusion.
const _kCategoryQueries = {
  'Diet':
      '("diabetes diet" OR "diabetic diet" OR "blood sugar diet" OR "low glycemic foods" OR "diabetes nutrition") -cocktail -alcohol -wine -beer -casino -politics',
  'Medication':
      '("diabetes medication" OR "insulin therapy" OR metformin OR "glucose control medication" OR "diabetes treatment") -politics -shopping -deals',
  'Mental Health':
      '("diabetes mental health" OR "diabetes stress" OR "chronic illness mental health" OR "diabetes depression" OR "diabetes anxiety") -politics',
  'Type 1 Diabetes':
      '("type 1 diabetes" OR "insulin pump" OR "continuous glucose monitor" OR CGM OR "diabetic ketoacidosis") -politics -shopping',
  'Health News':
      '("diabetes research" OR "blood glucose" OR "glucose monitoring" OR endocrinology OR HbA1c OR A1C) -politics -election -trump -biden -obama',
};

// ─── Category-specific acceptance keywords ────────────────────────────────────
// An article for a specific category must contain at least one of these.
const _kCategoryKeywords = <String, List<String>>{
  'Diet': [
    'diet',
    'nutrition',
    'food',
    'meal',
    'low glycemic',
    'carbohydrate',
    'carbs',
    'healthy eating',
    'blood sugar diet',
    'diabetic diet',
  ],
  'Medication': [
    'medication',
    'medicine',
    'insulin',
    'metformin',
    'treatment',
    'therapy',
    'glucose control',
    'prescription',
  ],
  'Mental Health': [
    'mental health',
    'stress',
    'anxiety',
    'depression',
    'wellbeing',
    'emotional',
    'chronic illness',
  ],
  'Type 1 Diabetes': [
    'type 1',
    't1d',
    'insulin pump',
    'cgm',
    'continuous glucose monitor',
    'ketoacidosis',
    'insulin therapy',
  ],
  'Health News': [
    'diabetes research',
    'blood glucose',
    'glucose monitoring',
    'endocrinology',
    'medical study',
    'clinical trial',
    'public health',
    'hba1c',
    'a1c',
  ],
};

// ─── General medical keywords (any article must match at least one) ────────────
const _kMedicalKeywords = <String>[
  'diabetes',
  'diabetic',
  'glucose',
  'blood sugar',
  'insulin',
  'metformin',
  'cgm',
  'continuous glucose',
  'endocrinology',
  'hypoglycemia',
  'hyperglycemia',
  'type 1 diabetes',
  'type 2 diabetes',
  'hba1c',
  'a1c',
  'medication',
  'chronic illness',
  'nutrition',
  'low glycemic',
  'mental health',
  'depression',
  'anxiety',
  'insulin pump',
  'diabetic ketoacidosis',
];

// ─── Blocked keywords (any article containing these is rejected) ───────────────
const _kBlockedKeywords = <String>[
  'politics',
  'trump',
  'biden',
  'obama',
  'election',
  'congress',
  'senate',
  'white house',
  'government',
  'judge',
  'court',
  'lawsuit',
  'tariff',
  'war',
  'celebrity',
  'football',
  'sports',
  'cricket',
  'casino',
  'cocktail',
  'alcohol',
  'wine',
  'beer',
  'whisky',
  'vodka',
  'shopping',
  'prime day',
  'deals',
  'discount',
  'garmin deal',
  'fitbit deal',
  'oura ring',
  'fashion',
  'travel',
  'stock market',
  'crypto',
];

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // ── Preserved state ───────────────────────────────────────────────────────────
  String selectedCategory = 'All';
  List<String> categories = [
    'All',
    'Diet',
    'Medication',
    'Mental Health',
    'Type 1 Diabetes',
    'Health News',
  ];
  List<String> userPreferences = [];

  // ── Preserved: API keys ───────────────────────────────────────────────────────
  final Map<String, String> apiKeys = {
    'Diet': '73e3b43feab34d20a99f776dbb51bf2c',
    'Medication': '73e3b43feab34d20a99f776dbb51bf2c',
    'Mental Health': '73e3b43feab34d20a99f776dbb51bf2c',
    'Type 1 Diabetes': '73e3b43feab34d20a99f776dbb51bf2c',
    'Health News': '73e3b43feab34d20a99f776dbb51bf2c',
  };

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _fetchUserPreferences);
  }

  // ── Preserved: Firestore user preferences fetch ───────────────────────────────
  Future<void> _fetchUserPreferences() async {
    const userId = 'example_user_id';
    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(userId)
              .get();
      if (userDoc.exists && userDoc.data() != null) {
        setState(() {
          userPreferences = List<String>.from(
            userDoc.data()?['preferences'] ?? [],
          );
        });
      }
    } catch (e) {
      debugPrint('[FeedScreen] Error fetching user preferences: $e');
    }
  }

  // ── News API fetch with strict medical filtering ──────────────────────────────
  // When selectedCategory == "All": fetch all category queries, deduplicate by URL.
  // When a specific category: fetch only that category's query.
  Future<List<Map<String, dynamic>>> _fetchNewsAndPosts() async {
    debugPrint('[FeedScreen] Selected category: $selectedCategory');

    final List<Map<String, dynamic>> allPosts = [];
    final seenUrls = <String>{};

    try {
      // ── Preserved: Firestore NewsFeed fetch ─────────────────────────────────
      final snapshot =
          await FirebaseFirestore.instance
              .collection('NewsFeed')
              .orderBy('timestamp', descending: true)
              .get();

      allPosts.addAll(
        snapshot.docs.map(
          (doc) => {
            'title': doc['title'],
            'content': doc['content'],
            'imageUrl': doc['imageUrl'],
            'category': doc['category'],
            'likes': doc['likes'] ?? 0,
            'comments': List<String>.from(doc['comments'] ?? []),
            'url': doc['url'],
            'timestamp': (doc['timestamp'] as Timestamp).toDate(),
            'docId': doc.id,
            'source': 'user',
          },
        ),
      );

      // ── News API: only fetch categories relevant to the selected chip ────────
      final categoriesToFetch =
          selectedCategory == 'All'
              ? categories.where((c) => c != 'All').toList()
              : [selectedCategory];

      for (final category in categoriesToFetch) {
        final apiKey = apiKeys[category];
        if (apiKey == null) continue;

        final query = _kCategoryQueries[category] ?? category;

        final response = await http.get(
          Uri.parse(
            'https://newsapi.org/v2/everything'
            '?q=${Uri.encodeComponent(query)}'
            '&language=en'
            '&sortBy=publishedAt'
            '&pageSize=10'
            '&apiKey=$apiKey',
          ),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final articles = (data['articles'] as List<dynamic>?) ?? [];
          debugPrint(
            '[FeedScreen] $category: ${articles.length} raw articles from API',
          );

          int accepted = 0;

          for (final rawArticle in articles) {
            final article = rawArticle as Map<String, dynamic>;
            final articleTitle = article['title']?.toString() ?? '';
            final articleUrl = article['url']?.toString() ?? '';

            // Skip NewsAPI "[Removed]" placeholder entries
            if (articleTitle == '[Removed]') continue;

            // Deduplicate by URL across all category fetches
            if (articleUrl.isNotEmpty && seenUrls.contains(articleUrl)) {
              continue;
            }

            // Apply strict medical relevance filter
            if (!_isRelevantMedicalArticle(article, category)) continue;

            if (articleUrl.isNotEmpty) seenUrls.add(articleUrl);
            accepted++;

            final description = article['description']?.toString() ?? '';
            allPosts.add({
              'title': articleTitle.isEmpty ? 'No Title' : articleTitle,
              'content':
                  description.isNotEmpty
                      ? description
                      : 'No Description Available',
              'imageUrl': article['urlToImage'] ?? '',
              'url': articleUrl,
              'timestamp':
                  DateTime.tryParse(article['publishedAt'] ?? '') ??
                  DateTime.now(),
              'category': category,
              'source': 'news',
            });
          }

          debugPrint(
            '[FeedScreen] $category: $accepted articles accepted after filtering',
          );
        } else {
          debugPrint(
            '[FeedScreen] Error fetching $category (${response.statusCode}): ${response.body}',
          );
        }
      }
    } catch (e) {
      debugPrint('[FeedScreen] Error fetching posts: $e');
    }

    // ── Preserved: user preference filter ─────────────────────────────────────
    List<Map<String, dynamic>> result = allPosts;
    if (userPreferences.isNotEmpty) {
      result =
          allPosts
              .where((post) => userPreferences.contains(post['category']))
              .toList();
    }

    result.sort(
      (a, b) =>
          (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
    );

    debugPrint('[FeedScreen] Total posts returned: ${result.length}');
    return result;
  }

  // ── Preserved: like post ──────────────────────────────────────────────────────
  void _likePost(String docId, int currentLikes) {
    FirebaseFirestore.instance.collection('NewsFeed').doc(docId).update({
      'likes': currentLikes + 1,
    });
  }

  // ── Strict medical relevance filter ──────────────────────────────────────────
  // Checks title + description + content + source name.
  // Returns false if blocked keyword found, no medical keyword found,
  // or (for specific category) no category keyword found.
  bool _isRelevantMedicalArticle(
    Map<String, dynamic> article,
    String category,
  ) {
    final title = (article['title']?.toString() ?? '').toLowerCase();
    final description =
        (article['description']?.toString() ?? '').toLowerCase();
    final content = (article['content']?.toString() ?? '').toLowerCase();
    final sourceName =
        ((article['source'] as Map<String, dynamic>?)?['name']?.toString() ??
                '')
            .toLowerCase();
    final combined = '$title $description $content $sourceName';

    // 1. Reject immediately if any blocked keyword is present
    for (final kw in _kBlockedKeywords) {
      if (combined.contains(kw)) {
        debugPrint(
          '[FeedScreen] REJECTED "${article['title']}": blocked keyword "$kw"',
        );
        return false;
      }
    }

    // 2. Reject if no general medical keyword is present
    final hasGeneral = _kMedicalKeywords.any((kw) => combined.contains(kw));
    if (!hasGeneral) {
      debugPrint(
        '[FeedScreen] REJECTED "${article['title']}": no medical keyword found',
      );
      return false;
    }

    // 3. For specific categories, require at least one category keyword
    if (category != 'All') {
      final catKeywords = _kCategoryKeywords[category] ?? [];
      final hasCatKeyword = catKeywords.any((kw) => combined.contains(kw));
      if (!hasCatKeyword) {
        debugPrint(
          '[FeedScreen] REJECTED "${article['title']}": no "$category" keyword found',
        );
        return false;
      }
    }

    return true;
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: Column(
        children: [
          _buildHeader(),
          _buildCategoryChips(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchNewsAndPosts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _kPrimaryBlue),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: _kTextGrey,
                          size: 52,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Error loading news',
                          style: TextStyle(color: _kTextGrey, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                final posts = snapshot.data ?? [];
                // Secondary local filter: when a specific category is active,
                // ensure only that category's articles are shown (Firestore posts
                // already have a 'category' field; API posts were fetched by category).
                final filteredPosts =
                    selectedCategory == 'All'
                        ? posts
                        : posts
                            .where(
                              (post) => post['category'] == selectedCategory,
                            )
                            .toList();

                if (filteredPosts.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildNoArticlesState(),
                      const SizedBox(height: 16),
                      _buildJoinCommunityCard(),
                      const SizedBox(height: 24),
                    ],
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  // +1 appends the community card after the last article
                  itemCount: filteredPosts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == filteredPosts.length) {
                      return _buildJoinCommunityCard();
                    }
                    return _buildNewsCard(filteredPosts[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kDarkBlue, _kSecondaryBlue],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circle — top-right
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Decorative circle — bottom-left
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Faint megaphone icon — decorative
          Positioned(
            right: 20,
            bottom: 14,
            child: Icon(
              Icons.campaign_rounded,
              color: Colors.white.withValues(alpha: 0.08),
              size: 72,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _BackButton(),
                      const Spacer(),
                      // Bell icon with red notification dot
                      Stack(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.2,
                              ),
                            ),
                            child: const Icon(
                              Icons.notifications_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          Positioned(
                            right: 9,
                            top: 9,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _kRed,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'News & Community',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Stay updated with diabetes and health-related news.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xCCFFFFFF),
                      height: 1.4,
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

  // ─── 2. Category Chips ───────────────────────────────────────────────────────

  Widget _buildCategoryChips() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final cat = categories[index];
            final isSelected = selectedCategory == cat;
            final color = _categoryColor(cat);
            return GestureDetector(
              onTap: () => setState(() => selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? color : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow:
                      isSelected
                          ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.32),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                          : null,
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : _kTextGrey,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── 3. News Card ────────────────────────────────────────────────────────────

  Widget _buildNewsCard(Map<String, dynamic> post) {
    final category = (post['category'] as String?) ?? 'Health News';
    final title = (post['title'] as String?) ?? '';
    final content = (post['content'] as String?) ?? '';
    final imageUrl = (post['imageUrl'] as String?) ?? '';
    final url = (post['url'] as String?) ?? '';
    final timestamp = (post['timestamp'] as DateTime?) ?? DateTime.now();
    final source = (post['source'] as String?) ?? 'news';
    final readTime = _readTime(content);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Article image ──────────────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child:
                imageUrl.isNotEmpty
                    ? Image.network(
                      imageUrl,
                      height: 178,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => _buildImagePlaceholder(category),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 178,
                          color: _kSoftBlue,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: _kPrimaryBlue,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                    )
                    : _buildImagePlaceholder(category),
          ),

          // ── Article content ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryBadge(category),
                const SizedBox(height: 10),
                // Title
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _kTextDark,
                    height: 1.4,
                  ),
                ),
                // Description
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _kTextGrey,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // ── Bottom meta row ────────────────────────────────────────
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: _kTextGrey.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      readTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: _kTextGrey.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: _kTextGrey.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, yyyy').format(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: _kTextGrey.withValues(alpha: 0.85),
                      ),
                    ),
                    const Spacer(),
                    // Like button — only for user posts (Firestore NewsFeed)
                    if (source == 'user' && post['docId'] != null) ...[
                      GestureDetector(
                        onTap:
                            () => _likePost(
                              post['docId'] as String,
                              (post['likes'] as int?) ?? 0,
                            ),
                        child: const Icon(
                          Icons.favorite_border_rounded,
                          size: 18,
                          color: _kPink,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    // Open article button (Preserved: url_launcher)
                    if (url.isNotEmpty)
                      GestureDetector(
                        onTap: () => launchUrl(Uri.parse(url)),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _kPrimaryBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4. Category Badge ───────────────────────────────────────────────────────

  Widget _buildCategoryBadge(String category) {
    final color = _categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // ─── 5. Image Placeholder ────────────────────────────────────────────────────

  Widget _buildImagePlaceholder(String category) {
    final color = _categoryColor(category);
    return Container(
      height: 178,
      width: double.infinity,
      color: color.withValues(alpha: 0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _categoryIcon(category),
            color: color.withValues(alpha: 0.45),
            size: 52,
          ),
          const SizedBox(height: 8),
          Text(
            category,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 6. No Articles State ────────────────────────────────────────────────────

  Widget _buildNoArticlesState() {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _kSoftBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.article_rounded,
                color: _kPrimaryBlue,
                size: 36,
              ),
            ),
          ),
          SizedBox(height: 18),
          Text(
            'No relevant diabetes or medical news found for this category.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _kTextGrey, height: 1.55),
          ),
        ],
      ),
    );
  }

  // ─── 7. Join Community Card ──────────────────────────────────────────────────

  Widget _buildJoinCommunityCard() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kDarkBlue, _kSecondaryBlue],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _kPrimaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join the Community',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Share your diabetes journey and get support from others.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xCCFFFFFF),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _readTime(String content) {
    if (content.isEmpty) return '1 min read';
    final words =
        content.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final minutes = (words / 200).ceil();
    return '${minutes < 1 ? 1 : minutes} min read';
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Diet':
        return _kGreen;
      case 'Medication':
        return _kPrimaryBlue;
      case 'Mental Health':
        return _kPurple;
      case 'Type 1 Diabetes':
        return _kOrange;
      case 'Health News':
        return _kBrightBlue;
      default:
        return _kPrimaryBlue;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Diet':
        return Icons.restaurant_rounded;
      case 'Medication':
        return Icons.medication_rounded;
      case 'Mental Health':
        return Icons.psychology_rounded;
      case 'Type 1 Diabetes':
        return Icons.bloodtype_rounded;
      case 'Health News':
        return Icons.health_and_safety_rounded;
      default:
        return Icons.article_rounded;
    }
  }
}

class _BackButton extends StatefulWidget {
  const _BackButton();

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
