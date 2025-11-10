// Offline Indicator Widget
// Shows connectivity status and sync information to users

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';

// Provider for connectivity status
final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier();
});

class ConnectivityState {
  final bool isOnline;
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final String? syncError;

  const ConnectivityState({
    required this.isOnline,
    this.isSyncing = false,
    this.lastSyncTime,
    this.syncError,
  });

  ConnectivityState copyWith({
    bool? isOnline,
    bool? isSyncing,
    DateTime? lastSyncTime,
    String? syncError,
  }) {
    return ConnectivityState(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      syncError: syncError,
    );
  }
}

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  ConnectivityNotifier() : super(const ConnectivityState(isOnline: true));

  void updateOnlineStatus(bool isOnline) {
    state = state.copyWith(isOnline: isOnline);
  }

  void updateSyncStatus(bool isSyncing) {
    state = state.copyWith(isSyncing: isSyncing);
  }

  void updateLastSyncTime(DateTime time) {
    state = state.copyWith(lastSyncTime: time);
  }

  void setSyncError(String? error) {
    state = state.copyWith(syncError: error);
  }
}

// Offline Indicator Widget
class OfflineIndicator extends ConsumerWidget {
  final bool showAlways;
  final EdgeInsets padding;

  const OfflineIndicator({
    Key? key,
    this.showAlways = false,
    this.padding = const EdgeInsets.all(8.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityState = ref.watch(connectivityProvider);

    // Only show when offline or syncing (unless showAlways is true)
    if (!showAlways && connectivityState.isOnline && !connectivityState.isSyncing) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: padding,
      child: Material(
        color: _getBackgroundColor(connectivityState),
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIcon(connectivityState),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _getMessage(connectivityState),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (connectivityState.isSyncing) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(ConnectivityState state) {
    if (state.isSyncing) {
      return const Icon(Icons.sync, color: Colors.white, size: 20);
    } else if (!state.isOnline) {
      return const Icon(Icons.cloud_off, color: Colors.white, size: 20);
    } else if (state.syncError != null) {
      return const Icon(Icons.error_outline, color: Colors.white, size: 20);
    } else {
      return const Icon(Icons.cloud_done, color: Colors.white, size: 20);
    }
  }

  String _getMessage(ConnectivityState state) {
    if (state.isSyncing) {
      return 'Syncing...';
    } else if (!state.isOnline) {
      return 'Offline - Changes will sync when connected';
    } else if (state.syncError != null) {
      return 'Sync failed - ${state.syncError}';
    } else if (state.lastSyncTime != null) {
      final difference = DateTime.now().difference(state.lastSyncTime!);
      if (difference.inMinutes < 1) {
        return 'Synced just now';
      } else if (difference.inMinutes < 60) {
        return 'Synced ${difference.inMinutes}m ago';
      } else {
        return 'Synced ${difference.inHours}h ago';
      }
    } else {
      return 'Online';
    }
  }

  Color _getBackgroundColor(ConnectivityState state) {
    if (state.syncError != null) {
      return Colors.red.shade600;
    } else if (!state.isOnline) {
      return Colors.orange.shade600;
    } else if (state.isSyncing) {
      return Colors.blue.shade600;
    } else {
      return Colors.green.shade600;
    }
  }
}

// Floating Offline Banner
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityState = ref.watch(connectivityProvider);

    if (connectivityState.isOnline && !connectivityState.isSyncing) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: OfflineIndicator(
        showAlways: true,
        padding: const EdgeInsets.all(12),
      ),
    );
  }
}

// Status Bar with Sync Button
class SyncStatusBar extends ConsumerWidget {
  final VoidCallback? onSyncPressed;

  const SyncStatusBar({
    Key? key,
    this.onSyncPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityState = ref.watch(connectivityProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            connectivityState.isOnline ? Icons.wifi : Icons.wifi_off,
            size: 20,
            color: connectivityState.isOnline
                ? Colors.green
                : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  connectivityState.isOnline ? 'Online' : 'Offline',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (connectivityState.lastSyncTime != null)
                  Text(
                    'Last synced: ${_formatTime(connectivityState.lastSyncTime!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
              ],
            ),
          ),
          if (connectivityState.isOnline && !connectivityState.isSyncing)
            TextButton.icon(
              onPressed: onSyncPressed,
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Sync Now'),
            ),
          if (connectivityState.isSyncing)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Syncing...'),
              ],
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

// Snackbar helper for offline notifications
class OfflineSnackBar {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  static void showSyncSuccess(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Sync completed successfully'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void showSyncError(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Sync failed: $error'),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'RETRY',
          textColor: Colors.white,
          onPressed: () {
            // Trigger retry
          },
        ),
      ),
    );
  }
}
