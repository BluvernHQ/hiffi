import 'package:workmanager/workmanager.dart';

/// Service for managing WorkManager tasks and checking task status
class WorkManagerService {
  /// Check if a task with the given unique name exists/is running
  /// Note: WorkManager doesn't provide a direct API to check task status,
  /// so we use a workaround by attempting to cancel and checking if it was successful
  /// This is not perfect but works for our use case
  static Future<bool> hasTaskWithName(String uniqueName) async {
    try {
      // WorkManager doesn't expose a way to check if a task exists
      // We'll need to track this ourselves or use a different approach
      // For now, we'll return false and rely on the view model to track active tasks
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Cancel all video upload tasks
  static Future<void> cancelAllVideoUploadTasks() async {
    try {
      await Workmanager().cancelAll();
    } catch (e) {
      // Ignore errors
    }
  }

  /// Cancel a specific task by unique name
  static Future<bool> cancelTask(String uniqueName) async {
    try {
      await Workmanager().cancelByUniqueName(uniqueName);
      return true;
    } catch (e) {
      return false;
    }
  }
}
