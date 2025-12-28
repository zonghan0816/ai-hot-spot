import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/trip.dart';
import '../models/fleet.dart';
import '../models/fee_item.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'taxibook.db');

    return await openDatabase(
      path,
      version: 9, // 版本號提升至 9
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTripsTable(db);
    await _createFleetsTable(db);
    await _createFeeItemsTable(db);
    await _createTripFeesTable(db);
    await _createSettingsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createFleetsTable(db);
    }
    if (oldVersion < 3) {
      await _createFeeItemsTable(db);
      await _createTripFeesTable(db);
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE fleets ADD COLUMN fareTypes TEXT NOT NULL DEFAULT \'\'');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE fleets ADD COLUMN isDefault INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE trips ADD COLUMN pickupLocation TEXT');
    }
    if (oldVersion < 7) {
      await _createSettingsTable(db);
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE trips ADD COLUMN pickupLatitude REAL');
      await db.execute('ALTER TABLE trips ADD COLUMN pickupLongitude REAL');
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE trips ADD COLUMN notes TEXT');
    }
  }

  // Table Creation Scripts

  Future<void> _createTripsTable(Database db) async {
    await db.execute('''
      CREATE TABLE trips(
        id TEXT PRIMARY KEY,
        fare REAL NOT NULL, tip REAL NOT NULL, isCash INTEGER NOT NULL,
        timestamp TEXT NOT NULL, commission REAL NOT NULL, fleetName TEXT,
        pickupLocation TEXT,
        pickupLatitude REAL,
        pickupLongitude REAL,
        notes TEXT
      )''');
  }

  Future<void> _createFleetsTable(Database db) async {
    await db.execute('''
      CREATE TABLE fleets(
        id TEXT PRIMARY KEY, name TEXT NOT NULL, type INTEGER NOT NULL,
        defaultCommission REAL NOT NULL, 
        fareTypes TEXT NOT NULL DEFAULT '',
        isDefault INTEGER NOT NULL DEFAULT 0
      )''');
  }

  Future<void> _createFeeItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE fee_items(
        id TEXT PRIMARY KEY, name TEXT NOT NULL, defaultAmount REAL NOT NULL
      )''');
  }

  Future<void> _createTripFeesTable(Database db) async {
    await db.execute('''
      CREATE TABLE trip_fees(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tripId TEXT NOT NULL,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        FOREIGN KEY (tripId) REFERENCES trips (id) ON DELETE CASCADE
      )''');
  }

  Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )''');
  }

  // --- Settings Operations ---

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  // Trip Operations

  Future<void> insertTrip(Trip trip) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('trips', trip.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      for (final fee in trip.fees) {
        await txn.insert('trip_fees', fee.toMap(trip.id));
      }
    });
  }

  Future<List<Trip>> getTrips() async {
    final db = await database;
    final List<Map<String, dynamic>> tripMaps = await db.query('trips', orderBy: 'timestamp DESC');
    List<Trip> trips = [];
    for (var tripMap in tripMaps) {
      final List<Map<String, dynamic>> feeMaps = await db.query('trip_fees', where: 'tripId = ?', whereArgs: [tripMap['id']]);
      final List<AppliedFee> fees = feeMaps.map((feeMap) => AppliedFee.fromMap(feeMap)).toList();
      trips.add(Trip.fromMap(tripMap, fees: fees));
    }
    return trips;
  }
  
  Future<List<Trip>> getTripsForToday() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final List<Map<String, dynamic>> tripMaps = await db.query(
      'trips',
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
    
    List<Trip> trips = [];
    for (var tripMap in tripMaps) {
      final List<Map<String, dynamic>> feeMaps = await db.query('trip_fees', where: 'tripId = ?', whereArgs: [tripMap['id']]);
      final List<AppliedFee> fees = feeMaps.map((feeMap) => AppliedFee.fromMap(feeMap)).toList();
      trips.add(Trip.fromMap(tripMap, fees: fees));
    }
    return trips;
  }

  Future<int> getTripsCountByCity(String city) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM trips WHERE pickupLocation LIKE ?',
      ['%$city%']
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> updateTrip(Trip trip) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('trips', trip.toMap(), where: 'id = ?', whereArgs: [trip.id]);
      await txn.delete('trip_fees', where: 'tripId = ?', whereArgs: [trip.id]);
      for (final fee in trip.fees) {
        await txn.insert('trip_fees', fee.toMap(trip.id));
      }
    });
  }

  Future<void> deleteTrip(String id) async {
    final db = await database;
    await db.delete('trips', where: 'id = ?', whereArgs: [id]);
    await db.delete('trip_fees', where: 'tripId = ?', whereArgs: [id]); 
  }

  // Rename this or add new method
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('trips');
      await txn.delete('trip_fees');
      await txn.delete('fleets');
      await txn.delete('fee_items');
      await txn.delete('settings');
    });
  }
  
  // Kept for backward compatibility if needed, but redirects to clearAllData if intent is same
  // Or kept as is if some code specifically wants only trips cleared. 
  // Based on user request, "Clear Local Data" usually means everything.
  Future<void> deleteAllTrips() async {
     await clearAllData();
  }

  // Fleet Operations

  Future<void> insertFleet(Fleet fleet) async {
    final db = await database;
    await db.insert('fleets', fleet.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Fleet>> getFleets() async {
    final db = await database;
    final maps = await db.query('fleets', orderBy: 'name ASC');
    return maps.map((e) => Fleet.fromMap(e)).toList();
  }

  Future<void> updateFleet(Fleet fleet) async {
    final db = await database;
    await db.update('fleets', fleet.toMap(), where: 'id = ?', whereArgs: [fleet.id]);
  }

  Future<void> deleteFleet(String id) async {
    final db = await database;
    await db.delete('fleets', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setDefaultFleet(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('fleets', {'isDefault': 0}, where: 'isDefault = 1');
      await txn.update('fleets', {'isDefault': 1}, where: 'id = ?', whereArgs: [id]);
    });
  }

  // FeeItem (Template) Operations

  Future<void> insertFeeItem(FeeItem feeItem) async {
    final db = await database;
    await db.insert('fee_items', feeItem.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<FeeItem>> getFeeItems() async {
    final db = await database;
    final maps = await db.query('fee_items', orderBy: 'name ASC');
    return maps.map((e) => FeeItem.fromMap(e)).toList();
  }

  Future<void> updateFeeItem(FeeItem feeItem) async {
    final db = await database;
    await db.update('fee_items', feeItem.toMap(), where: 'id = ?', whereArgs: [feeItem.id]);
  }

  Future<void> deleteFeeItem(String id) async {
    final db = await database;
    await db.delete('fee_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
