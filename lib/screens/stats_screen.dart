import 'package:flutter/material.dart';
import 'package:taxibook/models/trip.dart';
import 'package:taxibook/services/database_service.dart';

// --- Modern Dashboard Refactor by Gemini ---
// Update: 修正 Hot Reload 導致的型別錯誤，增加防禦性編碼

class TripStats {
  final double totalToday;
  final double totalThisWeek;
  final double totalThisMonth;
  final double totalCash;
  final double totalNonCash;
  final int tripCountToday;
  final Duration operatingHoursToday;
  final double hourlyRateToday;
  final double? avgRevenuePerTripToday; // 改為 nullable 以容錯

  TripStats({
    this.totalToday = 0.0,
    this.totalThisWeek = 0.0,
    this.totalThisMonth = 0.0,
    this.totalCash = 0.0,
    this.totalNonCash = 0.0,
    this.tripCountToday = 0,
    this.operatingHoursToday = Duration.zero,
    this.hourlyRateToday = 0.0,
    this.avgRevenuePerTripToday = 0.0,
  });
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => StatsScreenState();
}

class StatsScreenState extends State<StatsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  late Future<TripStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  void loadStats() {
    setState(() {
      _statsFuture = _calculateStats();
    });
  }

  Future<TripStats> _calculateStats() async {
    final trips = await _databaseService.getTrips();
    final now = DateTime.now();

    double totalToday = 0;
    double totalThisWeek = 0;
    double totalThisMonth = 0;
    double totalCash = 0;
    double totalNonCash = 0;
    int tripCountToday = 0;
    List<Trip> tripsToday = [];

    // 計算本週起始日 (週一為第一天)
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    // 去除時間部分，只比較日期
    final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final endOfWeekDate = startOfWeekDate.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));

    for (final trip in trips) {
      final revenue = trip.actualRevenue;
      
      // 本月
      if (trip.timestamp.year == now.year && trip.timestamp.month == now.month) {
        totalThisMonth += revenue;
      }

      // 本週
      if (trip.timestamp.isAfter(startOfWeekDate.subtract(const Duration(seconds: 1))) && 
          trip.timestamp.isBefore(endOfWeekDate)) {
        totalThisWeek += revenue;
      }
      
      // 今日
      if (trip.timestamp.year == now.year &&
          trip.timestamp.month == now.month &&
          trip.timestamp.day == now.day) {
        totalToday += revenue;
        tripCountToday++;
        tripsToday.add(trip);
        
        // 今日支付方式
        if (trip.isCash) {
          totalCash += revenue;
        } else {
          totalNonCash += revenue;
        }
      }
    }

    Duration operatingHoursToday = Duration.zero;
    double hourlyRateToday = 0.0;
    
    if (tripsToday.length > 1) {
      tripsToday.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final firstTripTime = tripsToday.first.timestamp;
      final lastTripTime = tripsToday.last.timestamp;
      operatingHoursToday = lastTripTime.difference(firstTripTime);
    } else if (tripsToday.length == 1) {
      // 只有一單時，暫時估算為 20分鐘
      operatingHoursToday = const Duration(minutes: 20);
    }

    if (operatingHoursToday.inMinutes > 0) {
        hourlyRateToday = totalToday / (operatingHoursToday.inMinutes / 60.0);
    }

    double avgRevenue = tripCountToday > 0 ? totalToday / tripCountToday : 0.0;

    return TripStats(
      totalToday: totalToday,
      totalThisWeek: totalThisWeek,
      totalThisMonth: totalThisMonth,
      totalCash: totalCash,
      totalNonCash: totalNonCash,
      tripCountToday: tripCountToday,
      operatingHoursToday: operatingHoursToday,
      hourlyRateToday: hourlyRateToday,
      avgRevenuePerTripToday: avgRevenue,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 依據主題調整背景色
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: FutureBuilder<TripStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // 在這裡顯示錯誤，但不崩潰
            return Center(child: Text('載入失敗 (請嘗試重啟 App): ${snapshot.error}'));
          }
          
          final stats = snapshot.data ?? TripStats();

          return RefreshIndicator(
            onRefresh: () async => loadStats(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    '今日概況',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMainRevenueCard(context, stats),
                  const SizedBox(height: 20),
                  Text(
                    '詳細數據',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMetricsGrid(context, stats),
                  const SizedBox(height: 20),
                  _buildPaymentBreakdown(context, stats),
                  const SizedBox(height: 20),
                  _buildPeriodSummary(context, stats),
                  const SizedBox(height: 80), 
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainRevenueCard(BuildContext context, TripStats stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withAlpha(204),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withAlpha(77),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '今日收入',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const Icon(Icons.trending_up, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '\$${stats.totalToday.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '共 ${stats.tripCountToday} 趟行程',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, TripStats stats) {
    // 防禦性處理：如果是舊資料，該欄位可能為 null，給予 0.0
    final avgRev = stats.avgRevenuePerTripToday ?? 0.0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          context,
          '平均時薪',
          '\$${stats.hourlyRateToday.toStringAsFixed(0)}',
          Icons.speed,
          Colors.blue,
        ),
        _buildMetricCard(
          context,
          '每單平均',
          '\$${avgRev.toStringAsFixed(0)}',
          Icons.attach_money,
          Colors.green,
        ),
        _buildMetricCard(
          context,
          '上線時數',
          _formatSimpleDuration(stats.operatingHoursToday),
          Icons.timer_outlined,
          Colors.orange,
        ),
        _buildMetricCard(
          context,
          '行程數',
          '${stats.tripCountToday}',
          Icons.local_taxi,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? [] : [
           BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdown(BuildContext context, TripStats stats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double total = stats.totalToday;
    if (total == 0) total = 1; 
    final cashPct = stats.totalCash / total;
    final nonCashPct = stats.totalNonCash / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
         boxShadow: isDark ? [] : [
           BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '收入結構 (今日)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: ((cashPct * 100).toInt() == 0 && cashPct > 0) ? 1 : (cashPct * 100).toInt(),
                    child: Container(color: Colors.teal),
                  ),
                  Expanded(
                    flex: ((nonCashPct * 100).toInt() == 0 && nonCashPct > 0) ? 1 : (nonCashPct * 100).toInt(),
                    child: Container(color: Colors.orangeAccent),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegend(context, '現金', '\$${stats.totalCash.toStringAsFixed(0)}', Colors.teal, cashPct),
              _buildLegend(context, '非現金', '\$${stats.totalNonCash.toStringAsFixed(0)}', Colors.orangeAccent, nonCashPct),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context, String label, String amount, Color color, double pct) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              '$amount (${(pct * 100).toStringAsFixed(1)}%)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildPeriodSummary(BuildContext context, TripStats stats) {
    return Row(
      children: [
        Expanded(child: _buildSummaryCard(context, '本週累計', stats.totalThisWeek)),
        const SizedBox(width: 16),
        Expanded(child: _buildSummaryCard(context, '本月累計', stats.totalThisMonth)),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, double amount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withAlpha(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            '\$${amount.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatSimpleDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }
}
