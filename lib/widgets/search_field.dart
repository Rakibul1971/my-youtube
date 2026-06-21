import 'package:flutter/material.dart';

/// A reusable Material 3 search bar with a clear button.
class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  const SearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SearchBar(
        controller: controller,
        hintText: hintText,
        elevation: const WidgetStatePropertyAll(1),
        leading: const Icon(Icons.search),
        trailing: [
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: () {
                controller.clear();
                onChanged('');
              },
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
