import 'package:flutter/material.dart';

/// The Kanban board. Filled in by the following changes; for now it only
/// holds the tab's place.
class KanbanScreen extends StatelessWidget {
  const KanbanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kanban')),
      body: const Center(child: Text('Kanban')),
    );
  }
}
