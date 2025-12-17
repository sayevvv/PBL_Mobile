import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_moneyclassification/constants.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchHistory();
  }

  Future<List<Map<String, dynamic>>> _fetchHistory() async {
    final response = await _supabase
        .from('detection_history')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Detection History",
            style: TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
              final formattedDate =
                  DateFormat('dd MMM yyyy, HH:mm').format(date);
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
                    backgroundColor:
                        isNegative ? Colors.grey[200] : kLightColor,
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
      ),
    );
  }
}
