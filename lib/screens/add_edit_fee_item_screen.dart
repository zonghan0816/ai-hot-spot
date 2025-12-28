import 'package:flutter/material.dart';
import 'package:taxibook/models/fee_item.dart';
import 'package:taxibook/services/database_service.dart';
import 'package:uuid/uuid.dart';

// --- 大師級 UI/UX 改造 by Gemini (最終章) ---
// 改造重點：
// - 表單欄位與 add_edit_fleet_screen 風格完全統一。
// - 使用分區標題引導使用者，結構更清晰。
// - 採用 Material 3 的 FilledButton 作為主要的儲存按鈕。
// - 確保所有子頁面的設計語言一致，完成本次改造任務。

class AddEditFeeItemScreen extends StatefulWidget {
  final FeeItem? feeItem;

  const AddEditFeeItemScreen({super.key, this.feeItem});

  @override
  State<AddEditFeeItemScreen> createState() => _AddEditFeeItemScreenState();
}

class _AddEditFeeItemScreenState extends State<AddEditFeeItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  final DatabaseService _databaseService = DatabaseService();

  bool get _isEditing => widget.feeItem != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.feeItem?.name ?? '');
    _amountController = TextEditingController(
      text: widget.feeItem != null ? widget.feeItem!.defaultAmount.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveFeeItem() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final amount = double.tryParse(_amountController.text) ?? 0.0;

      final feeItem = FeeItem(
        id: widget.feeItem?.id ?? const Uuid().v4(),
        name: name,
        defaultAmount: amount,
      );

      if (_isEditing) {
        await _databaseService.updateFeeItem(feeItem);
      } else {
        await _databaseService.insertFeeItem(feeItem);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? '項目已更新' : '項目已新增'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '編輯收費項目' : '新增收費項目'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          children: [
            _buildSectionTitle(context, '項目資訊'),
            _buildNameField(),
            const SizedBox(height: 24),
            
            _buildSectionTitle(context, '預設金額'),
            _buildAmountField(),
            const SizedBox(height: 48),

            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: '項目名稱',
        hintText: '例如：過路費、清潔費',
        border: OutlineInputBorder(),
      ),
      validator: (value) => value == null || value.isEmpty ? '請輸入項目名稱' : null,
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      decoration: const InputDecoration(
        labelText: '金額',
        hintText: '例如：50',
        prefixText: '\$',
        border: OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) return '請輸入金額';
        final number = double.tryParse(value);
        if (number == null) return '請輸入有效的數字';
        if (number < 0) return '金額不能為負數';
        return null;
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _saveFeeItem,
        icon: const Icon(Icons.save_alt_outlined),
        label: const Text('儲存項目資料'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
