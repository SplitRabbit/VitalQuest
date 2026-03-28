import Foundation
import SQLite3

/// Manages two SQLite databases for raw health samples:
/// - **Transactional (hot)**: 14-day retention, indexed for on-device queries and CreateML
/// - **Warehouse (cold)**: Long-term append-only store for analytics export
///
/// Both are written on ingest. The transactional DB is pruned daily.
/// The warehouse is optimized for bulk reads and never pruned automatically.
@Observable
final class RawSampleStore {

    private var transactionalDB: OpaquePointer?
    private var warehouseDB: OpaquePointer?

    let transactionalURL: URL
    let warehouseURL: URL

    private static let transactionalRetentionDays = 14

    // MARK: - Lifecycle

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbDir = docs.appendingPathComponent("RawSamples", isDirectory: true)
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)

        transactionalURL = dbDir.appendingPathComponent("transactional.sqlite")
        warehouseURL = dbDir.appendingPathComponent("warehouse.sqlite")

        openDatabase(at: transactionalURL, db: &transactionalDB)
        openDatabase(at: warehouseURL, db: &warehouseDB)

        createTransactionalSchema()
        createWarehouseSchema()
    }

    deinit {
        sqlite3_close(transactionalDB)
        sqlite3_close(warehouseDB)
    }

    // MARK: - Schema

    private func openDatabase(at url: URL, db: inout OpaquePointer?) {
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            print("RawSampleStore: Failed to open \(url.lastPathComponent)")
            return
        }
        // WAL mode for concurrent read/write
        sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA synchronous=NORMAL", nil, nil, nil)
    }

    private func createTransactionalSchema() {
        let sql = """
        CREATE TABLE IF NOT EXISTS raw_sample (
            id            TEXT PRIMARY KEY,
            metric_type   TEXT NOT NULL,
            start_date    REAL NOT NULL,
            end_date      REAL NOT NULL,
            value         REAL,
            value_unit    TEXT,
            source_name   TEXT,
            device_model  TEXT,
            ingested_at   REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_txn_type_date ON raw_sample(metric_type, start_date);
        CREATE INDEX IF NOT EXISTS idx_txn_date ON raw_sample(start_date);
        """
        sqlite3_exec(transactionalDB, sql, nil, nil, nil)
    }

    private func createWarehouseSchema() {
        let sql = """
        CREATE TABLE IF NOT EXISTS fact_sample (
            id            TEXT PRIMARY KEY,
            metric_type   TEXT NOT NULL,
            start_date    REAL NOT NULL,
            end_date      REAL NOT NULL,
            value         REAL,
            value_unit    TEXT,
            day_of_week   INTEGER,
            hour_of_day   INTEGER,
            date_key      TEXT,
            source_name   TEXT,
            source_bundle TEXT,
            device_name   TEXT,
            device_model  TEXT,
            metadata_json TEXT,
            ingested_at   REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_wh_date_key ON fact_sample(date_key);
        """
        sqlite3_exec(warehouseDB, sql, nil, nil, nil)
    }

    // MARK: - Ingest (Dual Write)

    struct SampleRecord {
        let id: String
        let metricType: String
        let startDate: Date
        let endDate: Date
        let value: Double?
        let valueUnit: String?
        let sourceName: String?
        let sourceBundle: String?
        let deviceName: String?
        let deviceModel: String?
        let metadataJSON: String?
    }

    /// Ingest samples into both transactional and warehouse databases.
    /// Uses INSERT OR IGNORE for zero-cost deduplication via HealthKit UUIDs.
    func ingest(_ records: [SampleRecord]) {
        guard !records.isEmpty else { return }
        let now = Date().timeIntervalSince1970

        ingestTransactional(records, ingestedAt: now)
        ingestWarehouse(records, ingestedAt: now)
    }

    private func ingestTransactional(_ records: [SampleRecord], ingestedAt: Double) {
        guard let db = transactionalDB else { return }

        let sql = """
        INSERT OR IGNORE INTO raw_sample
            (id, metric_type, start_date, end_date, value, value_unit, source_name, device_model, ingested_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return
        }

        for record in records {
            bindTransactionalRow(stmt: stmt!, record: record, ingestedAt: ingestedAt)
            sqlite3_step(stmt)
            sqlite3_reset(stmt)
        }

        sqlite3_finalize(stmt)
        sqlite3_exec(db, "COMMIT", nil, nil, nil)
    }

    private func bindTransactionalRow(stmt: OpaquePointer, record: SampleRecord, ingestedAt: Double) {
        bindText(stmt, index: 1, value: record.id)
        bindText(stmt, index: 2, value: record.metricType)
        sqlite3_bind_double(stmt, 3, record.startDate.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 4, record.endDate.timeIntervalSince1970)
        if let v = record.value {
            sqlite3_bind_double(stmt, 5, v)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        bindOptionalText(stmt, index: 6, value: record.valueUnit)
        bindOptionalText(stmt, index: 7, value: record.sourceName)
        bindOptionalText(stmt, index: 8, value: record.deviceModel)
        sqlite3_bind_double(stmt, 9, ingestedAt)
    }

    private func ingestWarehouse(_ records: [SampleRecord], ingestedAt: Double) {
        guard let db = warehouseDB else { return }

        let sql = """
        INSERT OR IGNORE INTO fact_sample
            (id, metric_type, start_date, end_date, value, value_unit,
             day_of_week, hour_of_day, date_key,
             source_name, source_bundle, device_name, device_model,
             metadata_json, ingested_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return
        }

        let calendar = Calendar.current

        for record in records {
            let weekday = calendar.component(.weekday, from: record.startDate)
            let hour = calendar.component(.hour, from: record.startDate)
            let dateKey = Self.dateKeyFormatter.string(from: record.startDate)

            bindText(stmt!, index: 1, value: record.id)
            bindText(stmt!, index: 2, value: record.metricType)
            sqlite3_bind_double(stmt!, 3, record.startDate.timeIntervalSince1970)
            sqlite3_bind_double(stmt!, 4, record.endDate.timeIntervalSince1970)
            if let v = record.value {
                sqlite3_bind_double(stmt!, 5, v)
            } else {
                sqlite3_bind_null(stmt!, 5)
            }
            bindOptionalText(stmt!, index: 6, value: record.valueUnit)
            sqlite3_bind_int(stmt!, 7, Int32(weekday))
            sqlite3_bind_int(stmt!, 8, Int32(hour))
            bindText(stmt!, index: 9, value: dateKey)
            bindOptionalText(stmt!, index: 10, value: record.sourceName)
            bindOptionalText(stmt!, index: 11, value: record.sourceBundle)
            bindOptionalText(stmt!, index: 12, value: record.deviceName)
            bindOptionalText(stmt!, index: 13, value: record.deviceModel)
            bindOptionalText(stmt!, index: 14, value: record.metadataJSON)
            sqlite3_bind_double(stmt!, 15, ingestedAt)

            sqlite3_step(stmt)
            sqlite3_reset(stmt)
        }

        sqlite3_finalize(stmt)
        sqlite3_exec(db, "COMMIT", nil, nil, nil)
    }

    // MARK: - Prune Transactional (14-day retention)

    func pruneTransactional() {
        guard let db = transactionalDB else { return }
        let cutoff = Date().addingTimeInterval(-Double(Self.transactionalRetentionDays) * 86400).timeIntervalSince1970
        let sql = "DELETE FROM raw_sample WHERE start_date < ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt!, 1, cutoff)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        sqlite3_exec(db, "PRAGMA incremental_vacuum", nil, nil, nil)
    }

    // MARK: - Query Transactional (for on-device analytics / CreateML)

    struct RawSampleRow {
        let id: String
        let metricType: String
        let startDate: Date
        let endDate: Date
        let value: Double?
        let valueUnit: String?
    }

    /// Query recent raw samples from the transactional store.
    func querySamples(
        metricType: String,
        from startDate: Date,
        to endDate: Date
    ) -> [RawSampleRow] {
        guard let db = transactionalDB else { return [] }

        let sql = """
        SELECT id, metric_type, start_date, end_date, value, value_unit
        FROM raw_sample
        WHERE metric_type = ? AND start_date >= ? AND start_date < ?
        ORDER BY start_date ASC
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }

        bindText(stmt!, index: 1, value: metricType)
        sqlite3_bind_double(stmt!, 2, startDate.timeIntervalSince1970)
        sqlite3_bind_double(stmt!, 3, endDate.timeIntervalSince1970)

        var rows: [RawSampleRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let type = String(cString: sqlite3_column_text(stmt, 1))
            let start = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
            let end = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
            let value: Double? = sqlite3_column_type(stmt, 4) != SQLITE_NULL ? sqlite3_column_double(stmt, 4) : nil
            let unit: String? = sqlite3_column_type(stmt, 5) != SQLITE_NULL ? String(cString: sqlite3_column_text(stmt, 5)) : nil

            rows.append(RawSampleRow(
                id: id, metricType: type,
                startDate: start, endDate: end,
                value: value, valueUnit: unit
            ))
        }
        sqlite3_finalize(stmt)
        return rows
    }

    // MARK: - Storage Stats

    var transactionalSizeBytes: Int64 {
        fileSize(at: transactionalURL)
    }

    var warehouseSizeBytes: Int64 {
        fileSize(at: warehouseURL)
    }

    func sampleCount(in db: DatabaseTarget) -> Int {
        let (dbPointer, table) = target(db)
        guard let pointer = dbPointer else { return 0 }
        let sql = "SELECT COUNT(*) FROM \(table)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(pointer, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int64(stmt, 0)) : 0
    }

    func dateRange(in db: DatabaseTarget) -> (earliest: Date, latest: Date)? {
        let (dbPointer, table) = target(db)
        guard let pointer = dbPointer else { return nil }
        let sql = "SELECT MIN(start_date), MAX(start_date) FROM \(table)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(pointer, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW,
              sqlite3_column_type(stmt, 0) != SQLITE_NULL else { return nil }
        return (
            earliest: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0)),
            latest: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
        )
    }

    enum DatabaseTarget {
        case transactional, warehouse
    }

    private func target(_ db: DatabaseTarget) -> (OpaquePointer?, String) {
        switch db {
        case .transactional: return (transactionalDB, "raw_sample")
        case .warehouse: return (warehouseDB, "fact_sample")
        }
    }

    // MARK: - Warehouse Safety Valve

    /// If the warehouse exceeds maxBytes, prune oldest data to keep it under budget.
    func enforceWarehouseSizeLimit(maxBytes: Int64 = 500_000_000) {
        guard warehouseSizeBytes > maxBytes, let db = warehouseDB else { return }

        // Delete oldest 25% by date
        let sql = """
        DELETE FROM fact_sample WHERE start_date < (
            SELECT start_date FROM fact_sample
            ORDER BY start_date ASC
            LIMIT 1
            OFFSET (SELECT COUNT(*) / 4 FROM fact_sample)
        )
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        sqlite3_exec(db, "VACUUM", nil, nil, nil)
    }

    // MARK: - SQLite Helpers

    private func bindText(_ stmt: OpaquePointer, index: Int32, value: String) {
        value.withCString { cStr in
            sqlite3_bind_text(stmt, index, cStr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
    }

    private func bindOptionalText(_ stmt: OpaquePointer, index: Int32, value: String?) {
        if let v = value {
            bindText(stmt, index: index, value: v)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func fileSize(at url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()
}
