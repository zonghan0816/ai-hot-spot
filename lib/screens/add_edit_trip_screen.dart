import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxibook/models/fleet.dart';
import 'package:taxibook/models/trip.dart';
import 'package:taxibook/services/database_service.dart';
import 'package:uuid/uuid.dart';

class AddEditTripScreen extends StatefulWidget {
  final Trip? trip;

  const AddEditTripScreen({super.key, this.trip});

  @override
  State<AddEditTripScreen> createState() => _AddEditTripScreenState();
}

class _AddEditTripScreenState extends State<AddEditTripScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fareController;
  late TextEditingController _tipController;
  late TextEditingController _commissionController;
  late TextEditingController _locationController;
  late TextEditingController _notesController; // <<< NEW

  final _fareFocusNode = FocusNode();
  final _tipFocusNode = FocusNode();

  String _selectedPaymentType = '現金';
  double _actualIncome = 0.0;
  
  List<Fleet> _fleets = [];
  Fleet? _selectedFleet;
  double _originalCommission = 0.0;

  double? _pickupLatitude;
  double? _pickupLongitude;
  bool _isGpsAcquired = false; // <<< NEW

  final DatabaseService _databaseService = DatabaseService();

  bool get _isEditing => widget.trip != null;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadFleets();
    
    _fareController.addListener(_calculateActualIncome);
    _commissionController.addListener(_calculateActualIncome);
    _tipController.addListener(_calculateActualIncome);

    _fareFocusNode.addListener(() {
      if (_fareFocusNode.hasFocus && _fareController.text == '0') _fareController.clear();
    });
    _tipFocusNode.addListener(() {
      if (_tipFocusNode.hasFocus && _tipController.text == '0') _tipController.clear();
    });
  }

  void _initializeControllers() {
    if (_isEditing) {
      final t = widget.trip!;
      _fareController = TextEditingController(text: t.fare.toStringAsFixed(0));
      _tipController = TextEditingController(text: t.tip.toStringAsFixed(0));
      _commissionController = TextEditingController(text: (t.commission * 100).toStringAsFixed(1));
      _locationController = TextEditingController(text: t.pickupLocation ?? '');
      _notesController = TextEditingController(text: t.notes ?? ''); // <<< NEW
      _selectedPaymentType = t.isCash ? '現金' : '非現金';
      _pickupLatitude = t.pickupLatitude;
      _pickupLongitude = t.pickupLongitude;
      if (_pickupLatitude != null && _pickupLongitude != null && t.pickupLocation == 'GPS') {
        _isGpsAcquired = true;
        _locationController.text = '已取得GPS';
      }
    } else {
      _fareController = TextEditingController(text: '0');
      _tipController = TextEditingController(text: '0');
      _commissionController = TextEditingController(text: '0');
      _locationController = TextEditingController();
      _notesController = TextEditingController(); // <<< NEW
      _loadInitialLocation();
    }
  }
  
  Future<void> _loadInitialLocation() async {
    if (_isEditing) return;
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('last_known_lat');
    final lng = prefs.getDouble('last_known_lng');

    if (lat != null && lng != null) {
      if (mounted) {
        setState(() {
          _isGpsAcquired = true;
          _locationController.text = '已取得GPS';
          _pickupLatitude = lat;
          _pickupLongitude = lng;
        });
        await prefs.remove('last_known_lat'); 
        await prefs.remove('last_known_lng'); 
      }
    }
  }

  void _calculateActualIncome() {
    final fare = double.tryParse(_fareController.text) ?? 0.0;
    final tip = double.tryParse(_tipController.text) ?? 0.0;
    final commissionPercent = double.tryParse(_commissionController.text) ?? 0.0;
    final commissionAmount = fare * (commissionPercent / 100.0);
    setState(() {
      _actualIncome = (fare - commissionAmount) + tip;
    });
  }

  Future<void> _loadFleets() async {
    final fleets = await _databaseService.getFleets();
    if (!mounted) return;
    setState(() {
      _fleets = fleets;
      if (_isEditing) {
        try {
          _selectedFleet = fleets.firstWhere((f) => f.name == widget.trip!.fleetName);
          _originalCommission = _selectedFleet?.defaultCommission ?? 0.0;
        } catch (e) { _selectedFleet = null; }
      } else {
         Fleet? defaultFleet;
         try {
           defaultFleet = fleets.firstWhere((f) => f.isDefault);
         } catch (e) {
           defaultFleet = fleets.isNotEmpty ? fleets.first : null;
         }
         if (defaultFleet != null) _setSelectedFleet(defaultFleet);
      }
      _calculateActualIncome();
    });
  }

  void _setSelectedFleet(Fleet? fleet) {
    setState(() {
      _selectedFleet = fleet;
      _originalCommission = fleet?.defaultCommission ?? 0.0;
      if (fleet != null && fleet.fareTypes.isNotEmpty) {
        if (!_selectedFleet!.fareTypes.contains(_selectedPaymentType)) {
          _selectedPaymentType = _selectedFleet!.fareTypes.first;
        }
      } else {
        _selectedPaymentType = '現金';
      }
      _updateCommissionBasedOnPaymentType();
    });
  }

   void _updateCommissionBasedOnPaymentType() {
    if (_selectedPaymentType == '現金') {
      _commissionController.text = '0';
    } else {
      _commissionController.text = (_originalCommission * 100).toStringAsFixed(1);
    }
    _calculateActualIncome();
  }

  @override
  void dispose() {
    _fareController.dispose();
    _tipController.dispose();
    _commissionController.dispose();
    _locationController.dispose();
    _notesController.dispose(); // <<< NEW
    _fareFocusNode.dispose();
    _tipFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveTrip() async {
     FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final newTrip = Trip(
      id: widget.trip?.id ?? const Uuid().v4(),
      fare: double.tryParse(_fareController.text) ?? 0.0,
      tip: double.tryParse(_tipController.text) ?? 0.0,
      isCash: _selectedPaymentType == '現金',
      timestamp: widget.trip?.timestamp ?? DateTime.now(),
      commission: (double.tryParse(_commissionController.text) ?? 0.0) / 100,
      fleetName: _selectedFleet?.name,
      pickupLocation: _isGpsAcquired ? 'GPS' : _locationController.text, // Store 'GPS' if acquired
      pickupLatitude: _pickupLatitude,
      pickupLongitude: _pickupLongitude,
      notes: _notesController.text, // <<< NEW
    );

    try {
      if (_isEditing) {
        await _databaseService.updateTrip(newTrip);
      } else {
        await _databaseService.insertTrip(newTrip);
        _uploadTripEvent(newTrip);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? '行程已更新' : '行程已儲存'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, _isEditing ? true : 'TRIP_SAVED');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _uploadTripEvent(Trip trip) {
    final lat = trip.pickupLatitude;
    final lng = trip.pickupLongitude;
    final time = trip.timestamp;

    if (lat == null || lng == null) {
      return;
    }

    final Map<String, dynamic> eventData = {
      'latitude': lat,
      'longitude': lng,
      'timestamp': Timestamp.fromDate(time),
    };

    try {
      FirebaseFirestore.instance.collection('trip_events').add(eventData);
    } catch (e) {
      // ignore: avoid_print
      print('Failed to upload trip event: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final bgColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_isEditing ? '編輯行程' : '新增行程'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: isDarkMode ? 0 : 4,
          shadowColor: Colors.black.withAlpha(13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFareDisplay(),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('收費類別', theme),
                  const SizedBox(height: 8),
                  _buildPaymentTypeSelector(theme),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                       Expanded(child: _buildLabeledTextField(_tipController, '小費', theme, focusNode: _tipFocusNode)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildLabeledTextField(_commissionController, '抽成 (%)', theme)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                   _buildSectionTitle('預估實收', theme),
                   const SizedBox(height: 8),
                   _buildActualIncomeDisplay(theme),
                   const SizedBox(height: 24),
                   
                   _buildSectionTitle('車隊與地點 (選填)', theme),
                   const SizedBox(height: 12),
                   _buildFleetDropdown(theme),
                   const SizedBox(height: 16),
                  _buildLocationField(theme),
                  const SizedBox(height: 16),
                  _buildNotesField(theme), // <<< NEW
                  
                  const SizedBox(height: 32),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Omitted Widget Builders for brevity ---
  Widget _buildSectionTitle(String title, ThemeData theme) { return Text( title, style: TextStyle( fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.primary ) ); }
  Widget _buildFareDisplay() { return Column( children: [ Text('車資總額', style: TextStyle(color: Colors.grey[600], fontSize: 14)), TextField( controller: _fareController, focusNode: _fareFocusNode, textAlign: TextAlign.center, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold), keyboardType: TextInputType.number, decoration: const InputDecoration( border: InputBorder.none, prefixText: '\$ ', prefixStyle: TextStyle(fontSize: 24, color: Colors.grey), hintText: '0', ), ), ], ); }
  Widget _buildPaymentTypeSelector(ThemeData theme) { List<String> types = _selectedFleet?.fareTypes.isNotEmpty == true ? _selectedFleet!.fareTypes : ['現金', '非現金']; if (!types.contains(_selectedPaymentType)) { types = [...types, _selectedPaymentType]; } return GridView.count( crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12.0, mainAxisSpacing: 12.0, childAspectRatio: 2.5, children: types.map((type) { final isSelected = _selectedPaymentType == type; return GestureDetector( onTap: () { setState(() { _selectedPaymentType = type; _updateCommissionBasedOnPaymentType(); }); }, child: AnimatedContainer( duration: const Duration(milliseconds: 200), decoration: BoxDecoration( color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest.withAlpha(77), borderRadius: BorderRadius.circular(12), border: isSelected ? null : Border.all(color: Colors.grey.withAlpha(51)), ), alignment: Alignment.center, child: Text( type, style: TextStyle( color: isSelected ? theme.colorScheme.onPrimary : theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.bold, ), ), ), ); }).toList(), ); }
  Widget _buildLabeledTextField(TextEditingController controller, String label, ThemeData theme, {FocusNode? focusNode}) { return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ _buildSectionTitle(label, theme), const SizedBox(height: 8), Container( decoration: BoxDecoration( color: theme.brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(12), ), child: TextField( controller: controller, focusNode: focusNode, textAlign: TextAlign.center, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), decoration: const InputDecoration( border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 16), ), ), ), ], ); }
   Widget _buildFleetDropdown(ThemeData theme) { return Container( padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration( color: theme.brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(12), ), child: DropdownButtonHideUnderline( child: DropdownButton<Fleet>( value: _selectedFleet, isExpanded: true, hint: const Text('選擇一個車隊'), items: _fleets.map((f) => DropdownMenuItem(value: f, child: Text(f.name))).toList(), onChanged: (fleet) => setState(() => _setSelectedFleet(fleet)), ), ), ); }
   
  Widget _buildLocationField(ThemeData theme) {
    bool isReadOnly = _isGpsAcquired;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isReadOnly 
          ? (theme.brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[200])
          : (theme.brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _locationController,
        readOnly: isReadOnly,
        decoration: InputDecoration(
          icon: Icon(Icons.location_on_outlined, color: theme.colorScheme.primary),
          hintText: '上車地點 (選填)',
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildNotesField(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _notesController,
        decoration: InputDecoration(
          icon: Icon(Icons.note_alt_outlined, color: theme.colorScheme.primary),
          hintText: '新增備註 (選填)',
          border: InputBorder.none,
        ),
        maxLines: null, 
      ),
    );
  }

  Widget _buildActualIncomeDisplay(ThemeData theme) { return Container( width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration( gradient: LinearGradient( colors: theme.brightness == Brightness.dark ? [const Color(0xFF2C2C2C), const Color(0xFF1E1E1E)] : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)], begin: Alignment.topLeft, end: Alignment.bottomRight, ), borderRadius: BorderRadius.circular(16), ), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ const Text('預估實收', style: TextStyle(fontWeight: FontWeight.bold)), Text( '\$${_actualIncome.toStringAsFixed(0)}', style: TextStyle( color: theme.brightness == Brightness.dark ? Colors.greenAccent : Colors.green[800], fontSize: 24, fontWeight: FontWeight.bold ) ), ], ), ); }
  Widget _buildActionButtons() { return SizedBox( width: double.infinity, child: FilledButton.icon( onPressed: _saveTrip, icon: Icon(_isEditing ? Icons.update : Icons.save), label: Text(_isEditing ? '更新行程' : '儲存行程'), style: FilledButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), ), ), ); }

}
