import 'package:flutter/material.dart';

/// Sélecteur de date de naissance (jour + mois + année).
class DobPicker extends StatelessWidget {
  const DobPicker({
    super.key,
    required this.day,
    required this.month,
    required this.year,
    required this.onChanged,
  });

  final int? day;
  final int? month;
  final int? year;
  final void Function(int? day, int? month, int? year) onChanged;

  static const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  static const _daysInMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

  int get _maxDay => month == null ? 31 : _daysInMonth[month! - 1];

  @override
  Widget build(BuildContext context) {
    final safeDay = (day != null && day! <= _maxDay) ? day : null;
    final currentYear = DateTime.now().year;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<int?>(
                value: month,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Mois',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('—')),
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem<int?>(
                        value: m, child: Text(months[m - 1])),
                ],
                onChanged: (m) {
                  final maxD = m == null ? 31 : _daysInMonth[m - 1];
                  final d = (day != null && day! <= maxD) ? day : null;
                  onChanged(d, m, year);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int?>(
                value: safeDay,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Jour',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('—')),
                  for (var d = 1; d <= _maxDay; d++)
                    DropdownMenuItem<int?>(value: d, child: Text('$d')),
                ],
                onChanged: (d) => onChanged(d, month, year),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          value: year,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Année',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('—')),
            for (var y = currentYear; y >= 1900; y--)
              DropdownMenuItem<int?>(value: y, child: Text('$y')),
          ],
          onChanged: (y) => onChanged(day, month, y),
        ),
      ],
    );
  }
}

/// Libellé jour + mois (ex. "14 février"), pour l'anniversaire. Null si vide.
String? birthdayLabel(int? day, int? month) {
  if (day == null || month == null) return null;
  if (month < 1 || month > 12) return null;
  return '$day ${DobPicker.months[month - 1]}';
}

/// Libellé complet (ex. "14 février 1990"). Null si incomplet.
String? dobLabel(int? day, int? month, int? year) {
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12) return null;
  return '$day ${DobPicker.months[month - 1]} $year';
}

/// Âge révolu aujourd'hui à partir de la date de naissance. Null si incomplet.
int? ageFrom(int? day, int? month, int? year) {
  if (day == null || month == null || year == null) return null;
  final now = DateTime.now();
  var age = now.year - year;
  if (now.month < month || (now.month == month && now.day < day)) age--;
  return age;
}
