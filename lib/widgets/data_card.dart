import 'package:flutter/material.dart';

class DataCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Widget? additional; // From your version
  final bool useThemeStyles; // From my version
  final double elevation; // Configurable
  final EdgeInsetsGeometry margin; // From your version

  const DataCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.additional,
    this.useThemeStyles = true,
    this.elevation = 3,
    this.margin = const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: elevation,
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: useThemeStyles
                      ? textTheme.titleMedium // From my version
                      : const TextStyle( // From your version
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: useThemeStyles
                  ? textTheme.headlineSmall?.copyWith( // From my version
                      fontWeight: FontWeight.bold,
                    )
                  : const TextStyle( // From your version
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
            ),
            if (additional != null) ...[ // Your version's extension point
              const SizedBox(height: 8),
              additional!,
            ],
          ],
        ),
      ),
    );
  }
}

// Helper function preserving your original API (optional)
Widget buildDataCard(
  String title,
  String value,
  IconData icon,
  Color color, [
  Widget? additional,
]) {
  return DataCard(
    title: title,
    value: value,
    icon: icon,
    color: color,
    additional: additional,
    useThemeStyles: false, // Maintains your original styling
  );
}