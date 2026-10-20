import 'package:flutter/material.dart';
import '../models/country_code.dart';
import '../theme/app_theme.dart';

class CountryPickerDialog extends StatefulWidget {
  final CountryCode selectedCountry;
  final ValueChanged<CountryCode> onCountrySelected;

  const CountryPickerDialog({
    super.key,
    required this.selectedCountry,
    required this.onCountrySelected,
  });

  static Future<CountryCode?> show(
    BuildContext context, {
    required CountryCode selectedCountry,
  }) {
    return showModalBottomSheet<CountryCode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CountryPickerDialog(
        selectedCountry: selectedCountry,
        onCountrySelected: (c) => Navigator.of(ctx).pop(c),
      ),
    );
  }

  @override
  State<CountryPickerDialog> createState() => _CountryPickerDialogState();
}

class _CountryPickerDialogState extends State<CountryPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<CountryCode> _filteredCountries = CountryCode.defaultCountries;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = CountryCode.defaultCountries;
      } else {
        _filteredCountries = CountryCode.defaultCountries.where((c) {
          return c.name.toLowerCase().contains(query) ||
              c.code.contains(query) ||
              c.iso.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.cardBorder, width: 1.5),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.cardBorder,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.public_rounded, color: AppColors.primaryBlueLight, size: 22),
                SizedBox(width: 10),
                Text(
                  'Select Country / Dial Code',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search country or code (+91, India)...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.cardBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.cardBorder),
          // Country List
          Expanded(
            child: _filteredCountries.isEmpty
                ? const Center(
                    child: Text(
                      'No matching countries found.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    itemCount: _filteredCountries.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 64,
                      color: AppColors.surfaceLight,
                    ),
                    itemBuilder: (context, index) {
                      final country = _filteredCountries[index];
                      final isSelected = country.code == widget.selectedCountry.code &&
                          country.name == widget.selectedCountry.name;

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryPurpleLight
                                  : AppColors.cardBorder,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            country.flag,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                        title: Text(
                          country.name,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primaryBlueLight
                                : AppColors.textPrimary,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryPurple.withValues(alpha: 0.3)
                                : AppColors.cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryPurple
                                  : AppColors.cardBorder,
                            ),
                          ),
                          child: Text(
                            country.code,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        onTap: () => widget.onCountrySelected(country),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
