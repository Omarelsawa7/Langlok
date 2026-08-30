import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Central local database for everything that needs to persist beyond a
/// single session: saved vocabulary words, per-video watch progress
/// (Course Mode resume), and favorited/bookmarked videos.
class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  AppDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'langtok.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE vocabulary (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT NOT NULL,
            source_sentence TEXT,
            video_path TEXT,
            video_title TEXT,
            created_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE watch_progress (
            video_path TEXT PRIMARY KEY,
            position_ms INTEGER NOT NULL,
            duration_ms INTEGER NOT NULL,
            completed INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE favorites (
            video_path TEXT PRIMARY KEY,
            created_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE course_state (
            id INTEGER PRIMARY KEY CHECK (id = 0),
            last_index INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // ---------------------------------------------------------------------
  // Vocabulary Bank
  // ---------------------------------------------------------------------

  Future<int> saveWord({
    required String word,
    String? sourceSentence,
    String? videoPath,
    String? videoTitle,
  }) async {
    final db = await database;
    return db.insert('vocabulary', {
      'word': word,
      'source_sentence': sourceSentence,
      'video_path': videoPath,
      'video_title': videoTitle,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, Object?>>> getAllWords() async {
    final db = await database;
    return db.query('vocabulary', orderBy: 'created_at DESC');
  }

  Future<void> deleteWord(int id) async {
    final db = await database;
    await db.delete('vocabulary', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------
  // Watch Progress (Course Mode resume + completion tracking)
  // ---------------------------------------------------------------------

  Future<void> saveProgress({
    required String videoPath,
    required int positionMs,
    required int durationMs,
  }) async {
    final db = await database;
    // A video is considered "completed" once watched past 90% —
    // avoids requiring pixel-perfect completion at the very last frame.
    final completed = durationMs > 0 && positionMs >= (durationMs * 0.9);

    await db.insert(
      'watch_progress',
      {
        'video_path': videoPath,
        'position_ms': positionMs,
        'duration_ms': durationMs,
        'completed': completed ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> getProgress(String videoPath) async {
    final db = await database;
    final rows = await db.query(
      'watch_progress',
      where: 'video_path = ?',
      whereArgs: [videoPath],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Set<String>> getCompletedVideoPaths() async {
    final db = await database;
    final rows = await db.query(
      'watch_progress',
      columns: ['video_path'],
      where: 'completed = 1',
    );
    return rows.map((r) => r['video_path'] as String).toSet();
  }

  /// Persists the last active index in Course Mode so the app can resume
  /// exactly where the user left off, even across app restarts.
  Future<void> saveLastCourseIndex(int index) async {
    final db = await database;
    await db.insert(
      'course_state',
      {
        'id': 0,
        'last_index': index,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int?> getLastCourseIndex() async {
    final db = await database;
    final rows = await db.query('course_state', where: 'id = 0', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['last_index'] as int?;
  }

  // ---------------------------------------------------------------------
  // Favorites
  // ---------------------------------------------------------------------

  Future<void> addFavorite(String videoPath) async {
    final db = await database;
    await db.insert(
      'favorites',
      {'video_path': videoPath, 'created_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(String videoPath) async {
    final db = await database;
    await db.delete('favorites', where: 'video_path = ?', whereArgs: [videoPath]);
  }

  Future<bool> isFavorite(String videoPath) async {
    final db = await database;
    final rows = await db.query(
      'favorites',
      where: 'video_path = ?',
      whereArgs: [videoPath],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> getAllFavoritePaths() async {
    final db = await database;
    final rows = await db.query('favorites', columns: ['video_path']);
    return rows.map((r) => r['video_path'] as String).toSet();
  }
}
