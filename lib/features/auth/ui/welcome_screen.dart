import 'package:flutter/material.dart';

import 'onboarding_screen.dart';
import 'sign_in_screen.dart';
import 'widgets/intro_page.dart';

/// Design 1/35: first launch.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return IntroPage(
      title: 'Find your people.\nFind your thing.',
      description: 'Events, clubs and experiences across campus in one place.',
      buttonLabel: 'Get started',
      onPressed: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const OnboardingScreen())),
      secondaryLabel: 'I already have an account',
      onSecondaryPressed: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const SignInScreen())),
    );
  }
}
