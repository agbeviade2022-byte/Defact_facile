import 'package:flutter/material.dart';

import 'app_states.dart';

/// Foundation-only screen used until the feature is implemented in its
/// dedicated mission. Deliberately explicit so nobody mistakes it for a
/// finished feature.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.mission,
    this.icon = Icons.construction_outlined,
  });

  final String title;
  final String mission;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AppEmptyState(
        icon: icon,
        title: title,
        message: 'Cet écran sera implémenté dans la $mission.',
      ),
    );
  }
}
