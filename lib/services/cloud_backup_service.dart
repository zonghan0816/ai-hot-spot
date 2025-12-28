import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:taxibook/services/database_service.dart';

// Enum to provide clear status feedback to the UI
enum CloudBackupStatus {
  success, 
  error,
  noBackupFound,
  inProgress,
  userCancelled
}

class CloudBackupService {
  final GoogleSignIn _googleSignIn;
  final DatabaseService _databaseService = DatabaseService();
  static const String _dbFileName = 'taxibook.db';

  CloudBackupService(this._googleSignIn);

  Future<drive.DriveApi?> _getDriveApi() async {
    var googleSignInAccount = _googleSignIn.currentUser;
    
    // 如果目前沒有使用者資訊，嘗試靜默登入恢復 Session
    if (googleSignInAccount == null) {
      try {
        debugPrint('CloudBackup: Attempting silent sign-in...');
        googleSignInAccount = await _googleSignIn.signInSilently();
      } catch (e) {
        debugPrint('CloudBackup: Silent sign-in failed: $e');
      }
    }

    if (googleSignInAccount == null) {
      debugPrint('CloudBackup: Google User is null. User must interactively sign in.');
      return null;
    }

    try {
      final client = await _googleSignIn.authenticatedClient();
      if (client == null) {
        debugPrint('CloudBackup: Authenticated Client is null');
        return null;
      }
      return drive.DriveApi(client);
    } catch (e) {
      debugPrint('CloudBackup: Failed to get authenticated client: $e');
      return null;
    }
  }

  Future<String?> _findBackupFile(drive.DriveApi driveApi) async {
    try {
      final response = await driveApi.files.list(
        q: "name='$_dbFileName' and trashed=false", // Ensure we don't pick up trash
        spaces: 'appDataFolder',
        $fields: 'files(id, name)',
      );
      if (response.files != null && response.files!.isNotEmpty) {
        // Return the most recent one if multiple exist? 
        // For simplicity, just return the first one found.
        return response.files!.first.id;
      }
    } catch (e) {
      debugPrint('CloudBackup: Failed to list files: $e');
    }
    return null;
  }

  Future<CloudBackupStatus> backupDatabase() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      debugPrint('CloudBackup: Drive API is null');
      return CloudBackupStatus.error;
    }

    try {
      // Close the database to prevent corruption during backup
      await _databaseService.close();
      final dbPath = await getDatabasesPath();
      final dbFile = File(p.join(dbPath, _dbFileName));

      if (!await dbFile.exists()) {
        debugPrint('CloudBackup: Local DB file does not exist at ${dbFile.path}');
        return CloudBackupStatus.error;
      }

      final fileId = await _findBackupFile(driveApi);

      final media = drive.Media(dbFile.openRead(), await dbFile.length());
      final driveFile = drive.File()..name = _dbFileName;

      if (fileId == null) {
        // Create new file
        debugPrint('CloudBackup: Creating new backup file...');
        driveFile.parents = ['appDataFolder'];
        await driveApi.files.create(driveFile, uploadMedia: media);
      } else {
        // Update existing file
        debugPrint('CloudBackup: Updating existing backup file ($fileId)...');
        await driveApi.files.update(driveFile, fileId, uploadMedia: media);
      }
      debugPrint('CloudBackup: Backup successful!');
      return CloudBackupStatus.success;
    } catch (e) {
      debugPrint('CloudBackup: Backup failed with error: $e');
      return CloudBackupStatus.error;
    } finally {
      // Re-open the database connection
      await _databaseService.database;
    }
  }

  Future<CloudBackupStatus> restoreDatabase() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return CloudBackupStatus.error;

    // Temporary backup of current DB in case restore fails
    File? tempBackup;

    try {
      final fileId = await _findBackupFile(driveApi);
      if (fileId == null) {
        debugPrint('CloudBackup: No backup file found in Drive.');
        return CloudBackupStatus.noBackupFound;
      }

      // 1. Close Database
      await _databaseService.close();

      final dbPath = await getDatabasesPath();
      final dbFile = File(p.join(dbPath, _dbFileName));

      // 2. Create a local temp backup just in case
      if (await dbFile.exists()) {
        final tempPath = p.join(dbPath, '$_dbFileName.bak');
        tempBackup = await dbFile.copy(tempPath);
        await dbFile.delete(); // Delete original to avoid lock issues
      }

      debugPrint('CloudBackup: Downloading backup file ($fileId)...');
      final media = await driveApi.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      
      // 3. Write new file
      final fileSink = dbFile.openWrite(); // This creates a new file
      await fileSink.addStream(media.stream);
      await fileSink.flush();
      await fileSink.close();

      // 4. Delete temp backup as success
      if (tempBackup != null && await tempBackup.exists()) {
        await tempBackup.delete();
      }

      debugPrint('CloudBackup: Restore successful!');
      return CloudBackupStatus.success;
    } catch (e) {
      debugPrint('CloudBackup: Restore failed with error: $e');
      
      // Attempt rollback
      if (tempBackup != null && await tempBackup.exists()) {
         debugPrint('CloudBackup: Rolling back to previous version...');
         final dbPath = await getDatabasesPath();
         final dbFile = File(p.join(dbPath, _dbFileName));
         await tempBackup.copy(dbFile.path);
      }
      
      return CloudBackupStatus.error;
    } finally {
      // Re-open the database connection
      await _databaseService.database;
    }
  }
}
