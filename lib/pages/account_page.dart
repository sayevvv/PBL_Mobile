import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_moneyclassification/constants.dart';
import 'package:intl/intl.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _historyFuture;
  User? _user;
  late TabController _tabController;
  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _user = _supabase.auth.currentUser;
    _isGuest = _user == null;

    if (!_isGuest) {
      _historyFuture = _fetchHistory();
    } else {
      // Dummy future for guest (resolves to empty list)
      _historyFuture = Future.value([]);
    }

    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchHistory() async {
    final response = await _supabase
        .from('detection_history')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _signOutOrSignIn() async {
    if (!_isGuest) {
      await _supabase.auth.signOut();
    }
    // For both Guest (Sign In) and User (Sign Out), go to Onboarding
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/onboarding', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Account", style: TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // User Profile Section
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: kLightColor,
                  child: Icon(
                    _isGuest ? Icons.person_outline : Icons.person,
                    size: 40,
                    color: kPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _user?.email ?? 'Guest User',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _signOutOrSignIn,
                  icon: Icon(
                    _isGuest ? Icons.login : Icons.logout,
                    size: 18,
                  ),
                  label: Text(_isGuest ? "Sign In" : "Sign Out"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isGuest ? kPrimaryColor : Colors.red,
                    side: BorderSide(
                        color: _isGuest ? kPrimaryColor : Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: kPrimaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: kPrimaryColor,
            tabs: const [
              Tab(text: "History"),
              Tab(text: "Settings"),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // History Tab
                _isGuest
                    ? _buildGuestHistoryPlaceholder()
                    : _buildHistoryList(),
                // Settings Tab
                const Center(child: Text("Settings coming soon...")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestHistoryPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_toggle_off, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            "History not available",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Sign in to save your detection history.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _signOutOrSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text("Sign In"),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: kPrimaryColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data;
        if (data == null || data.isEmpty) {
          return const Center(child: Text("No history found"));
        }

        return ListView.builder(
          itemCount: data.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final item = data[index];
            final date = DateTime.parse(item['created_at']).toLocal();
            final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(date);
            final isNegative = item['is_negative'] ?? false;
            final prediction = item['prediction_result'] ?? "Unknown";
            final model = item['model_used'] ?? "Unknown";

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: kLightColor, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isNegative ? Colors.grey[200] : kLightColor,
                  child: Icon(
                    isNegative
                        ? Icons.highlight_off
                        : Icons.check_circle_outline,
                    color: kPrimaryColor,
                  ),
                ),
                title: Text(
                  isNegative ? "Not Money" : "Rp $prediction",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor,
                  ),
                ),
                subtitle: Text("$formattedDate • $model"),
              ),
            );
          },
        );
      },
    );
  }
}
