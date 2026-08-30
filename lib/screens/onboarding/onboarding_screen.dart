import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/screens/auth/login_screen.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';
import 'package:tayay_app/utils/tayar_page_route.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      icon: Icons.two_wheeler,
      title: 'أرخص وأسرع في الزحمة',
      subtitle: 'وصل لأي مكان بالدراجة بأقل سعر وفي أقل وقت',
      color: const Color(0xFFFF6B00),
    ),
    _OnboardingPageData(
      icon: Icons.handshake,
      title: 'اختار السعر اللي يناسبك',
      subtitle: 'مفاوضة حرة بينك وبين الطيار، مفيش سعر ثابت يفرض عليك',
      color: const Color(0xFF4CAF50),
    ),
    _OnboardingPageData(
      icon: Icons.delivery_dining,
      title: 'توصيل طلباتك من أي مكان',
      subtitle: 'مطاعم، صيدليات، مستندات، أي حاجة تقدر تطلبها',
      color: const Color(0xFF2196F3),
    ),
    _OnboardingPageData(
      icon: Icons.shield,
      title: 'رحلات آمنة',
      subtitle: 'زرار SOS للطوارئ ومشاركة موقع الرحلة لحظة بلحظة',
      color: const Color(0xFFE91E63),
    ),
  ];

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      TayarPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _finishOnboarding,
                  child: Text(
                    'تخطي',
                    style: TextStyle(
                      color: TayarColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) =>
                    _buildPage(_pages[index], context.textColor),
              ),
            ),

            // Bottom section
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Page indicator
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _pages.length,
                    effect: WormEffect(
                      dotWidth: 10,
                      dotHeight: 10,
                      activeDotColor: TayarColors.primary,
                      dotColor: context.dividerColor2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Next / Start button
                  SizedBox(
                    width: double.infinity,
                    child: AppPrimaryButton(
                      onPressed: _onNext,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.large,
                      child: Text(
                        _currentPage < _pages.length - 1 ? 'التالي' : 'ابدأ الآن',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPageData page, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon container
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 64,
              color: page.color,
            ),
          ),
          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: textColor.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}