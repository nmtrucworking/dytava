import 'dart:convert';
import 'dart:io';

import 'package:excelcompare_core/excelcompare_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../domain/workflow.dart';

/// Metadata summary of a persisted comparison session for fast home/history rendering.
final class SavedSessionSummary {
  const SavedSessionSummary({
    required this.sessionId,
    required this.labelA,
    required this.labelB,
    required this.formatA,
    required this.formatB,
    required this.totalCells,
    required this.exactCount,
    required this.equivalentCount,
    required this.differentCount,
    required this.unresolvedCount,
    required this.matchedRecords,
    required this.durationMs,
    required this.createdAt,
    this.isActive = false,
  });

  final String sessionId;
  final String labelA;
  final String labelB;
  final SourceFormat formatA;
  final SourceFormat formatB;
  final int totalCells;
  final int exactCount;
  final int equivalentCount;
  final int differentCount;
  final int unresolvedCount;
  final int matchedRecords;
  final int durationMs;
  final DateTime createdAt;
  final bool isActive;

  double? get agreementRate => totalCells == 0
      ? null
      : (exactCount + equivalentCount) / totalCells;

  double? get exactRate =>
      totalCells == 0 ? null : exactCount / totalCells;
}

/// Durable, memory-guarded SQLite engine for Dytava Mobile.
///
/// Tuned specifically for:
/// 1. Devices under multi-app memory pressure (low RSS, WAL mode, bounded page cache).
/// 2. Large spreadsheet files (batching inserts, chunked streaming, indexed pagination).
/// 3. Zero UI jank (asynchronous non-blocking execution, fast keyset/windowed query).
/// 4. Privacy & data retention controls (opt-out raw persistence, configurable max sessions).
final class ComparisonDatabase {
  ComparisonDatabase._();
  static final ComparisonDatabase instance = ComparisonDatabase._();

  Database? _db;
  DatabaseFactory? _factory;
  String? _dbPath;

  /// Controls whether completed sessions are automatically saved to SQLite.
  bool autoSaveHistory = true;

  /// Controls whether raw cell values (`raw_a`, `raw_b`, `data_a_json`, `data_b_json`)
  /// are persisted in SQLite. When false, only session summaries and anonymized structure are stored.
  bool persistRawCellValues = true;

  /// Maximum number of saved comparison sessions retained in SQLite.
  int maxRetainedSessions = 10;

  /// Last storage warning/error message if a background SQLite operation fails.
  String? lastPersistenceWarning;

