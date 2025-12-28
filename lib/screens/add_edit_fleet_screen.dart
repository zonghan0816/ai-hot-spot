import 'package:flutter/material.dart';
import 'package:taxibook/models/fleet.dart';
import 'package:taxibook/services/database_service.dart';
import 'package:uuid/uuid.dart';

// --- Modern Add/Edit Fleet Screen v2 by Gemini ---
// Features: Auto-clear '0.0' on focus for commission

class AddEditFleetScreen extends StatefulWidget {
  final Fleet? fleet;

  const AddEditFleetScreen({super.key, this.fleet});

  @override
  State<AddEditFleetScreen> createState() => _AddEditFleetScreenState();
}

class _AddEditFleetScreenState extends State<AddEditFleetScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _commissionController;
  late Set<FleetType> _selectedType;
  
  final FocusNode _commissionFocus = FocusNode();

  final List<String> _defaultFareTypes = ['現金', '非現金'];
  final List<String> _availableFareTypes = ['現金', '非現金'];
  final Set<String> _selectedFareTypes = {};

  final DatabaseService _databaseService = DatabaseService();
  double _sliderValue = 0.0;

  bool get _isEditing => widget.fleet != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.fleet?.name ?? '');
    
    double initialCommission = widget.fleet != null ? widget.fleet!.defaultCommission * 100 : 0.0;
    _commissionController = TextEditingController(text: initialCommission.toStringAsFixed(1));
    _sliderValue = initialCommission;

    _selectedType = {widget.fleet?.type ?? FleetType.diverse};

    if (_isEditing && widget.fleet!.fareTypes.isNotEmpty) {
      _selectedFareTypes.addAll(widget.fleet!.fareTypes);
      for (var type in widget.fleet!.fareTypes) {
        if (!_availableFareTypes.contains(type)) {
          _availableFareTypes.add(type);
        }
      }
    } else if (!_isEditing) {
      _selectedFareTypes.addAll(['現金', '非現金']);
    }

    _commissionController.addListener(() {
      final val = double.tryParse(_commissionController.text);
      if (val != null && val >= 0 && val <= 100) {
        setState(() {
          _sliderValue = val;
        });
      }
    });

    // Auto-clear logic
    _commissionFocus.addListener(() {
      if (_commissionFocus.hasFocus) {
        final text = _commissionController.text;
        if (text == '0' || text == '0.0') {
          _commissionController.clear();
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commissionController.dispose();
    _commissionFocus.dispose();
    super.dispose();
  }

  Future<void> _saveFleet() async {
    FocusScope.of(context).unfocus();

    if (_selectedFareTypes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請至少選擇一個車資類別'), backgroundColor: Colors.red),
        );
        return;
    }

    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final commissionPercent = double.tryParse(_commissionController.text) ?? 0.0;

      final fleet = Fleet(
        id: widget.fleet?.id ?? const Uuid().v4(),
        name: name,
        type: _selectedType.first,
        defaultCommission: commissionPercent / 100.0,
        fareTypes: _selectedFareTypes.toList(),
      );

      if (_isEditing) {
        await _databaseService.updateFleet(fleet);
      } else {
        await _databaseService.insertFleet(fleet);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? '車隊資料已更新' : '成功新增車隊'), behavior: SnackBarBehavior.floating),
        );
        Navigator.of(context).pop(true);
      }
    }
  }

  void _showAddFareTypeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新增車資類別'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '例如：悠遊卡、企業簽單',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final newType = controller.text.trim();
                if (newType.isNotEmpty && !_availableFareTypes.contains(newType)) {
                  setState(() {
                    _availableFareTypes.add(newType);
                    _selectedFareTypes.add(newType);
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('新增'),
            ),
          ],
        );
      },
    );
  }

  void _removeFareType(String type) {
      if (_availableFareTypes.length <= 1) {
           ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('必須保留至少一個車資類別'), backgroundColor: Colors.red),
            );
          return;
      }
      setState(() {
          _availableFareTypes.remove(type);
          _selectedFareTypes.remove(type);
      });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          children: [
            _buildHeader(context),
            const SizedBox(height: 32),
            
            _buildNameField(context),
            const SizedBox(height: 24),
            
            _buildSectionLabel(context, '車隊類型'),
            const SizedBox(height: 8),
            _buildTypeSelector(context),
            const SizedBox(height: 24),

            _buildSectionLabel(context, '預設非現金抽成'),
            const SizedBox(height: 8),
            _buildCommissionCard(context),
            const SizedBox(height: 24),

            _buildSectionLabel(context, '支援車資類別'),
            const SizedBox(height: 8),
            _buildFareTypeSelector(context),
            
            const SizedBox(height: 100), // Bottom padding for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_edit_fleet_fab', // Unique Hero Tag
        onPressed: _saveFleet,
        icon: const Icon(Icons.check),
        label: const Text('儲存設定'),
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            _isEditing ? Icons.edit_note : Icons.add_business,
            size: 32,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isEditing ? '編輯車隊資料' : '新增車隊',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '設定車隊名稱與預設抽成比例',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildNameField(BuildContext context) {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: '車隊名稱',
        hintText: '例如：Uber, 台灣大車隊',
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        prefixIcon: const Icon(Icons.business),
      ),
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      validator: (value) => value == null || value.isEmpty ? '請輸入車隊名稱' : null,
    );
  }

  Widget _buildTypeSelector(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<FleetType>(
        segments: const <ButtonSegment<FleetType>>[
          ButtonSegment(value: FleetType.diverse, label: Text('多元計程車'), icon: Icon(Icons.local_taxi)),
          ButtonSegment(value: FleetType.regular, label: Text('小黃計程車'), icon: Icon(Icons.hail)),
        ],
        selected: _selectedType,
        onSelectionChanged: (Set<FleetType> newSelection) {
          setState(() {
            _selectedType = newSelection;
          });
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.comfortable,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ),
    );
  }

  Widget _buildCommissionCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.withAlpha(26), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('抽成比例', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                width: 100,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _commissionController,
                  focusNode: _commissionFocus, // Attach FocusNode
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    suffixText: '%',
                    suffixStyle: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Theme.of(context).colorScheme.primary,
              thumbColor: Theme.of(context).colorScheme.primary,
              trackHeight: 6.0,
            ),
            child: Slider(
              value: _sliderValue,
              min: 0,
              max: 30, // Assuming taxi commission rarely exceeds 30%
              divisions: 60, // 0.5 steps
              label: '${_sliderValue.toStringAsFixed(1)}%',
              onChanged: (value) {
                setState(() {
                  _sliderValue = value;
                  _commissionController.text = value.toStringAsFixed(1);
                });
              },
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0%', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('15%', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('30%', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareTypeSelector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.withAlpha(26), blurRadius: 10)],
      ),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 12.0,
        children: [
          ..._availableFareTypes.map((type) {
            final isDefaultType = _defaultFareTypes.contains(type);
            final isSelected = _selectedFareTypes.contains(type);
            return FilterChip(
              label: Text(type),
              selected: isSelected,
              showCheckmark: false,
              avatar: isSelected ? const Icon(Icons.check, size: 18) : null,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    _selectedFareTypes.add(type);
                  } else {
                    if (_selectedFareTypes.length > 1) {
                       _selectedFareTypes.remove(type);
                    } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('至少需保留一種'), duration: Duration(seconds: 1)),
                        );
                    }
                  }
                });
              },
              onDeleted: isDefaultType ? null : () => _removeFareType(type),
              deleteIcon: const Icon(Icons.close, size: 16),
            );
          }),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('新增'),
            onPressed: _showAddFareTypeDialog,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
            side: BorderSide.none,
          ),
        ],
      ),
    );
  }
}
