import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:taxibook/models/trip.dart';
import 'package:taxibook/screens/add_edit_trip_screen.dart';
import 'package:taxibook/services/database_service.dart';
import 'package:collection/collection.dart';

// --- Modern History Dashboard v3.2 by Gemini ---
// Features: Edit Navigation Enabled, Show Actual Revenue

enum HistoryView { day, week, month }

class HistoryScreen extends StatefulWidget {
  final Function()? onDataUpdated;
  const HistoryScreen({super.key, this.onDataUpdated});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Trip> _allTrips = []; 
  List<Trip> _displayTrips = []; 
  Map<String, List<Trip>> _groupedTrips = {}; 
  
  HistoryView _currentView = HistoryView.day;
  DateTime _selectedDate = DateTime.now(); 

  @override
  void initState() {
    super.initState();
    _initLocale(); 
    loadTrips();
    _searchController.addListener(_updateDisplayData);
  }

  Future<void> _initLocale() async {
    try {
      await initializeDateFormatting('zh_TW', null);
      if (mounted) {
        setState(() => _updateDisplayData());
      }
    } catch (e) {
      debugPrint('Locale initialization failed: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadTrips() async {
    final trips = await _databaseService.getTrips();
    trips.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (mounted) {
      setState(() {
        _allTrips = trips;
        _updateDisplayData();
      });
    }
  }

  void _updateDisplayData() {
    final range = _getDateRange();
    final start = range.start;
    final end = range.end;

    List<Trip> tripsInRange = _allTrips.where((trip) {
      return trip.timestamp.isAfter(start) && trip.timestamp.isBefore(end);
    }).toList();

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      tripsInRange = tripsInRange.where((trip) {
        final fleet = trip.fleetName?.toLowerCase() ?? '';
        final location = trip.pickupLocation?.toLowerCase() ?? '';
        return fleet.contains(query) || location.contains(query);
      }).toList();
    }

    Map<String, List<Trip>> grouped;
    
    if (_currentView == HistoryView.day) {
       String dateKey;
       try {
         dateKey = DateFormat('yyyy/MM/dd').format(_selectedDate);
       } catch (e) {
         dateKey = _selectedDate.toString().split(' ')[0];
       }
       grouped = { dateKey: tripsInRange };
    } else {
      grouped = groupBy(tripsInRange, (trip) {
        try {
          return DateFormat('MM/dd (E)', 'zh_TW').format(trip.timestamp);
        } catch (e) {
          return DateFormat('MM/dd').format(trip.timestamp); 
        }
      });
    }

    setState(() {
      _displayTrips = tripsInRange;
      _groupedTrips = grouped;
    });
  }

  DateTimeRange _getDateRange() {
    final date = _selectedDate;
    DateTime start, end;

    switch (_currentView) {
      case HistoryView.day:
        start = DateTime(date.year, date.month, date.day);
        end = DateTime(date.year, date.month, date.day, 23, 59, 59);
        break;
      case HistoryView.week:
        final monday = date.subtract(Duration(days: date.weekday - 1));
        start = DateTime(monday.year, monday.month, monday.day);
        final sunday = monday.add(const Duration(days: 6));
        end = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);
        break;
      case HistoryView.month:
        start = DateTime(date.year, date.month, 1);
        final lastDay = DateTime(date.year, date.month + 1, 0);
        end = DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59);
        break;
    }
    return DateTimeRange(start: start.subtract(const Duration(milliseconds: 1)), end: end);
  }

  void _navigateDate(int offset) {
    setState(() {
      switch (_currentView) {
        case HistoryView.day:
          _selectedDate = _selectedDate.add(Duration(days: offset));
          break;
        case HistoryView.week:
          _selectedDate = _selectedDate.add(Duration(days: offset * 7));
          break;
        case HistoryView.month:
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + offset, _selectedDate.day);
          break;
      }
      _updateDisplayData();
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('zh', 'TW'),
      builder: (context, child) {
         return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _updateDisplayData();
      });
    }
  }

  String _getDateLabel() {
    try {
      switch (_currentView) {
        case HistoryView.day:
          if (_isSameDay(_selectedDate, DateTime.now())) return '今天';
          return DateFormat('yyyy/MM/dd (E)', 'zh_TW').format(_selectedDate);
        case HistoryView.week:
          final range = _getDateRange();
          final start = range.start.add(const Duration(milliseconds: 1)); 
          final end = range.end;
          return '${DateFormat('MM/dd').format(start)} - ${DateFormat('MM/dd').format(end)}';
        case HistoryView.month:
          return DateFormat('yyyy年 MM月').format(_selectedDate);
      }
    } catch (e) {
      return DateFormat('yyyy/MM/dd').format(_selectedDate);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _navigateToEdit(Trip trip) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditTripScreen(trip: trip),
      ),
    );

    if (result == true) {
      widget.onDataUpdated?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          _buildTopControls(context),
          Expanded(
            child: _displayTrips.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: loadTrips,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _groupedTrips.length,
                      itemBuilder: (context, index) {
                        final key = _groupedTrips.keys.elementAt(index);
                        final trips = _groupedTrips[key]!;
                        return _buildGroup(context, key, trips);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopControls(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜尋本頁行程...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<HistoryView>(
                  segments: const [
                    ButtonSegment(value: HistoryView.day, label: Text('日')),
                    ButtonSegment(value: HistoryView.week, label: Text('週')),
                    ButtonSegment(value: HistoryView.month, label: Text('月')),
                  ],
                  selected: {_currentView},
                  onSelectionChanged: (Set<HistoryView> newSelection) {
                    setState(() {
                      _currentView = newSelection.first;
                      _updateDisplayData();
                    });
                  },
                   style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _navigateDate(-1),
                    visualDensity: VisualDensity.compact,
                  ),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            _getDateLabel(),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _navigateDate(1),
                     visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
               const SizedBox(height: 8),
            ],
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
          Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('此期間無行程紀錄', style: TextStyle(color: Colors.grey[600], fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, String title, List<Trip> trips) {
    final totalRevenue = trips.fold(0.0, (sum, t) => sum + t.actualRevenue);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentView != HistoryView.day) 
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text(
                  '\$${totalRevenue.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
          )
        else 
           Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     const Text("單日實收: ", style: TextStyle(fontWeight: FontWeight.bold)),
                     Text(
                      '\$${totalRevenue.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
           ),
        
        ...trips.map((trip) => _buildTripCard(context, trip)),
      ],
    );
  }

  Widget _buildTripCard(BuildContext context, Trip trip) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 使用 actualRevenue 而不是 fare
    final displayAmount = trip.actualRevenue;
    
    return Dismissible(
      key: Key(trip.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: Colors.red[400], borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
      ),
      confirmDismiss: (_) async {
         return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("刪除行程"),
            content: const Text("確定要刪除這筆行程嗎?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("取消")),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("刪除", style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
      onDismissed: (_) async {
         await _databaseService.deleteTrip(trip.id);
         widget.onDataUpdated?.call();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [if (!isDark) BoxShadow(color: Colors.grey.withAlpha(26), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: InkWell(
          onTap: () => _navigateToEdit(trip),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(DateFormat('HH:mm').format(trip.timestamp), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                     Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: trip.isCash ? Colors.green.withAlpha(26) : Colors.blue.withAlpha(26),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(trip.isCash ? '現金' : '刷卡', style: TextStyle(fontSize: 10, color: trip.isCash ? Colors.green : Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                 const SizedBox(width: 16),
                 Container(height: 40, width: 1, color: Colors.grey.withAlpha(51)),
                 const SizedBox(width: 16),
                 
                 Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.fleetName ?? '個人行程', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      if (trip.pickupLocation != null && trip.pickupLocation!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, size: 12, color: Colors.grey),
                              const SizedBox(width: 2),
                              Expanded(child: Text(trip.pickupLocation!, style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                     Text(
                      '\$${displayAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text('實收', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
