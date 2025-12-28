import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxibook/main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 當使用者完成引導或點擊跳過時觸發
  Future<void> _onboardingFinished() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (mounted) {
      // 使用 pushReplacement，讓使用者無法返回新手引導頁面
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      icon: Icons.local_taxi,
      title: '歡迎使用司機帳本',
      description: '專為計程車司機設計，輕鬆記錄您的每一筆收入與成本。'
    ),
    OnboardingPageData(
      icon: Icons.add_circle,
      title: '隨時新增行程',
      description: '點擊主畫面的「+」按鈕，快速記錄每趟行程的詳細資訊。'
    ),
    OnboardingPageData(
      icon: Icons.bar_chart,
      title: '洞悉您的財務狀況',
      description: '自動生成專業的日、週、月收入報表，讓財務狀況一目了然。'
    ),
    OnboardingPageData(
      icon: Icons.cloud_upload,
      title: '雲端備份，萬無一失',
      description: '登入帳號即可將您的寶貴資料備份至雲端，更換手機也不怕。'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, index) {
                  return _OnboardingPageContent(data: _pages[index]);
                },
              ),
            ),
            _buildControls(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 底部控制項 (圓點、按鈕)
  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左側「跳過」按鈕
          TextButton(
            onPressed: _onboardingFinished,
            child: const Text('跳過'),
          ),

          // 中間頁面指示器
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (index) => _buildDot(index, context),
            ),
          ),

          // 右側「下一步/完成」按鈕
          FilledButton(
            onPressed: () {
              if (_currentPage < _pages.length - 1) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              } else {
                _onboardingFinished();
              }
            },
            child: Text(_currentPage < _pages.length - 1 ? '下一步' : '開始'),
          ),
        ],
      ),
    );
  }

  // 單個圓點的 UI
  Widget _buildDot(int index, BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 5),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// 用於承載每頁資料的簡單類別
class OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;

  OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });
}

// 單個教學頁面的 UI
class _OnboardingPageContent extends StatelessWidget {
  final OnboardingPageData data;

  const _OnboardingPageContent({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            data.icon,
            size: 120,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 48),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
