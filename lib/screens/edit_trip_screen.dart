import 'package:flutter/material.dart';
import 'package:taxibook/models/trip.dart';
import 'package:taxibook/services/database_service.dart';

class EditTripScreen extends StatefulWidget {
  final Trip trip;

  const EditTripScreen({super.key, required this.trip});

  @override
  State<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends State<EditTripScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fareController;
  late TextEditingController _tipController;
  late TextEditingController _commissionController;
  late TextEditingController _fleetNameController;
  late bool _isCash;
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _fareController = TextEditingController(text: widget.trip.fare.toString());
    _tipController = TextEditingController(text: widget.trip.tip.toString());
    _commissionController = TextEditingController(text: (widget.trip.commission * 100).toString());
    _fleetNameController = TextEditingController(text: widget.trip.fleetName);
    _isCash = widget.trip.isCash;
  }

  @override
  void dispose() {
    _fareController.dispose();
    _tipController.dispose();
    _commissionController.dispose();
    _fleetNameController.dispose();
    super.dispose();
  }

  Future<void> _updateTrip() async {
    if (_formKey.currentState!.validate()) {
      final fare = double.parse(_fareController.text);
      final tip = _tipController.text.isNotEmpty ? double.parse(_tipController.text) : 0.0;
      final commissionPercent = _commissionController.text.isNotEmpty ? double.parse(_commissionController.text) : 0.0;
      final fleetName = _fleetNameController.text.isNotEmpty ? _fleetNameController.text : null;

      final updatedTrip = Trip(
        id: widget.trip.id, // Keep the original ID
        fare: fare,
        tip: tip,
        isCash: _isCash,
        timestamp: widget.trip.timestamp, // Keep the original timestamp
        commission: commissionPercent / 100, // Convert percentage to decimal
        fleetName: fleetName,
      );

      await _databaseService.updateTrip(updatedTrip);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('行程已更新')),
        );
        Navigator.of(context).pop(true); // Pop and signal that an update happened
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('編輯行程'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _fareController,
                decoration: const InputDecoration(
                  labelText: '車資',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return '請輸入車資';
                  if (double.tryParse(value) == null) return '請輸入有效的數字';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tipController,
                decoration: const InputDecoration(
                  labelText: '小費 (選填)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.card_giftcard),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _commissionController,
                decoration: const InputDecoration(
                  labelText: '抽成 (%) (選填)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.percent),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fleetNameController,
                decoration: const InputDecoration(
                  labelText: '車隊名稱 (選填)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group_work),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  const Text('付款方式'),
                  FilterChip(
                    label: const Text('現金'),
                    selected: _isCash,
                    onSelected: (selected) {
                      setState(() { _isCash = true; });
                    },
                  ),
                  FilterChip(
                    label: const Text('非現金'),
                    selected: !_isCash,
                    onSelected: (selected) {
                      setState(() { _isCash = false; });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _updateTrip,
                  icon: const Icon(Icons.save_as),
                  label: const Text('儲存變更'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
