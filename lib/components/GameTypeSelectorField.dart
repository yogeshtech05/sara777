import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GameTypeSelectorField extends StatelessWidget {
  final String selectedOption;
  final List<String> options;
  final bool enabled;
  final ValueChanged<String> onSelected;
  final String Function(String)? displayTextBuilder;
  final String Function(String)? dialogTextBuilder;

  const GameTypeSelectorField({
    Key? key,
    required this.selectedOption,
    required this.options,
    required this.onSelected,
    this.enabled = true,
    this.displayTextBuilder,
    this.dialogTextBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayBuilder = displayTextBuilder ?? (val) => val.toUpperCase();
    final dialBuilder = dialogTextBuilder ?? (val) => val.toUpperCase();

    return GestureDetector(
      onTap: enabled
          ? () {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (context) {
                  return Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Orange Header
                          Container(
                            color: const Color(0xFFF9B233), // Brand Orange
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const SizedBox(width: 24), // Spacer to help center the title
                                Expanded(
                                  child: Text(
                                    "Select Game Type",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.black,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Options List
                          Column(
                            children: options.map((option) {
                              final bool isSelected = option.toLowerCase() == selectedOption.toLowerCase();
                              return InkWell(
                                onTap: () {
                                  onSelected(option);
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        dialBuilder(option),
                                        style: GoogleFonts.poppins(
                                          color: Colors.black87,
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: Colors.black54,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
          : null,
      child: Container(
        height: 38,
        padding: const EdgeInsets.only(left: 14, right: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                displayBuilder(selectedOption),
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFFF9B233),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
