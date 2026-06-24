import 'package:flutter/material.dart';

class PaginationBar extends StatelessWidget {
  final int pageIndex;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const PaginationBar({
    Key? key,
    required this.pageIndex,
    required this.totalPages,
    this.onPrevious,
    this.onNext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _navButton("PREVIOUS", onPrevious != null, onPrevious),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  "($pageIndex/$totalPages)",
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _navButton("NEXT", onNext != null, onNext),
        ],
      ),
    );
  }

  Widget _navButton(String label, bool enabled, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
