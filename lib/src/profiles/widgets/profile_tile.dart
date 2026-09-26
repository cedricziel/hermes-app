import 'package:flutter/material.dart';

import '../hermes_profiles_repository.dart';

/// One row of the Profiles screen: the profile's label, its description,
/// default model and skill count, an "Active" chip on the active one, and,
/// with [onChangeModel], a button that changes its default model.
class ProfileTile extends StatelessWidget {
  const ProfileTile({
    super.key,
    required this.profile,
    required this.active,
    required this.onTap,
    this.onChangeModel,
  });

  final HermesProfile profile;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onChangeModel;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (profile.description.isNotEmpty) profile.description,
      ?profile.model,
      '${profile.skillCount} skills',
    ];
    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: Text(profile.label),
      subtitle: Text(parts.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active) const Chip(label: Text('Active')),
          if (onChangeModel != null)
            IconButton(
              key: Key('profile-model-${profile.name}'),
              tooltip: 'Change default model',
              icon: const Icon(Icons.tune),
              onPressed: onChangeModel,
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