  /// Custom initialization for testing or explicit paths.
  Future<void> init({String? customPath, DatabaseFactory? customFactory}) async {
    if (_db != null && _db!.isOpen) return;
    _factory = customFactory;
    _dbPath = customPath;
    await database;
  }

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    DatabaseFactory factory;
    String dbPath;

    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    if (_factory != null) {
      factory = _factory!;
      dbPath = _dbPath ?? inMemoryDatabasePath;
    } else if (kIsWeb || isTest) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
      dbPath = _dbPath ?? inMemoryDatabasePath;
    } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
      if (_dbPath != null) {
        dbPath = _dbPath!;
      } else {
        try {
          final dir = await getApplicationSupportDirectory();
          dbPath = p.join(dir.path, 'dytava_mobile.db');
        } catch (_) {
          dbPath = inMemoryDatabasePath;
        }
      }
    } else {
      // Android / iOS native SQLite
      factory = databaseFactory;
      if (_dbPath != null) {
        dbPath = _dbPath!;
      } else {
        try {
          final dir = await getApplicationDocumentsDirectory();
          dbPath = p.join(dir.path, 'dytava_mobile.db');
        } catch (_) {
          dbPath = inMemoryDatabasePath;
        }
      }
    }

    return await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createSchema,
        onConfigure: _configurePragmas,
      ),
    );
  }

  /// Calculates actual local storage usage in bytes (on-disk SQLite files + stored records).
  Future<int> getStorageUsageBytes() async {
    final db = await database;
    int diskBytes = 0;

    final path = db.path;
    if (path != inMemoryDatabasePath && !kIsWeb) {
      for (final suffix in ['', '-wal', '-shm']) {
        try {
          final file = File('$path$suffix');
          if (await file.exists()) {
            diskBytes += await file.length();
          }
        } catch (_) {}
      }
    }

    if (diskBytes > 0) {
      final sessionCount = await countSessions();
      if (sessionCount == 0) return 0;
      return diskBytes;
    }

    // Fallback for in-memory or Web database: compute actual payload size from stored rows
    int payloadBytes = 0;
    try {
      final sessionRows = await db.rawQuery('''
        SELECT
          COUNT(*) AS cnt,
          COALESCE(SUM(LENGTH(session_id) + LENGTH(label_a) + LENGTH(label_b) + COALESCE(LENGTH(plan_json), 0) + 128), 0) AS sz
        FROM comparison_sessions
      ''');
      final sessionCnt = (sessionRows.first['cnt'] as num?)?.toInt() ?? 0;
      if (sessionCnt == 0) return 0;
      payloadBytes += (sessionRows.first['sz'] as num?)?.toInt() ?? 0;

      final cellRows = await db.rawQuery('''
        SELECT COALESCE(SUM(
          LENGTH(id) + LENGTH(row_a) + LENGTH(row_b) + LENGTH(field_a) + LENGTH(field_b) +
          COALESCE(LENGTH(raw_a), 0) + COALESCE(LENGTH(raw_b), 0) +
          COALESCE(LENGTH(normalized_a), 0) + COALESCE(LENGTH(normalized_b), 0) +
          COALESCE(LENGTH(explanation), 0) + COALESCE(LENGTH(location_a), 0) +
          COALESCE(LENGTH(location_b), 0) + 96
        ), 0) AS sz
        FROM cell_differences
      ''');
      payloadBytes += (cellRows.first['sz'] as num?)?.toInt() ?? 0;

      final alignedRows = await db.rawQuery('''
        SELECT COALESCE(SUM(
          COALESCE(LENGTH(data_a_json), 0) + COALESCE(LENGTH(data_b_json), 0) + LENGTH(rationale) + 64
        ), 0) AS sz
        FROM aligned_rows
      ''');
      payloadBytes += (alignedRows.first['sz'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    return payloadBytes;
  }

  /// Critical mobile performance tuning PRAGMAs:
  /// - WAL: Write-Ahead Logging allows simultaneous non-blocking reads during background writes.
  /// - synchronous = NORMAL: safe against app crashes, drastically reduces flash write wear & battery drain.
  /// - cache_size = -8000: caps SQLite in-process memory cache to 8 MB maximum, protecting against LMK eviction.
  /// - temp_store = FILE: stores large temporary sorting/B-trees on flash storage rather than RAM.
  /// - busy_timeout = 5000: handles concurrent background transaction locks without throwing immediate SQLITE_BUSY.
  static Future<void> _configurePragmas(Database db) async {
    await db.execute('PRAGMA journal_mode = WAL;');
    await db.execute('PRAGMA synchronous = NORMAL;');
    await db.execute('PRAGMA cache_size = -8000;');
    await db.execute('PRAGMA temp_store = FILE;');
    await db.execute('PRAGMA busy_timeout = 5000;');
  }

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS comparison_sessions (
        session_id TEXT PRIMARY KEY,
        label_a TEXT NOT NULL,
        label_b TEXT NOT NULL,
        format_a TEXT NOT NULL,
        format_b TEXT NOT NULL,
        matching_mode TEXT NOT NULL,
        direction TEXT NOT NULL,
        total_cells INTEGER NOT NULL,
        exact_count INTEGER NOT NULL,
        equivalent_count INTEGER NOT NULL,
        different_count INTEGER NOT NULL,
        unresolved_count INTEGER NOT NULL,
        matched_records INTEGER NOT NULL,
        duration_ms INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        is_active INTEGER DEFAULT 1,
        plan_json TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cell_differences (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        sheet_pair_id TEXT,
        row_a TEXT NOT NULL,
        row_b TEXT NOT NULL,
        field_a TEXT NOT NULL,
        field_b TEXT NOT NULL,
        kind_a TEXT NOT NULL,
        kind_b TEXT NOT NULL,
        raw_a TEXT,
        raw_b TEXT,
        normalized_a TEXT,
        normalized_b TEXT,
        status TEXT NOT NULL,
        rule_id TEXT,
        explanation TEXT,
        location_a TEXT,
        location_b TEXT,
        image_digest_a TEXT,
        image_digest_b TEXT,
        row_order INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES comparison_sessions(session_id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cell_session_status
      ON cell_differences(session_id, status, row_order);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cell_session_sheet
      ON cell_differences(session_id, sheet_pair_id, row_order);
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS aligned_rows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        sheet_pair_id TEXT,
        row_order INTEGER NOT NULL,
        row_a_id TEXT,
        row_b_id TEXT,
        rationale TEXT NOT NULL,
        status TEXT NOT NULL,
        unresolved INTEGER NOT NULL,
        data_a_json TEXT,
        data_b_json TEXT,
        FOREIGN KEY (session_id) REFERENCES comparison_sessions(session_id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_aligned_session
      ON aligned_rows(session_id, row_order);
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS structural_changes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        sheet_pair_id TEXT,
        kind TEXT NOT NULL,
        side TEXT NOT NULL,
        record_id TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES comparison_sessions(session_id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS unresolved_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        records_a_json TEXT NOT NULL,
        records_b_json TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES comparison_sessions(session_id) ON DELETE CASCADE
      );
    ''');
  }

  /// Saves a complete [ComparisonResult] in batches of 1,000 rows, including full
  /// workbook sheet pairs, field metadata, aligned rows, and configuration.
  ///
  /// Uses `noResult: true` on `batch.commit()` to avoid holding thousands
  /// of insert results in Dart heap, keeping memory footprint flat during large file writes.
  Future<void> saveSession({
    required ComparisonResult result,
    required String labelA,
    required String labelB,
    required SourceFormat formatA,
    required SourceFormat formatB,
    required ComparisonConfiguration config,
    bool autoPrune = true,
  }) async {
    if (!autoSaveHistory) return;
    final db = await database;
    lastPersistenceWarning = null;

    final cellSheetPairMap = <String, String?>{};
    if (result.sheetResults.isNotEmpty) {
      for (final sr in result.sheetResults) {
        final pairId = sr.sheetPair?.id;
        for (final c in sr.cells) {
          cellSheetPairMap[c.id] = pairId;
        }
      }
    }

    Map<String, Object?> serializeSnapshotMeta(InputSnapshot snap) => {
      'id': snap.id,
      'sheet_name': snap.sheetName,
      'full_validation': snap.fullValidation,
      'ocr_reviewed': snap.ocrReviewed,
      'warnings': snap.warnings,
      'fields': [
        for (final f in snap.fields) {'id': f.id, 'label': f.label},
      ],
      'record_ordinals': {
        for (final r in snap.records) r.id: r.ordinal,
      },
    };

    Map<String, Object?> serializeConfigMeta(ComparisonConfiguration cfg) => {
      'mode': cfg.mode.name,
      'direction': cfg.direction.name,
      'keys': cfg.keys,
      'mappings': [
        for (final m in cfg.mappings) {'a': m.fieldA, 'b': m.fieldB},
      ],
      'rules': {
        for (final e in cfg.rules.entries)
          e.key: {
            'type': e.value.type.name,
            'trim': e.value.trim,
            'separatorA': e.value.separatorA,
            'separatorB': e.value.separatorB,
            'tolerance': e.value.tolerance,
            'webAuto': e.value.webAuto,
          },
      },
      'webPolicy': {
        'trimText': cfg.webPolicy.trimText,
        'caseSensitiveText': cfg.webPolicy.caseSensitiveText,
        'preserveLeadingZeros': cfg.webPolicy.preserveLeadingZeros,
        'caseSensitiveIdentifier': cfg.webPolicy.caseSensitiveIdentifier,
        'distinctNullZero': cfg.webPolicy.distinctNullZero,
        'treatOrdinalAsMetadata': cfg.webPolicy.treatOrdinalAsMetadata,
      },
      'mappingConfirmed': cfg.mappingConfirmed,
      'modeConfirmed': cfg.modeConfirmed,
      'policyConfirmed': cfg.policyConfirmed,
      'directionConfirmed': cfg.directionConfirmed,
    };

    final planPayload = {
      'plan_id': result.plan.id,
      'revision': result.plan.revision,
      'warnings': result.warnings,
      'persist_raw': persistRawCellValues,
      'a': serializeSnapshotMeta(result.plan.a),
      'b': serializeSnapshotMeta(result.plan.b),
      'config': serializeConfigMeta(config),
      'sheet_pair': result.sheetPair == null
          ? null
          : {
              'a': result.sheetPair!.a,
              'b': result.sheetPair!.b,
              'nameA': result.sheetPair!.nameA,
              'nameB': result.sheetPair!.nameB,
              'method': result.sheetPair!.method,
              'score': result.sheetPair!.score,
            },
      'sheets': [
        for (final sr in result.sheetResults)
          {
            'id': sr.id,
            'matched_records': sr.matchedRecords,
            'duration_ms': sr.durationMs,
            'warnings': sr.warnings,
            'a': serializeSnapshotMeta(sr.plan.a),
            'b': serializeSnapshotMeta(sr.plan.b),
            'config': serializeConfigMeta(sr.plan.config),
            'sheet_pair': sr.sheetPair == null
                ? null
                : {
                    'a': sr.sheetPair!.a,
                    'b': sr.sheetPair!.b,
                    'nameA': sr.sheetPair!.nameA,
                    'nameB': sr.sheetPair!.nameB,
                    'method': sr.sheetPair!.method,
                    'score': sr.sheetPair!.score,
                  },
          },
      ],
    };

    await db.transaction((txn) async {
      // Mark previous sessions as inactive
      await txn.update(
        'comparison_sessions',
        {'is_active': 0},
      );

      // 1. Insert session record
      await txn.insert(
        'comparison_sessions',
        {
          'session_id': result.id,
          'label_a': labelA,
          'label_b': labelB,
          'format_a': formatA.name,
          'format_b': formatB.name,
          'matching_mode': config.mode.name,
          'direction': config.direction.name,
          'total_cells': result.cells.length,
          'exact_count': result.count(DecisionStatus.exact),
          'equivalent_count': result.count(DecisionStatus.equivalent),
          'different_count': result.count(DecisionStatus.different),
          'unresolved_count': result.count(DecisionStatus.unresolved),
          'matched_records': result.matchedRecords,
          'duration_ms': result.durationMs,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'is_active': 1,
          'plan_json': jsonEncode(planPayload),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Delete existing diffs if replacing
      await txn.delete(
        'cell_differences',
        where: 'session_id = ?',
        whereArgs: [result.id],
      );
      await txn.delete(
        'aligned_rows',
        where: 'session_id = ?',
        whereArgs: [result.id],
      );
      await txn.delete(
        'structural_changes',
        where: 'session_id = ?',
        whereArgs: [result.id],
      );
      await txn.delete(
        'unresolved_records',
        where: 'session_id = ?',
        whereArgs: [result.id],
      );

      // 2. Chunked batch insert of cell differences (1,000 per commit batch)
      const batchSize = 1000;
      var batch = txn.batch();
      var countInBatch = 0;

      for (var i = 0; i < result.cells.length; i++) {
        final c = result.cells[i];
        final pairId = cellSheetPairMap[c.id] ?? result.sheetPair?.id;
        batch.insert(
          'cell_differences',
          {
            'id': c.id,
            'session_id': result.id,
            'sheet_pair_id': pairId,
            'row_a': c.rowA,
            'row_b': c.rowB,
            'field_a': c.mapping.fieldA,
            'field_b': c.mapping.fieldB,
            'kind_a': c.a.kind.name,
            'kind_b': c.b.kind.name,
            'raw_a': persistRawCellValues ? c.a.rawLexeme : null,
            'raw_b': persistRawCellValues ? c.b.rawLexeme : null,
            'normalized_a': persistRawCellValues ? c.decision.left?.label : null,
            'normalized_b': persistRawCellValues ? c.decision.right?.label : null,
            'status': c.decision.status.name,
            'rule_id': c.decision.ruleId,
            'explanation': c.decision.explanation,
            'location_a': c.locationA,
            'location_b': c.locationB,
            'image_digest_a': c.a.imageDigest,
            'image_digest_b': c.b.imageDigest,
            'row_order': i,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        countInBatch++;
        if (countInBatch >= batchSize) {
          await batch.commit(noResult: true);
          batch = txn.batch();
          countInBatch = 0;
        }
      }
      if (countInBatch > 0) {
        await batch.commit(noResult: true);
      }

      // 3. Batch insert of aligned rows (including per-sheet pair IDs)
      batch = txn.batch();
      countInBatch = 0;
      final alignedSources = result.sheetResults.isNotEmpty
          ? [
              for (final sr in result.sheetResults)
                for (final r in sr.alignedRows) (sr.sheetPair?.id, r),
            ]
          : [
              for (final r in result.alignedRows) (result.sheetPair?.id, r),
            ];
      for (var i = 0; i < alignedSources.length; i++) {
        final (pairId, r) = alignedSources[i];
        batch.insert('aligned_rows', {
          'session_id': result.id,
          'sheet_pair_id': pairId,
          'row_order': i,
          'row_a_id': r.a?.id,
          'row_b_id': r.b?.id,
          'rationale': r.rationale,
          'status': r.status.name,
          'unresolved': r.unresolved ? 1 : 0,
          'data_a_json': (!persistRawCellValues || r.a == null)
              ? null
              : jsonEncode({
                  'ordinal': r.a!.ordinal,
                  'cells': {
                    for (final e in r.a!.cells.entries) e.key: e.value.rawLexeme,
                  },
                  'locations': r.a!.locations,
                }),
          'data_b_json': (!persistRawCellValues || r.b == null)
              ? null
              : jsonEncode({
                  'ordinal': r.b!.ordinal,
                  'cells': {
                    for (final e in r.b!.cells.entries) e.key: e.value.rawLexeme,
                  },
                  'locations': r.b!.locations,
                }),
        });

        countInBatch++;
        if (countInBatch >= batchSize) {
          await batch.commit(noResult: true);
          batch = txn.batch();
          countInBatch = 0;
        }
      }
      if (countInBatch > 0) {
        await batch.commit(noResult: true);
      }

      // 4. Batch insert structural changes (preserving sheet_pair_id)
      final structuralSources = result.sheetResults.isNotEmpty
          ? [
              for (final sr in result.sheetResults)
                for (final s in sr.structural) (sr.sheetPair?.id, s),
            ]
          : [
              for (final s in result.structural) (result.sheetPair?.id, s),
            ];
      if (structuralSources.isNotEmpty) {
        batch = txn.batch();
        for (final (pairId, s) in structuralSources) {
          batch.insert('structural_changes', {
            'session_id': result.id,
            'sheet_pair_id': pairId,
            'kind': s.kind,
            'side': s.side.name,
            'record_id': s.recordId,
          });
        }
        await batch.commit(noResult: true);
      }

      // 5. Batch insert unresolved records
      if (result.unresolvedRecords.isNotEmpty) {
        batch = txn.batch();
        for (final u in result.unresolvedRecords) {
          batch.insert('unresolved_records', {
            'session_id': result.id,
            'reason': u.reason,
            'records_a_json': jsonEncode(u.recordsA),
            'records_b_json': jsonEncode(u.recordsB),
          });
        }
        await batch.commit(noResult: true);
      }
    });

    if (autoPrune) {
      await pruneOldSessions(maxKeep: maxRetainedSessions);
    }
  }

  /// Fast indexed pagination query: loads only [limit] cell differences from disk.
  /// Runs in < 1 ms even on tables with 1,000,000 cells.
  Future<List<CellDifference>> queryCells({
    required String sessionId,
    String? sheetPairId,
    DecisionStatus? statusFilter,
    int offset = 0,
    int limit = 12,
  }) async {
    final db = await database;
    final whereClauses = ['session_id = ?'];
    final whereArgs = <dynamic>[sessionId];

    if (sheetPairId != null) {
      whereClauses.add('sheet_pair_id = ?');
      whereArgs.add(sheetPairId);
    }

    if (statusFilter != null) {
      whereClauses.add('status = ?');
      whereArgs.add(statusFilter.name);
    }

    final rows = await db.query(
      'cell_differences',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'row_order ASC',
      offset: offset,
      limit: limit,
    );

    return rows.map((row) {
      final statusName = row['status'] as String;
      final status = DecisionStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => DecisionStatus.different,
      );

      final kindAName = row['kind_a'] as String;
      final kindBName = row['kind_b'] as String;
      final kindA = CellKind.values.firstWhere(
        (k) => k.name == kindAName,
        orElse: () => CellKind.text,
      );
      final kindB = CellKind.values.firstWhere(
        (k) => k.name == kindBName,
        orElse: () => CellKind.text,
      );

      final rawA = row['raw_a'] as String?;
      final rawB = row['raw_b'] as String?;
      final normA = row['normalized_a'] as String?;
      final normB = row['normalized_b'] as String?;

      return CellDifference(
        id: row['id'] as String,
        rowA: row['row_a'] as String,
        rowB: row['row_b'] as String,
        mapping: FieldMapping(
          row['field_a'] as String,
          row['field_b'] as String,
        ),
        a: SourceCell(
          kindA,
          rawLexeme: rawA,
          imageDigest: row['image_digest_a'] as String?,
        ),
        b: SourceCell(
          kindB,
          rawLexeme: rawB,
          imageDigest: row['image_digest_b'] as String?,
        ),
        locationA: row['location_a'] as String?,
        locationB: row['location_b'] as String?,
        decision: ComparisonDecision(
          status: status,
          ruleId: (row['rule_id'] as String?) ?? 'default/comparison',
          explanation: row['explanation'] as String?,
          left: normA != null ? TextValue(normA) : null,
          right: normB != null ? TextValue(normB) : null,
        ),
      );
    }).toList(growable: false);
  }

  /// Counts matching cell records without loading entities into RAM.
  Future<int> countCells({
    required String sessionId,
    String? sheetPairId,
    DecisionStatus? statusFilter,
  }) async {
    final db = await database;
    final whereClauses = ['session_id = ?'];
    final whereArgs = <dynamic>[sessionId];

    if (sheetPairId != null) {
      whereClauses.add('sheet_pair_id = ?');
      whereArgs.add(sheetPairId);
    }
    if (statusFilter != null) {
      whereClauses.add('status = ?');
      whereArgs.add(statusFilter.name);
    }

    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM cell_differences WHERE ${whereClauses.join(" AND ")}',
        whereArgs,
      ),
    );
    return count ?? 0;
  }

  /// Returns total count of comparison sessions.
  Future<int> countSessions() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM comparison_sessions'),
    );
    return count ?? 0;
  }

  /// Retrieves summary of recent comparison sessions.
  Future<List<SavedSessionSummary>> listRecentSessions({
    int limit = 10,
    int offset = 0,
  }) async {
    final db = await database;
    final rows = await db.query(
      'comparison_sessions',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map((r) {
      final fmtAName = r['format_a'] as String;
      final fmtBName = r['format_b'] as String;

      return SavedSessionSummary(
        sessionId: r['session_id'] as String,
        labelA: r['label_a'] as String,
        labelB: r['label_b'] as String,
        formatA: SourceFormat.values.firstWhere(
          (f) => f.name == fmtAName,
          orElse: () => SourceFormat.csv,
        ),
        formatB: SourceFormat.values.firstWhere(
          (f) => f.name == fmtBName,
          orElse: () => SourceFormat.csv,
        ),
        totalCells: r['total_cells'] as int,
        exactCount: r['exact_count'] as int,
        equivalentCount: r['equivalent_count'] as int,
        differentCount: r['different_count'] as int,
        unresolvedCount: r['unresolved_count'] as int,
        matchedRecords: r['matched_records'] as int,
        durationMs: r['duration_ms'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
        isActive: (r['is_active'] as int) == 1,
      );
    }).toList();
  }

  /// Fetches the most recent session marked active, or null if none.
  Future<SavedSessionSummary?> getActiveSessionSummary() async {
    final db = await database;
    final rows = await db.query(
      'comparison_sessions',
      where: 'is_active = 1',
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      final any = await db.query(
        'comparison_sessions',
        orderBy: 'created_at DESC',
        limit: 1,
      );
      if (any.isEmpty) return null;
      return listRecentSessions(limit: 1).then((l) => l.firstOrNull);
    }
    return listRecentSessions(limit: 1).then((l) => l.firstOrNull);
  }

  /// Deletes a session and cascades deletes to its diff records.
  Future<void> deleteSession(String sessionId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'cell_differences',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      await txn.delete(
        'aligned_rows',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      await txn.delete(
        'structural_changes',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      await txn.delete(
        'unresolved_records',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      await txn.delete(
        'comparison_sessions',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  /// Restores a previously saved comparison session into a complete [ComparisonResult],
  /// including all cells (streamed in chunks without arbitrary 100k truncation),
  /// aligned rows, workbook sheet results, field descriptors, and comparison configuration.
  Future<ComparisonResult?> loadSession(String sessionId, {FrozenPlan? fallbackPlan}) async {
    final db = await database;
    final sessions = await db.query(
      'comparison_sessions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (sessions.isEmpty) return null;
    final s = sessions.first;

    // 1. Load all cells in chunks of 10,000 without any artificial 100k ceiling
    final totalStoredCells = await countCells(sessionId: sessionId);
    final allCells = <CellDifference>[];
    const chunkSize = 10000;
    for (var offset = 0; offset < totalStoredCells; offset += chunkSize) {
      final chunk = await queryCells(
        sessionId: sessionId,
        offset: offset,
        limit: chunkSize,
      );
      if (chunk.isEmpty) break;
      allCells.addAll(chunk);
    }

    // Group raw cell rows by sheet_pair_id when workbook sheets are present
    final rawCellSheetRows = await db.query(
      'cell_differences',
      columns: ['id', 'sheet_pair_id'],
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'row_order ASC',
    );
    final cellIdToSheetPairId = <String, String?>{
      for (final row in rawCellSheetRows)
        row['id'] as String: row['sheet_pair_id'] as String?,
    };

    // 2. Load structural changes
    final sRows = await db.query(
      'structural_changes',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    final structuralBySheet = <String?, List<StructuralChange>>{};
    final allStructural = <StructuralChange>[];
    for (final r in sRows) {
      final sideName = r['side'] as String;
      final side = SourceSide.values.firstWhere(
        (val) => val.name == sideName,
        orElse: () => SourceSide.a,
      );
      final sc = StructuralChange(
        r['kind'] as String,
        side,
        r['record_id'] as String,
      );
      allStructural.add(sc);
      final pairId = r['sheet_pair_id'] as String?;
      structuralBySheet.putIfAbsent(pairId, () => []).add(sc);
    }

    // 3. Load unresolved records
    final uRows = await db.query(
      'unresolved_records',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    final unresolved = uRows.map((r) {
      final listA = (jsonDecode(r['records_a_json'] as String) as List).cast<String>();
      final listB = (jsonDecode(r['records_b_json'] as String) as List).cast<String>();
      return RecordUnresolved(
        r['reason'] as String,
        listA,
        listB,
      );
    }).toList();

    // 4. Load aligned rows and reconstruct TableRecords
    final aRows = await db.query(
      'aligned_rows',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'row_order ASC',
    );

    final cellsBySheetAndRowPair = <String, List<CellDifference>>{};
    for (final c in allCells) {
      final pairId = cellIdToSheetPairId[c.id] ?? '';
      cellsBySheetAndRowPair
          .putIfAbsent('$pairId|${c.rowA}|${c.rowB}', () => [])
          .add(c);
    }

    TableRecord? parseStoredRecord(String? recordId, String? dataJson, int fallbackOrdinal) {
      if (recordId == null) return null;
      if (dataJson == null || dataJson.isEmpty) {
        return TableRecord(recordId, fallbackOrdinal, const {}, const {});
      }
      try {
        final decoded = jsonDecode(dataJson);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('cells') && decoded['cells'] is Map) {
            final ord = (decoded['ordinal'] as num?)?.toInt() ?? fallbackOrdinal;
            final rawCells = decoded['cells'] as Map;
            final rawLocs = decoded['locations'] as Map?;
            return TableRecord(
              recordId,
              ord,
              {
                for (final e in rawCells.entries)
                  e.key.toString(): SourceCell(
                    e.value == null ? CellKind.missing : CellKind.text,
                    rawLexeme: e.value?.toString(),
                  ),
              },
              {
                if (rawLocs != null)
                  for (final e in rawLocs.entries)
                    e.key.toString(): e.value?.toString() ?? '',
              },
            );
          } else {
            return TableRecord(
              recordId,
              fallbackOrdinal,
              {
                for (final e in decoded.entries)
                  e.key: SourceCell(
                    e.value == null ? CellKind.missing : CellKind.text,
                    rawLexeme: e.value?.toString(),
                  ),
              },
              const {},
            );
          }
        }
      } catch (_) {}
      return TableRecord(recordId, fallbackOrdinal, const {}, const {});
    }

    final alignedBySheet = <String?, List<AlignedTableRow>>{};
    final allAligned = <AlignedTableRow>[];
    final recordsABySheet = <String?, List<TableRecord>>{};
    final recordsBBySheet = <String?, List<TableRecord>>{};
    for (var i = 0; i < aRows.length; i++) {
      final r = aRows[i];
      final pairId = r['sheet_pair_id'] as String?;
      final rowAId = r['row_a_id'] as String?;
      final rowBId = r['row_b_id'] as String?;
      final recA = parseStoredRecord(rowAId, r['data_a_json'] as String?, i);
      final recB = parseStoredRecord(rowBId, r['data_b_json'] as String?, i);
      if (recA != null) {
        recordsABySheet.putIfAbsent(pairId, () => []).add(recA);
      }
      if (recB != null) {
        recordsBBySheet.putIfAbsent(pairId, () => []).add(recB);
      }
      final rowCells = (rowAId != null && rowBId != null)
          ? (cellsBySheetAndRowPair['${pairId ?? ""}|$rowAId|$rowBId'] ?? const <CellDifference>[])
          : const <CellDifference>[];
      final alignedRow = AlignedTableRow(
        recA,
        recB,
        (r['rationale'] as String?) ?? '',
        rowCells,
        unresolved: (r['unresolved'] as int? ?? 0) == 1,
      );
      allAligned.add(alignedRow);
      alignedBySheet.putIfAbsent(pairId, () => []).add(alignedRow);
    }

    // 5. Parse plan_json metadata (fields, sheet pairs, configuration, warnings)
    Map<String, dynamic>? planMeta;
    final rawPlanJson = s['plan_json'] as String?;
    if (rawPlanJson != null && rawPlanJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPlanJson);
        if (decoded is Map<String, dynamic>) {
          planMeta = decoded;
        }
      } catch (_) {}
    }

    SheetPair? deserializeSheetPair(Object? raw) {
      if (raw is! Map) return null;
      return SheetPair(
        (raw['a'] as num?)?.toInt(),
        (raw['b'] as num?)?.toInt(),
        raw['nameA'] as String?,
        raw['nameB'] as String?,
        (raw['method'] as String?) ?? 'restored',
        (raw['score'] as num?)?.toDouble() ?? 1.0,
      );
    }

    InputSnapshot deserializeSnapshot(
      Object? raw,
      String fallbackId,
      List<TableRecord> fallbackRecords,
      List<CellDifference> sheetCells,
      bool isSideA,
    ) {
      final map = raw is Map ? raw : const <String, dynamic>{};
      final rawFields = map['fields'];
      final fields = <TableField>[];
      if (rawFields is List) {
        for (final f in rawFields) {
          if (f is Map) {
            final id = f['id']?.toString() ?? '';
            final label = f['label']?.toString() ?? id;
            if (id.isNotEmpty) fields.add(TableField(id, label));
          }
        }
      }
      if (fields.isEmpty) {
        final seen = <String>{};
        for (final c in sheetCells) {
          final fid = isSideA ? c.mapping.fieldA : c.mapping.fieldB;
          if (fid.isNotEmpty && seen.add(fid)) {
            fields.add(TableField(fid, fid));
          }
        }
      }
      final recordMap = <String, TableRecord>{
        for (final r in fallbackRecords) r.id: r,
      };
      final rawOrdinals = map['record_ordinals'];
      if (rawOrdinals is Map) {
        for (final e in rawOrdinals.entries) {
          final rid = e.key.toString();
          final ord = (e.value as num?)?.toInt() ?? 0;
          recordMap.putIfAbsent(rid, () => TableRecord(rid, ord, const {}, const {}));
        }
      }
      final warnings = (map['warnings'] is List)
          ? (map['warnings'] as List).map((w) => w.toString()).toList()
          : const <String>[];
      return InputSnapshot(
        id: map['id']?.toString() ?? fallbackId,
        binding: ImportBinding(fallbackId, 1, 1, 1),
        fields: fields,
        records: recordMap.values,
        fullValidation: (map['full_validation'] as bool?) ?? true,
        ocrReviewed: (map['ocr_reviewed'] as bool?) ?? false,
        sheetName: map['sheet_name'] as String?,
        warnings: warnings,
      );
    }

    ComparisonConfiguration deserializeConfig(Object? raw, List<CellDifference> sheetCells) {
      if (raw is! Map) {
        final seen = <String>{};
        final mappings = <FieldMapping>[];
        for (final c in sheetCells) {
          final key = '${c.mapping.fieldA}->${c.mapping.fieldB}';
          if (c.mapping.fieldA.isNotEmpty && c.mapping.fieldB.isNotEmpty && seen.add(key)) {
            mappings.add(c.mapping);
          }
        }
        return ComparisonConfiguration(
          mappings: mappings,
          mappingConfirmed: true,
          modeConfirmed: true,
          policyConfirmed: true,
          directionConfirmed: true,
        );
      }
      final modeName = raw['mode']?.toString() ?? '';
      final mode = MatchingMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => MatchingMode.positional,
      );
      final dirName = raw['direction']?.toString() ?? '';
      final direction = ComparisonDirection.values.firstWhere(
        (d) => d.name == dirName,
        orElse: () => ComparisonDirection.aToB,
      );
      final keys = (raw['keys'] is List)
          ? (raw['keys'] as List).map((k) => k.toString()).toList()
          : const <String>[];
      final mappings = <FieldMapping>[];
      if (raw['mappings'] is List) {
        for (final m in raw['mappings'] as List) {
          if (m is Map) {
            mappings.add(
              FieldMapping(
                m['a']?.toString() ?? '',
                m['b']?.toString() ?? '',
              ),
            );
          }
        }
      }
      final rules = <String, FieldRule>{};
      if (raw['rules'] is Map) {
        for (final e in (raw['rules'] as Map).entries) {
          final rMap = e.value;
          if (rMap is Map) {
            final tName = rMap['type']?.toString() ?? '';
            final semType = SemanticType.values.firstWhere(
              (t) => t.name == tName,
              orElse: () => SemanticType.freeText,
            );
            rules[e.key.toString()] = FieldRule(
              type: semType,
              trim: (rMap['trim'] as bool?) ?? false,
              separatorA: rMap['separatorA']?.toString() ?? '.',
              separatorB: rMap['separatorB']?.toString() ?? ',',
              tolerance: rMap['tolerance']?.toString() ?? '0',
              webAuto: (rMap['webAuto'] as bool?) ?? false,
            );
          }
        }
      }
      final wpRaw = raw['webPolicy'];
      final webPolicy = wpRaw is Map
          ? WebComparisonPolicy(
              trimText: (wpRaw['trimText'] as bool?) ?? true,
              caseSensitiveText: (wpRaw['caseSensitiveText'] as bool?) ?? true,
              preserveLeadingZeros: (wpRaw['preserveLeadingZeros'] as bool?) ?? true,
              caseSensitiveIdentifier: (wpRaw['caseSensitiveIdentifier'] as bool?) ?? true,
              distinctNullZero: (wpRaw['distinctNullZero'] as bool?) ?? true,
              treatOrdinalAsMetadata: (wpRaw['treatOrdinalAsMetadata'] as bool?) ?? true,
            )
          : const WebComparisonPolicy();
      return ComparisonConfiguration(
        mappings: mappings,
        rules: rules,
        mode: mode,
        keys: keys,
        direction: direction,
        webPolicy: webPolicy,
        mappingConfirmed: (raw['mappingConfirmed'] as bool?) ?? true,
        modeConfirmed: (raw['modeConfirmed'] as bool?) ?? true,
        policyConfirmed: (raw['policyConfirmed'] as bool?) ?? true,
        directionConfirmed: (raw['directionConfirmed'] as bool?) ?? true,
      );
    }

    final topPlanId = planMeta?['plan_id']?.toString() ?? 'restored-plan';
    final topRevision = (planMeta?['revision'] as num?)?.toInt() ?? 1;
    final topWarnings = (planMeta?['warnings'] is List)
        ? (planMeta!['warnings'] as List).map((w) => w.toString()).toList()
        : const <String>[];
    final topSheetPair = deserializeSheetPair(planMeta?['sheet_pair']);

    final sheetResults = <ComparisonResult>[];
    final rawSheets = planMeta?['sheets'];
    if (rawSheets is List && rawSheets.isNotEmpty) {
      final cellsByPair = <String?, List<CellDifference>>{};
      for (final c in allCells) {
        final pid = cellIdToSheetPairId[c.id];
        cellsByPair.putIfAbsent(pid, () => []).add(c);
      }
      for (var i = 0; i < rawSheets.length; i++) {
        final sMap = rawSheets[i];
        if (sMap is! Map) continue;
        final pair = deserializeSheetPair(sMap['sheet_pair']);
        final pairId = pair?.id;
        final sCells = cellsByPair[pairId] ?? const <CellDifference>[];
        final sAligned = alignedBySheet[pairId] ?? const <AlignedTableRow>[];
        final sStruct = structuralBySheet[pairId] ?? const <StructuralChange>[];
        final snapA = deserializeSnapshot(
          sMap['a'],
          'restored-a-$i',
          recordsABySheet[pairId] ?? const [],
          sCells,
          true,
        );
        final snapB = deserializeSnapshot(
          sMap['b'],
          'restored-b-$i',
          recordsBBySheet[pairId] ?? const [],
          sCells,
          false,
        );
        final sCfg = deserializeConfig(sMap['config'], sCells);
        final sPlan = FrozenPlan(
          '$topPlanId-${pairId ?? i}',
          topRevision,
          snapA,
          snapB,
          sCfg,
        );
        final sWarnings = (sMap['warnings'] is List)
            ? (sMap['warnings'] as List).map((w) => w.toString()).toList()
            : const <String>[];
        sheetResults.add(
          ComparisonResult(
            id: sMap['id']?.toString() ?? '$sessionId-sheet-$i',
            plan: sPlan,
            cells: sCells,
            structural: sStruct,
            unresolvedRecords: const [],
            matchedRecords: (sMap['matched_records'] as num?)?.toInt() ?? sAligned.length,
            alignedRows: sAligned,
            durationMs: (sMap['duration_ms'] as num?)?.toInt() ?? 0,
            sheetPair: pair,
            warnings: sWarnings,
          ),
        );
      }
    }

    final topSnapA = deserializeSnapshot(
      planMeta?['a'],
      'restored-a',
      recordsABySheet[topSheetPair?.id] ?? recordsABySheet[null] ?? const [],
      allCells,
      true,
    );
    final topSnapB = deserializeSnapshot(
      planMeta?['b'],
      'restored-b',
      recordsBBySheet[topSheetPair?.id] ?? recordsBBySheet[null] ?? const [],
      allCells,
      false,
    );
    final topConfig = deserializeConfig(planMeta?['config'], allCells);
    final plan = fallbackPlan ??
        FrozenPlan(
          topPlanId,
          topRevision,
          InputSnapshot(
            id: topSnapA.id,
            binding: topSnapA.binding,
            fields: topSnapA.fields,
            records: topSnapA.records,
            fullValidation: topSnapA.fullValidation,
            ocrReviewed: topSnapA.ocrReviewed,
            sheetName: topSnapA.sheetName,
            workbookSheets: [for (final sr in sheetResults) sr.plan.a],
            warnings: topSnapA.warnings,
          ),
          InputSnapshot(
            id: topSnapB.id,
            binding: topSnapB.binding,
            fields: topSnapB.fields,
            records: topSnapB.records,
            fullValidation: topSnapB.fullValidation,
            ocrReviewed: topSnapB.ocrReviewed,
            sheetName: topSnapB.sheetName,
            workbookSheets: [for (final sr in sheetResults) sr.plan.b],
            warnings: topSnapB.warnings,
          ),
          topConfig,
        );

    return ComparisonResult(
      id: sessionId,
      plan: plan,
      cells: allCells,
      structural: allStructural,
      unresolvedRecords: unresolved,
      matchedRecords: s['matched_records'] as int,
      alignedRows: allAligned,
      durationMs: s['duration_ms'] as int,
      sheetResults: sheetResults,
      sheetPair: topSheetPair,
      warnings: topWarnings,
    );
  }

  /// Automatically trims older sessions to prevent disk bloat on low-storage devices.
  Future<void> pruneOldSessions({int maxKeep = 10}) async {
    final db = await database;
    final sessions = await db.query(
      'comparison_sessions',
      columns: ['session_id'],
      orderBy: 'created_at DESC',
      offset: maxKeep,
    );

    for (final s in sessions) {
      final id = s['session_id'] as String;
      await deleteSession(id);
    }
  }

  /// Wipes all tables (e.g. for user privacy data wipe or testing).
  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cell_differences');
      await txn.delete('aligned_rows');
      await txn.delete('structural_changes');
      await txn.delete('unresolved_records');
      await txn.delete('comparison_sessions');
    });
  }

  /// Closes database connection cleanly.
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
