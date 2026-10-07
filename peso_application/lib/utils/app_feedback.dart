import 'package:flutter/material.dart';

extension AppFeedback on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppSnackBar(
    SnackBar snackBar,
  ) {
    return showSnackBar(
      SnackBar(
        key: snackBar.key,
        content: snackBar.content,
        backgroundColor: snackBar.backgroundColor,
        elevation: snackBar.elevation,
        margin: snackBar.margin,
        padding: snackBar.padding,
        width: snackBar.width,
        shape: snackBar.shape,
        hitTestBehavior: snackBar.hitTestBehavior,
        behavior: snackBar.behavior,
        action: snackBar.action,
        actionOverflowThreshold: snackBar.actionOverflowThreshold,
        showCloseIcon: snackBar.showCloseIcon,
        closeIconColor: snackBar.closeIconColor,
        duration: const Duration(seconds: 5),
        persist: false,
        animation: snackBar.animation,
        onVisible: snackBar.onVisible,
        dismissDirection: snackBar.dismissDirection,
        clipBehavior: snackBar.clipBehavior,
      ),
    );
  }
}
