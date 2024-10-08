import XCTest
import GRDB

// BadlyMangledStuff.updateFromRow() accepts a row with mangled column names.
// Its hasPersistentChangedValues flag is wrong.
class BadlyMangledStuff : Record {
    var id: Int64?
    var name: String?
    
    init(id: Int64? = nil, name: String? = nil) {
        self.id = id
        self.name = name
        super.init()
    }
    
    static func setup(_ db: Database) throws {
        try db.execute(sql: "CREATE TABLE stuffs (id INTEGER PRIMARY KEY, name TEXT)")
    }
    
    // Record
    
    override class var databaseTableName: String {
        "stuffs"
    }
    
    required init(row: Row) throws {
        // Here user may peek fancy column names that match his SQL queries.
        // However this is not the way to do it (see testBadlyMangledStuff()).
        id = row["mangled_id"]
        name = row["mangled_name"]
        try super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) throws {
        // User won't peek fancy column names because he will notice that the
        // generated INSERT query needs actual column names.
        container["id"] = id
        container["name"] = name
    }
    
    override func didInsert(_ inserted: InsertionSuccess) {
        super.didInsert(inserted)
        id = inserted.rowID
    }
}

class RecordWithColumnNameManglingTests: GRDBTestCase {
    
    override func setup(_ dbWriter: some DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createBadlyMangledStuff") {
            try BadlyMangledStuff.setup($0)
        }
        try migrator.migrate(dbWriter)
    }
    
    func testBadlyMangledStuff() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let record = BadlyMangledStuff()
                record.name = "foo"
                try record.save(db)
                
                // Nothing special here
                XCTAssertFalse(record.hasDatabaseChanges)
            }
            do {
                let record = try BadlyMangledStuff.fetchOne(db, sql: "SELECT id AS mangled_id, name AS mangled_name FROM stuffs")!
                // OK we could extract values.
                XCTAssertEqual(record.id, 1)
                XCTAssertEqual(record.name, "foo")
                
                // But here lies the problem with BadlyMangledStuff.
                // It should not be edited:
                XCTAssertTrue(record.hasDatabaseChanges)
            }
        }
    }
}
