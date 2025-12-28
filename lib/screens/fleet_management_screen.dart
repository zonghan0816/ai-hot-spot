import 'package:flutter/material.dart';
import 'package:taxibook/models/fleet.dart';
import 'package:taxibook/services/database_service.dart';
import 'add_edit_fleet_screen.dart';

// --- Modern Fleet Management by Gemini ---
// Features: Swipe-to-delete, Modern Cards, Default Badge

class FleetManagementScreen extends StatefulWidget {
  const FleetManagementScreen({super.key});

  @override
  State<FleetManagementScreen> createState() => _FleetManagementScreenState();
}

class _FleetManagementScreenState extends State<FleetManagementScreen> {
  final DatabaseService _databaseService = DatabaseService();
  late Future<List<Fleet>> _fleetsFuture;

  @override
  void initState() {
    super.initState();
    _loadFleets();
  }

  void _loadFleets() {
    setState(() {
      _fleetsFuture = _databaseService.getFleets();
    });
  }

  Future<void> _setDefaultFleet(Fleet fleet) async {
    await _databaseService.setDefaultFleet(fleet.id);
    _loadFleets();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已將 ${fleet.name} 設為預設車隊'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _deleteFleet(Fleet fleet) async {
    await _databaseService.deleteFleet(fleet.id);
    _loadFleets();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${fleet.name} 已刪除'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _navigateToAddEditScreen({Fleet? fleet}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditFleetScreen(fleet: fleet),
        fullscreenDialog: true,
      ),
    );
    if (result == true) {
      _loadFleets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('車隊管理'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: bgColor,
      ),
      body: FutureBuilder<List<Fleet>>(
        future: _fleetsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final fleet = snapshot.data![index];
              return _buildFleetCard(fleet);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_fleet_fab', // Unique Hero Tag added
        onPressed: () => _navigateToAddEditScreen(),
        icon: const Icon(Icons.add),
        label: const Text('新增車隊'),
      ),
    );
  }

  Widget _buildFleetCard(Fleet fleet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dismissible(
      key: Key(fleet.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('刪除車隊'),
            content: Text('確定要刪除 ${fleet.name} 嗎？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('刪除', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
      onDismissed: (_) => _deleteFleet(fleet),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
             if (!isDark)
              BoxShadow(
                color: Colors.grey.withAlpha(26),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: InkWell(
          onTap: () => _navigateToAddEditScreen(fleet: fleet),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withAlpha(102),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.local_taxi, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            fleet.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (fleet.isDefault)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '預設',
                                style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '非現金抽成: ${(fleet.defaultCommission * 100).toStringAsFixed(1)}%',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (!fleet.isDefault)
                  IconButton(
                    icon: const Icon(Icons.star_outline),
                    tooltip: '設為預設',
                    onPressed: () => _setDefaultFleet(fleet),
                  )
                else
                   const IconButton(
                    icon: Icon(Icons.star, color: Colors.orange),
                    onPressed: null, 
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_transfer, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('尚未新增車隊', style: TextStyle(color: Colors.grey[600], fontSize: 18)),
        ],
      ),
    );
  }
}
