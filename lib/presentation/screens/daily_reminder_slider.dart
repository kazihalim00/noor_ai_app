import 'dart:async';
import 'package:flutter/material.dart';

class DailyReminderSlider extends StatefulWidget {
  const DailyReminderSlider({super.key});

  @override
  State<DailyReminderSlider> createState() => _DailyReminderSliderState();
}

class _DailyReminderSliderState extends State<DailyReminderSlider> {
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;

  final List<String> _reminders = [
    "✨ দৃষ্টি অবনত রাখুন: 'মুমিনদেরকে বলুন, তারা যেন তাদের দৃষ্টি নত রাখে এবং তাদের লজ্জাস্থানের হেফাজত করে।' (সূরা আন-নূর: ৩০)",
    "✨ গীবত থেকে বেঁচে থাকুন: 'তোমাদের কেউ যেন কারও গীবত না করে। তোমাদের কেউ কি তার মৃত ভাইয়ের গোশত খেতে পছন্দ করবে?' (সূরা আল-হুজুরাত: ১২)",
    "✨ জবান হেফাজত করুন: রাসূলুল্লাহ (সা.) বলেছেন, 'যে ব্যক্তি চুপ থাকে, সে নাজাত পায় বা মুক্তি পায়।' (সুনান আত-তিরমিযী: ২৫০১)",
    "✨ রাগ নিয়ন্ত্রণ করুন: রাসূল (সা.) বলেছেন, 'প্রকৃত বীর সে নয় যে কুস্তিতে জয়ী হয়, বরং বীর সে, যে রাগের সময় নিজেকে নিয়ন্ত্রণ করতে পারে।' (সহীহ বুখারী: ৬১১৪)",
    "✨ অহংকার পতনের মূল: 'যার অন্তরে অণু পরিমাণ অহংকার থাকবে, সে জান্নাতে প্রবেশ করবে না।' (সহীহ মুসলিম: ৯১)",
    "✨ সময়ের কদর করুন: 'দুটি নিয়ামতের বিষয়ে অনেক মানুষ ধোঁকায় পড়ে আছে—সুস্থতা এবং অবসর।' (সহীহ বুখারী: ৬৪১২)",
    "✨ ধৈর্য ধারণ করুন: 'হে মুমিনগণ! ধৈর্য ও সালাতের মাধ্যমে সাহায্য প্রার্থনা করো। নিশ্চয়ই আল্লাহ ধৈর্যশীলদের সাথে আছেন।' (সূরা আল-বাকারাহ: ১৫৩)",
    "✨ সাদাকাহ দিন: 'দান-সাদাকাহ সম্পদ কমায় না, আর কেউ ক্ষমা করলে আল্লাহ তার সম্মান কেবল বাড়িয়েই দেন।' (সহীহ মুসলিম: ২৫৮৮)"
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_currentPage < _reminders.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: PageView.builder(
        controller: _pageController,
        itemCount: _reminders.length,
        itemBuilder: (context, index) {
          return Center(
            child: Text(
              _reminders[index],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          );
        },
      ),
    );
  }
}