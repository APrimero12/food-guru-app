// lib/views/friends/friends_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:appdevproject/models/user_model.dart';
import 'package:appdevproject/providers/user_provider.dart';
import 'package:appdevproject/services/follow_service.dart';
import 'package:appdevproject/views/profile/user_profile_page.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FollowService _followService = FollowService();
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _following = [];
  List<UserModel> _followers = [];
  List<UserModel> _discover  = [];

  /// IDs of users the current user is following — kept locally for instant
  /// button state without waiting for Firestore on every toggle.
  final Set<String> _followingIds = {};

  String _searchQuery = '';
  bool _isLoading = true;
  bool _hasError  = false;

  // ── filtered views (computed from search query) ───────────────────────────

  List<UserModel> get _displayFollowing => _filter(_following);
  List<UserModel> get _displayFollowers => _filter(_followers);
  List<UserModel> get _displayDiscover  => _filter(_discover);

  List<UserModel> _filter(List<UserModel> list) {
    if (_searchQuery.isEmpty) return list;
    return list.where((u) {
      final name     = (u.name     ?? '').toLowerCase();
      final username = (u.username ?? '').toLowerCase();
      return name.contains(_searchQuery) || username.contains(_searchQuery);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── data loading ──────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final uid = Provider.of<UserProvider>(context, listen: false)
        .currentUser
        ?.uid;
    if (uid == null) return;

    setState(() { _isLoading = true; _hasError = false; });

    try {
      final results = await Future.wait([
        _followService.getFollowing(uid),
        _followService.getFollowers(uid),
        _followService.getDiscoverUsers(uid),
        _followService.getFollowingIds(uid),
      ]);

      if (mounted) {
        setState(() {
          _following    = results[0] as List<UserModel>;
          _followers    = results[1] as List<UserModel>;
          _discover     = results[2] as List<UserModel>;
          _followingIds
            ..clear()
            ..addAll(results[3] as Set<String>);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  // ── follow toggle ─────────────────────────────────────────────────────────

  Future<void> _toggleFollow(UserModel target) async {
    final uid = Provider.of<UserProvider>(context, listen: false)
        .currentUser
        ?.uid;
    if (uid == null) return;

    final wasFollowing = _followingIds.contains(target.uid);

    // Optimistic local update.
    setState(() {
      if (wasFollowing) {
        _followingIds.remove(target.uid);
        _following.removeWhere((u) => u.uid == target.uid);
        if (!_discover.any((u) => u.uid == target.uid)) {
          _discover.insert(0, target);
        }
      } else {
        _followingIds.add(target.uid);
        if (!_following.any((u) => u.uid == target.uid)) {
          _following.insert(0, target);
        }
        _discover.removeWhere((u) => u.uid == target.uid);
      }
    });

    try {
      if (wasFollowing) {
        await _followService.unfollowUser(uid, target.uid);
      } else {
        await _followService.followUser(uid, target.uid);
      }
    } catch (_) {
      // Revert on failure.
      if (mounted) {
        setState(() {
          if (wasFollowing) {
            _followingIds.add(target.uid);
            if (!_following.any((u) => u.uid == target.uid)) {
              _following.insert(0, target);
            }
            _discover.removeWhere((u) => u.uid == target.uid);
          } else {
            _followingIds.remove(target.uid);
            _following.removeWhere((u) => u.uid == target.uid);
            if (!_discover.any((u) => u.uid == target.uid)) {
              _discover.insert(0, target);
            }
          }
        });
      }
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── tab bar ──────────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.orange,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Following (${_following.length})'),
              Tab(text: 'Followers (${_followers.length})'),
              const Tab(text: 'Discover'),
            ],
          ),
        ),

        // ── search bar ────────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or username…',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear,
                    color: Colors.grey, size: 18),
                onPressed: () => _searchController.clear(),
              )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // ── tab content ───────────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(
              child: CircularProgressIndicator(color: Colors.orange))
              : _hasError
              ? _buildError()
              : TabBarView(
            controller: _tabController,
            children: [
              _buildFollowingTab(),
              _buildFollowersTab(),
              _buildDiscoverTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── following tab ─────────────────────────────────────────────────────────

  Widget _buildFollowingTab() {
    final list = _displayFollowing;

    if (_following.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: "You're not following anyone yet",
        subtitle: 'Head to Discover to find people to follow.',
        action: TextButton(
          onPressed: () => _tabController.animateTo(2),
          child: const Text('Go to Discover',
              style: TextStyle(color: Colors.orange)),
        ),
      );
    }

    if (list.isEmpty) {
      return _buildNoSearchResults();
    }

    return RefreshIndicator(
      color: Colors.orange,
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: list.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey[200]),
        itemBuilder: (context, index) {
          final user = list[index];
          return _userTile(
            user,
            isFollowing: true,
            buttonLabel: 'Unfollow',
            buttonFilled: false,
            onToggle: () => _toggleFollow(user),
          );
        },
      ),
    );
  }

  // ── followers tab ─────────────────────────────────────────────────────────

  Widget _buildFollowersTab() {
    final list = _displayFollowers;

    if (_followers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'No followers yet',
        subtitle: 'Share your recipes to attract followers!',
      );
    }

    if (list.isEmpty) {
      return _buildNoSearchResults();
    }

    return RefreshIndicator(
      color: Colors.orange,
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: list.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey[200]),
        itemBuilder: (context, index) {
          final user = list[index];
          final alreadyFollowing = _followingIds.contains(user.uid);
          return _userTile(
            user,
            isFollowing: alreadyFollowing,
            buttonLabel: alreadyFollowing ? 'Following' : 'Follow back',
            buttonFilled: !alreadyFollowing,
            onToggle: () => _toggleFollow(user),
          );
        },
      ),
    );
  }

  // ── discover tab ──────────────────────────────────────────────────────────

  Widget _buildDiscoverTab() {
    final list = _displayDiscover;

    return RefreshIndicator(
      color: Colors.orange,
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          if (_searchQuery.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Discover People',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Find food lovers to follow',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ),

          if (_discover.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(
                icon: Icons.explore_outlined,
                title: "You're all caught up",
                subtitle:
                "You've followed everyone available. Check back later!",
              ),
            )
          else if (list.isEmpty)
            SliverFillRemaining(child: _buildNoSearchResults())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final user = list[index];
                  return Column(children: [
                    _userTile(
                      user,
                      isFollowing: _followingIds.contains(user.uid),
                      buttonLabel:
                      _followingIds.contains(user.uid) ? 'Following' : 'Follow',
                      buttonFilled: !_followingIds.contains(user.uid),
                      onToggle: () => _toggleFollow(user),
                    ),
                    Divider(height: 1, color: Colors.grey[200]),
                  ]);
                },
                childCount: list.length,
              ),
            ),
        ],
      ),
    );
  }

  // ── shared user tile ──────────────────────────────────────────────────────

  Widget _userTile(
      UserModel user, {
        required bool isFollowing,
        required String buttonLabel,
        required bool buttonFilled,
        required VoidCallback onToggle,
      }) {
    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfilePage(
            userId: user.uid,
            displayName: user.name,
          ),
        ),
      ),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[200],
        backgroundImage:
        user.avatar != null && user.avatar!.isNotEmpty
            ? NetworkImage(user.avatar!)
            : null,
        child: (user.avatar == null || user.avatar!.isEmpty)
            ? Text(
          user.name?.isNotEmpty == true
              ? user.name![0].toUpperCase()
              : '?',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black54),
        )
            : null,
      ),
      title: Text(
        user.name ?? 'User',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: user.username != null
          ? Text('@${user.username}',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]))
          : null,
      trailing: OutlinedButton(
        onPressed: onToggle,
        style: OutlinedButton.styleFrom(
          backgroundColor:
          buttonFilled ? Colors.orange : Colors.transparent,
          side: BorderSide(
              color: buttonFilled ? Colors.orange : Colors.grey[350]!),
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          minimumSize: const Size(90, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          buttonLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: buttonFilled ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[200]),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            if (action != null) ...[const SizedBox(height: 12), action],
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No results for "$_searchQuery"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Try a different name or username.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Could not load data.',
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loadData,
            child: const Text('Retry',
                style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }
}