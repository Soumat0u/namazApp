part of '../social_screen.dart';

// ═══════════════════════════════════════════════
// 📸 GELİŞMİŞ HİKAYE (STORY) GÖRÜNTÜLEYİCİ
// ═══════════════════════════════════════════════

void _showStoryViewer(BuildContext context, AppThemeColors r, List<UserStory> stories, int initialIndex) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Story",
    barrierColor: Colors.black.withOpacity(0.85),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, anim1, anim2) {
      return _StoryViewerContent(
        stories: stories,
        initialIndex: initialIndex,
        r: r,
      );
    },
  );
}

// ═══════════════════════════════════════════════
// 👁 HİKAYEYİ GÖRENLER LİSTESİ (BOTTOM SHEET)
// ═══════════════════════════════════════════════
Future<void> _showStoryViewersList(BuildContext context, AppThemeColors r, UserStory story) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: r.arkaPlanRengi,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: r.pasifRenk.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "${story.viewerProfiles.length} Görüntüleme",
              style: TextStyle(
                color: r.yaziRengi,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: r.pasifRenk.withOpacity(0.2)),
            Expanded(
              child: story.viewerProfiles.isEmpty
                  ? Center(
                      child: Text(
                        "Hikayeni henüz kimse görmedi.",
                        style: TextStyle(color: r.yaziRengi.withOpacity(0.5)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: story.viewerProfiles.length,
                      itemBuilder: (context, index) {
                        final viewer = story.viewerProfiles[index];
                        final name = viewer['displayName'] ?? "İsimsiz Kardeş";
                        final time = viewer['viewedAt'] != null 
                            ? (viewer['viewedAt'] as Timestamp).toDate().zamanFarki 
                            : "";

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: r.anaRenk.withOpacity(0.1),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : "?",
                              style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            name, 
                            style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            time,
                            style: TextStyle(color: r.pasifRenk, fontSize: 12),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );
}

class _StoryViewerContent extends StatefulWidget {
  final List<UserStory> stories;
  final int initialIndex;
  final AppThemeColors r;

  const _StoryViewerContent({
    required this.stories,
    required this.initialIndex,
    required this.r,
  });

  @override
  State<_StoryViewerContent> createState() => _StoryViewerContentState();
}

class _StoryViewerContentState extends State<_StoryViewerContent> with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _startStory();
    
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });
  }

  void _startStory() {
    _progressController.stop();
    _progressController.reset();
    _progressController.forward();
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Dismissible(
        key: const Key('story-viewer'),
        direction: DismissDirection.down,
        onDismissed: (_) => Navigator.pop(context),
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.stories.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
            _startStory();
          },
        itemBuilder: (context, index) {
          final story = widget.stories[index];
          final isMe = story.uid == context.read<NamazProvider>().currentUid;

          return Stack(
            children: [
              // 1. BULANIK ARKA PLAN
              Positioned.fill(
                child: Image.memory(
                  base64Decode(story.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(color: Colors.black.withOpacity(0.4)),
                ),
              ),

              // 2. ANA İÇERİK
              SafeArea(
                child: Column(
                  children: [
                    // İlerleme Çubuğu ve Üst Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        children: [
                          // 🔥 İlerleme Çubuğu - Her kullanıcının tek story'si olduğu için tek parça
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: AnimatedBuilder(
                                    animation: _progressController,
                                    builder: (context, child) {
                                      return FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: _progressController.value,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: widget.r.anaRenk.withOpacity(0.5),
                                child: Text(story.displayName.isNotEmpty ? story.displayName[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(story.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                                    Text("@${story.username} • ${story.createdAt.zamanFarki}", style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              if (isMe)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                                  onPressed: () async {
                                    _progressController.stop();
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("Hikayeyi Sil"),
                                        content: const Text("Bu hikayeyi silmek istediğinize emin misiniz?"),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
                                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sil")),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await FirebaseService().deleteStory(story.uid);
                                      if (context.mounted) Navigator.pop(context);
                                    } else {
                                      _progressController.forward();
                                    }
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Hikaye Görseli
                    Expanded(
                      child: GestureDetector(
                        onTapDown: (details) {
                          final screenWidth = MediaQuery.of(context).size.width;
                          if (details.globalPosition.dx < screenWidth / 3) {
                            _previousStory();
                          } else {
                            _nextStory();
                          }
                        },
                        onLongPressStart: (_) => _progressController.stop(),
                        onLongPressEnd: (_) => _progressController.forward(),
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.memory(
                              base64Decode(story.imageUrl),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // İzleyenler Barı (Benim hikayemse)
                    if (isMe)
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('stories').doc(story.uid).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox(height: 100);
                          final currentStory = UserStory.fromFirestore(snapshot.data!);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 30),
                            child: GestureDetector(
                              onTap: () {
                                _progressController.stop();
                                _showStoryViewersList(context, widget.r, currentStory).then((_) {
                                  _progressController.forward();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.visibility_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text("${currentStory.viewers.length} Görüntüleme", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                      )
                    else
                      const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
}
