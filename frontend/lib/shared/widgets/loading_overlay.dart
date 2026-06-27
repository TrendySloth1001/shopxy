import 'package:flutter/material.dart';
import 'package:shopxy/shared/theme/app_colors.dart';

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key, required this.isLoading, required this.child});

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          ColoredBox(
            color: AppColors.scrim,
            child: SizedBox.expand(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.black),
              ),
            ),
          ),
      ],
    );
  }
}
