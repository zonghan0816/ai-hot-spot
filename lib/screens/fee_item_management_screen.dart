import 'package:flutter/material.dart';
import 'package:taxibook/models/fee_item.dart';
import 'package:taxibook/services/database_service.dart';
import 'add_edit_fee_item_screen.dart';

// --- 大師級 UI/UX 改造 by Gemini (已修正) ---
// 修正：修正了字串中的轉義字元錯誤。

class FeeItemManagementScreen extends StatefulWidget {
  const FeeItemManagementScreen({super.key});

  @override
  State<FeeItemManagementScreen> createState() => _FeeItemManagementScreenState();
}

class _FeeItemManagementScreenState extends State<FeeItemManagementScreen> {
  final DatabaseService _databaseService = DatabaseService();
  late Future<List<FeeItem>> _feeItemsFuture;

  @override
  void initState() {
    super.initState();
    _loadFeeItems();
  }

  void _loadFeeItems() {
    setState(() {
      _feeItemsFuture = _databaseService.getFeeItems();
    });
  }

  void _deleteFeeItem(String id) async {
    await _databaseService.deleteFeeItem(id);
    _loadFeeItems();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('收費項目已刪除'), backgroundColor: Colors.green),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context, FeeItem feeItem) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('確認刪除'),
          content: Text('您確定要刪除 \'${feeItem.name}\' 嗎？'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: Text(
                '刪除',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deleteFeeItem(feeItem.id);
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToAddEditScreen({FeeItem? feeItem}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditFeeItemScreen(feeItem: feeItem),
        fullscreenDialog: true,
      ),
    );
    if (result == true) {
      _loadFeeItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收費項目管理'),
      ),
      body: FutureBuilder<List<FeeItem>>(
        future: _feeItemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }
          return _buildFeeItemList(snapshot.data!); 
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditScreen(),
        tooltip: '新增收費項目',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: theme.disabledColor),
          const SizedBox(height: 24),
          Text(
            '尚未建立任何收費項目',
            style: theme.textTheme.headlineSmall?.copyWith(color: theme.textTheme.bodySmall?.color),
          ),
          const SizedBox(height: 8),
          Text(
            '點擊右下角按鈕新增一個',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.disabledColor),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeeItemList(List<FeeItem> feeItems) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: feeItems.length,
      itemBuilder: (context, index) {
        final item = feeItems[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
            title: Text(item.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '預設金額: \$${item.defaultAmount.toStringAsFixed(0)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  color: theme.colorScheme.secondary,
                  onPressed: () => _navigateToAddEditScreen(feeItem: item),
                  tooltip: '編輯項目',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: theme.colorScheme.error,
                  onPressed: () => _showDeleteConfirmation(context, item),
                  tooltip: '刪除項目',
                ),
              ],
            ),
            onTap: () => _navigateToAddEditScreen(feeItem: item),
          ),
        );
      },
    );
  }
}
