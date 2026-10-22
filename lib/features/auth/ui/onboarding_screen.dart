import 'package:flutter/material.dart';

import 'create_account_screen.dart';
import 'widgets/intro_page.dart';

/// Designs 2/35 and 3/35: the two onboarding pages.
///
/// "Continue" on page 1 moves to page 2. "Create account" on page 2 opens
/// the sign up form. The system back button goes back a page as usual.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      title: 'Find events you’ll love',
      description: 'Search by topic, date or location and make plans that fit your schedule.',
    ),
    (
      title: 'Never miss a moment',
      description:
          'Get your ticket, save events and receive updates when plans change.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const CreateAccountScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _controller.previousPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      },
      child: PageView.builder(
        controller: _controller,
        itemCount: _pages.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (context, i) => IntroPage(
          title: _pages[i].title,
          description: _pages[i].description,
          buttonLabel: isLast ? 'Create account' : 'Continue',
          onPressed: _next,
          progress: (current: i + 1, total: _pages.length),
        ),
      ),
    );
  }
}
