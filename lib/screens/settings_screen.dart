import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxibook/main.dart';
import 'package:taxibook/providers/auth_provider.dart';
import 'package:taxibook/providers/theme_provider.dart';
import 'package:taxibook/services/auth_service.dart';
import 'package:taxibook/services/cloud_backup_service.dart';
import 'package:taxibook/services/database_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'fleet_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  bool _isSyncing = false;
  bool _isAiListView = false;

  late TabController _tabController;
  final _registerFormKey = GlobalKey<FormState>();
  final _loginFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _loginEmailController = TextEditingController();

  final _dailyGoalController = TextEditingController();
  final _weeklyGoalController = TextEditingController();
  final _monthlyGoalController = TextEditingController();

  final _dailyGoalFocus = FocusNode();
  final _weeklyGoalFocus = FocusNode();
  final _monthlyGoalFocus = FocusNode();

  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
    _dailyGoalController.addListener(_onDailyGoalChanged);
    _weeklyGoalController.addListener(_onWeeklyGoalChanged);
    _monthlyGoalController.addListener(_onMonthlyGoalChanged);

    _dailyGoalFocus.addListener(() => _handleFocusClear(_dailyGoalFocus, _dailyGoalController));
    _weeklyGoalFocus.addListener(() => _handleFocusClear(_weeklyGoalFocus, _weeklyGoalController));
    _monthlyGoalFocus.addListener(() => _handleFocusClear(_monthlyGoalFocus, _monthlyGoalController));
  }

  void _handleFocusClear(FocusNode node, TextEditingController controller) {
    if (node.hasFocus && controller.text == '0') {
      controller.clear();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _registerEmailController.dispose();
    _loginEmailController.dispose();
    _dailyGoalController.dispose();
    _weeklyGoalController.dispose();
    _monthlyGoalController.dispose();
    _dailyGoalFocus.dispose();
    _weeklyGoalFocus.dispose();
    _monthlyGoalFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isAiListView = prefs.getBool('ai_list_mode') ?? false;

    String? dailyStr = await _databaseService.getSetting('dailyGoal');
    String? weeklyStr = await _databaseService.getSetting('weeklyGoal');
    String? monthlyStr = await _databaseService.getSetting('monthlyGoal');

    if (dailyStr == null) {
      final dailyVal = prefs.getDouble('dailyGoal') ?? 0;
      dailyStr = dailyVal.toStringAsFixed(0);
      weeklyStr = (prefs.getDouble('weeklyGoal') ?? 0).toStringAsFixed(0);
      monthlyStr = (prefs.getDouble('monthlyGoal') ?? 0).toStringAsFixed(0);
      if (dailyVal > 0) _saveGoalsToDB(dailyStr, weeklyStr, monthlyStr);
    }

    if (mounted) {
      setState(() {
        _isAiListView = isAiListView;
        _dailyGoalController.text = dailyStr!;
        _weeklyGoalController.text = weeklyStr ?? '0';
        _monthlyGoalController.text = monthlyStr ?? '0';
      });
    }
  }
  
  Future<void> _manualRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    final authProvider = context.read<AuthProvider>();
    await authProvider.signInManually(
      name: _nameController.text,
      phone: _phoneController.text,
      email: _registerEmailController.text,
    );
  }

  Future<void> _manualLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    final authProvider = context.read<AuthProvider>();
    // In a real app, this would query a backend. Here, we simulate by trusting the user's input.
    await authProvider.signInManually(
      name: '', // Name and phone are not known at login
      phone: '',
      email: _loginEmailController.text,
    );
  }


  Future<void> _saveAiListModePreference(bool value) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('ai_list_mode', value); setState(() { _isAiListView = value; }); }
  void _onDailyGoalChanged() { if (!_dailyGoalFocus.hasFocus) return; final dailyGoal = double.tryParse(_dailyGoalController.text) ?? 0; _updateGoalText(_weeklyGoalController, dailyGoal * 7); _updateGoalText(_monthlyGoalController, dailyGoal * 30); _saveGoals(); }
  void _onWeeklyGoalChanged() { if (!_weeklyGoalFocus.hasFocus) return; final weeklyGoal = double.tryParse(_weeklyGoalController.text) ?? 0; final dailyGoal = weeklyGoal / 7; _updateGoalText(_dailyGoalController, dailyGoal); _updateGoalText(_monthlyGoalController, dailyGoal * 30); _saveGoals(); }
  void _onMonthlyGoalChanged() { if (!_monthlyGoalFocus.hasFocus) return; final monthlyGoal = double.tryParse(_monthlyGoalController.text) ?? 0; final dailyGoal = monthlyGoal / 30; _updateGoalText(_dailyGoalController, dailyGoal); _updateGoalText(_weeklyGoalController, dailyGoal * 7); _saveGoals(); }
  void _updateGoalText(TextEditingController controller, double value) { final textValue = value.toStringAsFixed(0); if (controller.text != textValue) { controller.text = textValue; } }
  Future<void> _saveGoals() async { final daily = _dailyGoalController.text; final weekly = _weeklyGoalController.text; final monthly = _monthlyGoalController.text; await _saveGoalsToDB(daily, weekly, monthly); }
  Future<void> _saveGoalsToDB(String daily, String weekly, String monthly) async { await _databaseService.setSetting('dailyGoal', daily); await _databaseService.setSetting('weeklyGoal', weekly); await _databaseService.setSetting('monthlyGoal', monthly); }
  Future<void> _sendFeedbackEmail() async { const String recipientEmail = 'your.email@example.com'; final packageInfo = await PackageInfo.fromPlatform(); final appName = packageInfo.appName; final appVersion = packageInfo.version; final buildNumber = packageInfo.buildNumber; String? device, osVersion; final deviceInfo = DeviceInfoPlugin(); if (Platform.isAndroid) { final androidInfo = await deviceInfo.androidInfo; device = "${androidInfo.manufacturer} ${androidInfo.model}"; osVersion = "Android ${androidInfo.version.release}"; } else if (Platform.isIOS) { final iosInfo = await deviceInfo.iosInfo; device = iosInfo.name; osVersion = "${iosInfo.systemName} ${iosInfo.systemVersion}"; } final String subject = Uri.encodeComponent('$appName 問題回報 ($appVersion)'); final String body = Uri.encodeComponent('''\n\n\n--- 請在此線上說明您的問題 ---\n\n\n\n\n--- 自動附加資訊，請勿刪除 ---\nApp 版本: $appVersion ($buildNumber)\n設備: $device\n作業系統: $osVersion\n'''); final Uri mailtoUri = Uri.parse('mailto:$recipientEmail?subject=$subject&body=$body'); if (await canLaunchUrl(mailtoUri)) { await launchUrl(mailtoUri); } else { if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('無法開啟郵件應用程式，請確認手機上是否已安裝。')), ); } } }
  void _performBackup(CloudBackupService backupService, AuthProvider authProvider) async { if (authProvider.status != AuthStatus.authenticated) { _showLoginPrompt(context); return; } await _saveGoals(); setState(() => _isSyncing = true); final status = await backupService.backupDatabase(); setState(() => _isSyncing = false); if (!mounted) return; final message = switch (status) { CloudBackupStatus.success => '資料備份成功！', CloudBackupStatus.error => '備份失敗，請稍後再試。', _ => '發生未知錯誤。', }; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); }
  void _confirmAndRestore(CloudBackupService backupService, AuthProvider authProvider) { if (authProvider.status != AuthStatus.authenticated) { _showLoginPrompt(context); return; } showDialog( context: context, builder: (dialogContext) => AlertDialog( title: const Text('警告'), content: const Text('還原資料將覆寫本機所有紀錄，確定要繼續嗎？'), actions: [ TextButton(child: const Text('取消'), onPressed: () => Navigator.of(dialogContext).pop()), TextButton( child: Text('還原', style: TextStyle(color: Theme.of(context).colorScheme.error)), onPressed: () { Navigator.of(dialogContext).pop(); _performRestore(backupService); }, ), ], ), ); }
  void _performRestore(CloudBackupService backupService) async { setState(() => _isSyncing = true); final status = await backupService.restoreDatabase(); setState(() => _isSyncing = false); if (!mounted) return; if (status == CloudBackupStatus.success) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('資料還原成功！正在重新載入...'))); Future.delayed(const Duration(seconds: 1), () { if (mounted) { Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const AuthWrapper()), (Route<dynamic> route) => false, ); } }); } else { final message = switch (status) { CloudBackupStatus.noBackupFound => '找不到備份檔案。', CloudBackupStatus.error => '還原失敗。', _ => '發生未知錯誤。', }; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); } }
  void _showLoginPrompt(BuildContext context) { showDialog( context: context, builder: (context) => AlertDialog( title: const Text('需要登入'), content: const Text('雲端同步功能需要登入帳號才能使用。'), actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
 FilledButton(onPressed: () { Navigator.pop(context); Provider.of<AuthProvider>(context, listen: false).signInWithGoogle(); }, child: const Text('以 Google 登入')), ], ), ); }
  void _showSignOutConfirmation(BuildContext context, AuthProvider authProvider) { showDialog( context: context, builder: (context) => AlertDialog( title: const Text('登出'), content: const Text('確定要登出目前的帳號嗎？'), actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')), TextButton( onPressed: () { Navigator.pop(context); authProvider.signOut(); }, child: const Text('登出', style: TextStyle(color: Colors.red)) ), ], ), ); }
  void _showClearDataDialog(BuildContext context) { showDialog( context: context, builder: (dialogContext) => AlertDialog( title: const Text('清除所有資料'), content: const Text('這將刪除所有行程、車隊、設定與備份目標，還原至初始狀態。確定嗎？'), actions: [ TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')), TextButton( onPressed: () async { await DatabaseService().clearAllData(); final prefs = await SharedPreferences.getInstance(); await prefs.clear(); if (!dialogContext.mounted) return; Navigator.pop(dialogContext); if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('資料已清除，正在重新啟動...'))); Future.delayed(const Duration(milliseconds: 500), () { if (context.mounted) { Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const AuthWrapper()), (Route<dynamic> route) => false, ); } }); } }, child: const Text('清除', style: TextStyle(color: Colors.red)) ), ], ), ); }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final authService = AuthService();
    final backupService = CloudBackupService(authService.googleSignInInstance);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              _buildAuthSection(context, authProvider),
              const SizedBox(height: 20),
              _buildSectionTitle(context, '營業目標'),
              _buildBusinessGoalsCard(context),
              _buildSectionTitle(context, '管理'),
              _buildSettingsCard(context, [
                _buildTile(context, Icons.local_taxi, '車隊管理', '設定車隊名稱與抽成', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FleetManagementScreen()))),
                _buildAiModeTile(context),
                _buildTile(context, Icons.palette_outlined, '外觀模式', _themeModeToString(context.watch<ThemeProvider>().themeMode), onTap: () => _showThemeDialog(context)),
              ]),
              _buildSectionTitle(context, '雲端同步'),
              _buildSettingsCard(context, [
                _buildTile(context, Icons.cloud_upload_outlined, '備份資料', '上傳目前資料到 Google Drive', onTap: () => _performBackup(backupService, authProvider)),
                _buildTile(context, Icons.cloud_download_outlined, '還原資料', '從 Google Drive 下載備份', onTap: () => _confirmAndRestore(backupService, authProvider)),
              ]),
              _buildSectionTitle(context, '支援'),
              _buildSettingsCard(context, [
                _buildTile(context, Icons.email_outlined, '問題回報與建議', '透過電子郵件聯絡開發者', onTap: _sendFeedbackEmail),
              ]),
              _buildSectionTitle(context, '進階'),
              _buildSettingsCard(context, [
                 if (kDebugMode)
                  _buildTile(context, Icons.bug_report, '測試閃退 (開發用)', '驗證 Crashlytics 整合', isDestructive: true, onTap: () => FirebaseCrashlytics.instance.crash()),
                 _buildTile(context, Icons.delete_forever_outlined, '清除本機資料', '刪除手機內所有行程紀錄', isDestructive: true, onTap: () => _showClearDataDialog(context)),
                if (authProvider.status == AuthStatus.authenticated)
                  _buildTile(context, Icons.logout, '登出帳號', (authProvider.isManualLogin ? authProvider.manualUserEmail : authProvider.user?.email) ?? '', isDestructive: true, onTap: () => _showSignOutConfirmation(context, authProvider)),
              ]),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Version 1.0.0', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ),
              ),
            ],
          ),
          if (_isSyncing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [CircularProgressIndicator(color: Colors.white), SizedBox(height: 16), Text('同步中...', style: TextStyle(color: Colors.white))],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiModeTile(BuildContext context) { return SwitchListTile( secondary: Container( padding: const EdgeInsets.all(8), decoration: BoxDecoration( color: Theme.of(context).colorScheme.primary.withAlpha(26), borderRadius: BorderRadius.circular(10), ), child: Icon(Icons.auto_awesome_outlined, color: Theme.of(context).colorScheme.primary, size: 20), ), title: const Text('AI推薦列表模式', style: TextStyle(fontWeight: FontWeight.w600)), subtitle: const Text('開啟後，AI 熱點推薦頁面將預設顯示多個選項', style: TextStyle(fontSize: 12, color: Colors.grey)), value: _isAiListView, onChanged: (bool value) { _saveAiListModePreference(value); }, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), ); }

  Widget _buildAuthSection(BuildContext context, AuthProvider authProvider) {
    final bool isAuthenticated = authProvider.status == AuthStatus.authenticated;

    if (isAuthenticated) {
      final user = authProvider.user;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            if (!authProvider.isManualLogin && user?.photoURL != null)
              CircleAvatar(radius: 32, backgroundImage: NetworkImage(user!.photoURL!))
            else
              CircleAvatar(radius: 32, backgroundColor: Colors.grey[200], child: Icon(authProvider.isManualLogin ? Icons.person : Icons.no_accounts, size: 32, color: Colors.grey)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(authProvider.isManualLogin ? (authProvider.manualUserName ?? '訪客') : (user?.displayName ?? '運將大哥'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(authProvider.isManualLogin ? (authProvider.manualUserEmail ?? '') : (user?.email ?? ''), style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            const SizedBox(height: 50),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '註冊'),
                Tab(text: '登入'),
              ],
            ),
            SizedBox(
              height: 400, // This fixed height is the problem
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRegisterForm(context),
                  _buildLoginForm(context),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
  
  Widget _buildRegisterForm(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: '姓名'), validator: (v) => v!.isEmpty ? '請輸入姓名' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: '手機'), keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            TextFormField(controller: _registerEmailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty || !v.contains('@') ? '請輸入有效的Email' : null),
            const SizedBox(height: 24),
            FilledButton(onPressed: _manualRegister, child: const Text('註冊')),
            const SizedBox(height: 12),
            const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('或')), Expanded(child: Divider())]),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () => authProvider.signInWithGoogle(), icon: const Icon(Icons.g_mobiledata), label: const Text('以 Google 註冊')),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLoginForm(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(controller: _loginEmailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty || !v.contains('@') ? '請輸入您的Email' : null),
            const SizedBox(height: 24),
            FilledButton(onPressed: _manualLogin, child: const Text('登入')),
             const SizedBox(height: 12),
            const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('或')), Expanded(child: Divider())]),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () => authProvider.signInWithGoogle(), icon: const Icon(Icons.g_mobiledata), label: const Text('以 Google 登入')),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) { return Padding( padding: const EdgeInsets.fromLTRB(24, 16, 24, 8), child: Text( title, style: TextStyle( fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, ), ), ); }
  Widget _buildSettingsCard(BuildContext context, List<Widget> children) { final isDark = Theme.of(context).brightness == Brightness.dark; return Container( margin: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration( color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: isDark ? [] : [ BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4)) ], ), child: Column( children: children.asMap().entries.map((entry) { final index = entry.key; final widget = entry.value; return Column( children: [ widget, if (index < children.length - 1) Divider(height: 1, indent: 60, color: Colors.grey.withAlpha(26)), ], ); }).toList(), ), ); }
  Widget _buildBusinessGoalsCard(BuildContext context) { final isDark = Theme.of(context).brightness == Brightness.dark; return Container( margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(20), decoration: BoxDecoration( gradient: LinearGradient( colors: isDark ? [const Color(0xFF2C2C2C), const Color(0xFF1E1E1E)] : [const Color(0xFFFFF8E1), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight, ), borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(51)), ), child: Column( children: [ _buildGoalRow(context, '日目標', _dailyGoalController, _dailyGoalFocus), const SizedBox(height: 12), _buildGoalRow(context, '週目標', _weeklyGoalController, _weeklyGoalFocus), const SizedBox(height: 12), _buildGoalRow(context, '月目標', _monthlyGoalController, _monthlyGoalFocus), ], ), ); }
  Widget _buildGoalRow(BuildContext context, String label, TextEditingController controller, FocusNode focus) { return Row( children: [ SizedBox( width: 60, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)), ), Expanded( child: Container( height: 40, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration( color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(10), ), child: Row( children: [ const Text('\$', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 8), Expanded( child: TextField( controller: controller, focusNode: focus, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, isDense: true), style: const TextStyle(fontWeight: FontWeight.bold), ), ), ], ), ), ), ], ); }
  Widget _buildTile(BuildContext context, IconData icon, String title, String subtitle, {VoidCallback? onTap, bool isDestructive = false}) { return ListTile( leading: Container( padding: const EdgeInsets.all(8), decoration: BoxDecoration( color: isDestructive ? Colors.red.withAlpha(26) : Theme.of(context).colorScheme.primary.withAlpha(26), borderRadius: BorderRadius.circular(10), ), child: Icon(icon, color: isDestructive ? Colors.red : Theme.of(context).colorScheme.primary, size: 20), ), title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDestructive ? Colors.red : null)), subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)), trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey), onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), ); }
  String _themeModeToString(ThemeMode mode) { switch (mode) { case ThemeMode.light: return '淺色模式'; case ThemeMode.dark: return '深色模式'; default: return '跟隨系統'; } }
  void _showThemeDialog(BuildContext context) { showDialog( context: context, builder: (BuildContext dialogContext) { final themeProvider = Provider.of<ThemeProvider>(context, listen: false); return SimpleDialog( title: const Text('選擇外觀'), children: <Widget>[ RadioListTile<ThemeMode>(title: const Text('淺色'), value: ThemeMode.light, groupValue: themeProvider.themeMode, onChanged: (v) { themeProvider.setThemeMode(v!); Navigator.pop(dialogContext); }), RadioListTile<ThemeMode>(title: const Text('深色'), value: ThemeMode.dark, groupValue: themeProvider.themeMode, onChanged: (v) { themeProvider.setThemeMode(v!); Navigator.pop(dialogContext); }), RadioListTile<ThemeMode>(title: const Text('跟隨系統'), value: ThemeMode.system, groupValue: themeProvider.themeMode, onChanged: (v) { themeProvider.setThemeMode(v!); Navigator.pop(dialogContext); }), ], ); }, ); }
}
