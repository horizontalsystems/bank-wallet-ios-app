import RxSwift
import GRDB
import RxGRDB
import KeychainAccess
import HsToolKit

class GrdbStorage {
    private let dbPool: DatabasePool

    private let appConfigProvider: IAppConfigProvider

    init(appConfigProvider: IAppConfigProvider) {
        self.appConfigProvider = appConfigProvider

        let databaseURL = try! FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("bank.sqlite")

        dbPool = try! DatabasePool(path: databaseURL.path)

        try! migrator.migrate(dbPool)
    }

    var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("createAccountRecordsTable") { db in
            try db.create(table: AccountRecord_v_0_10.databaseTableName) { t in
                t.column(AccountRecord_v_0_10.Columns.id.name, .text).notNull()
                t.column(AccountRecord_v_0_10.Columns.name.name, .text).notNull()
                t.column(AccountRecord_v_0_10.Columns.type.name, .integer).notNull()
                t.column(AccountRecord_v_0_10.Columns.backedUp.name, .boolean).notNull()
                t.column(AccountRecord_v_0_10.Columns.defaultSyncMode.name, .text)
                t.column(AccountRecord_v_0_10.Columns.wordsKey.name, .text)
                t.column(AccountRecord_v_0_10.Columns.derivation.name, .integer)
                t.column(AccountRecord_v_0_10.Columns.saltKey.name, .text)
                t.column(AccountRecord_v_0_10.Columns.dataKey.name, .text)
                t.column(AccountRecord_v_0_10.Columns.eosAccount.name, .text)

                t.primaryKey([
                    AccountRecord_v_0_10.Columns.id.name
                ], onConflict: .replace)
            }
        }

        migrator.registerMigration("createEnabledWalletsTable") { db in
            try db.create(table: EnabledWallet_v_0_10.databaseTableName) { t in
                t.column("coinCode", .text).notNull()
                t.column(EnabledWallet_v_0_10.Columns.accountId.name, .text).notNull()
                t.column(EnabledWallet_v_0_10.Columns.syncMode.name, .text)
                t.column(EnabledWallet_v_0_10.Columns.walletOrder.name, .integer).notNull()

                t.primaryKey(["coinCode", EnabledWallet.Columns.accountId.name], onConflict: .replace)
            }
        }

        migrator.registerMigration("migrateAuthData") { db in
            let keychain = Keychain(service: "io.horizontalsystems.bank.dev")
            guard let data = try? keychain.getData("auth_data_keychain_key"), let authData = try? NSKeyedUnarchiver.unarchivedObject(ofClass: AuthData.self, from: data) else {
                return
            }
            try? keychain.remove("auth_data_keychain_key")

            let uuid = authData.walletId
            let isBackedUp = UserDefaults.standard.bool(forKey: "is_backed_up")
            let syncMode: SyncMode
            switch UserDefaults.standard.string(forKey: "sync_mode_key") ?? "" {
            case "fast": syncMode = .fast
            case "slow": syncMode = .slow
            case "new": syncMode = .new
            default: syncMode = .fast
            }

            let wordsKey = "mnemonic_\(uuid)_words"

            let accountRecord = AccountRecord_v_0_10(id: uuid, name: uuid, type: "mnemonic", backedUp: isBackedUp, defaultSyncMode: syncMode.rawValue, wordsKey: wordsKey, derivation: "bip44", saltKey: nil, dataKey: nil, eosAccount: nil)
            try accountRecord.insert(db)

            try? keychain.set(authData.words.joined(separator: ","), key: wordsKey)

            guard try db.tableExists("enabled_coins") else {
                return
            }

            let accountId = accountRecord.id
            try db.execute(sql: """
                                INSERT INTO \(EnabledWallet_v_0_10.databaseTableName)(`coinCode`, `\(EnabledWallet_v_0_10.Columns.accountId.name)`, `\(EnabledWallet_v_0_10.Columns.syncMode.name)`, `\(EnabledWallet_v_0_10.Columns.walletOrder.name)`)
                                SELECT `coinCode`, '\(accountId)', '\(syncMode)', `coinOrder` FROM enabled_coins
                                """)
            try db.drop(table: "enabled_coins")
        }

        migrator.registerMigration("reCreatePriceAlertRecordsTable") { db in
            if try db.tableExists(PriceAlertRecord.databaseTableName) {
                try db.drop(table: PriceAlertRecord.databaseTableName)
            }

            try db.create(table: PriceAlertRecord.databaseTableName) { t in
                t.column(PriceAlertRecord.Columns.coinCode.name, .text).notNull()
                t.column(PriceAlertRecord.Columns.changeState.name, .integer).notNull()
                t.column(PriceAlertRecord.Columns.trendState.name, .text).notNull()

                t.primaryKey([PriceAlertRecord.Columns.coinCode.name], onConflict: .replace)
            }
        }

        migrator.registerMigration("createPriceAlertRequestRecordsTable") { db in
            try db.create(table: PriceAlertRequestRecord.databaseTableName) { t in
                t.column(PriceAlertRequestRecord.Columns.topic.name, .text).notNull()
                t.column(PriceAlertRequestRecord.Columns.method.name, .integer).notNull()

                t.primaryKey([PriceAlertRequestRecord.Columns.topic.name, PriceAlertRequestRecord.Columns.method.name], onConflict: .replace)
            }
        }

        migrator.registerMigration("renameCoinCodeToCoinIdInEnabledWallets") { db in
            let tempTableName = "enabled_wallets_temp"

            try db.create(table: tempTableName) { t in
                t.column(EnabledWallet_v_0_10.Columns.coinId.name, .text).notNull()
                t.column(EnabledWallet_v_0_10.Columns.accountId.name, .text).notNull()
                t.column(EnabledWallet_v_0_10.Columns.syncMode.name, .text)
                t.column(EnabledWallet_v_0_10.Columns.walletOrder.name, .integer).notNull()

                t.primaryKey([EnabledWallet_v_0_10.Columns.coinId.name, EnabledWallet_v_0_10.Columns.accountId.name], onConflict: .replace)
            }

            try db.execute(sql: """
                                INSERT INTO \(tempTableName)(`\(EnabledWallet_v_0_10.Columns.coinId.name)`, `\(EnabledWallet_v_0_10.Columns.accountId.name)`, `\(EnabledWallet_v_0_10.Columns.syncMode.name)`, `\(EnabledWallet_v_0_10.Columns.walletOrder.name)`)
                                SELECT `coinCode`, `accountId`, `syncMode`, `walletOrder` FROM \(EnabledWallet_v_0_10.databaseTableName)
                                """)

            try db.drop(table: EnabledWallet_v_0_10.databaseTableName)
            try db.rename(table: tempTableName, to: EnabledWallet_v_0_10.databaseTableName)
        }

        migrator.registerMigration("moveCoinSettingsFromAccountToWallet") { db in
            var oldDerivation: String?
            var oldSyncMode: String?

            let oldAccounts = try AccountRecord_v_0_10.fetchAll(db)

            try db.drop(table: AccountRecord_v_0_10.databaseTableName)

            try db.create(table: AccountRecord.databaseTableName) { t in
                t.column(AccountRecord.Columns.id.name, .text).notNull()
                t.column(AccountRecord.Columns.name.name, .text).notNull()
                t.column(AccountRecord.Columns.type.name, .text).notNull()
                t.column(AccountRecord.Columns.origin.name, .text).notNull()
                t.column(AccountRecord.Columns.backedUp.name, .boolean).notNull()
                t.column(AccountRecord.Columns.wordsKey.name, .text)
                t.column(AccountRecord.Columns.saltKey.name, .text)
                t.column(AccountRecord.Columns.dataKey.name, .text)
                t.column(AccountRecord.Columns.eosAccount.name, .text)

                t.primaryKey([AccountRecord.Columns.id.name], onConflict: .replace)
            }

            for oldAccount in oldAccounts {
                let origin = oldAccount.defaultSyncMode == "new" ? "created" : "restored"

                let newAccount = AccountRecord(
                        id: oldAccount.id,
                        name: oldAccount.name,
                        type: oldAccount.type,
                        origin: origin,
                        backedUp: oldAccount.backedUp,
                        wordsKey: oldAccount.wordsKey,
                        saltKey: oldAccount.saltKey,
                        dataKey: oldAccount.dataKey,
                        eosAccount: oldAccount.eosAccount
                )

                try newAccount.insert(db)

                if let defaultSyncMode = oldAccount.defaultSyncMode, let derivation = oldAccount.derivation {
                    oldDerivation = derivation
                    oldSyncMode = defaultSyncMode
                }
            }

            let oldWallets = try EnabledWallet_v_0_10.fetchAll(db)

            try db.drop(table: EnabledWallet_v_0_10.databaseTableName)

            try db.create(table: EnabledWallet_v_0_13.databaseTableName) { t in
                t.column(EnabledWallet_v_0_13.Columns.coinId.name, .text).notNull()
                t.column(EnabledWallet_v_0_13.Columns.accountId.name, .text).notNull()
                t.column(EnabledWallet_v_0_13.Columns.derivation.name, .text)
                t.column(EnabledWallet_v_0_13.Columns.syncMode.name, .text)

                t.primaryKey([EnabledWallet_v_0_13.Columns.coinId.name, EnabledWallet_v_0_13.Columns.accountId.name], onConflict: .replace)
            }

            for oldWallet in oldWallets {
                var derivation: String?
                var syncMode: String?

                if let oldDerivation = oldDerivation, oldWallet.coinId == "BTC" {
                    derivation = oldDerivation
                }

                if let oldSyncMode = oldSyncMode, (oldWallet.coinId == "BTC" || oldWallet.coinId == "BCH" || oldWallet.coinId == "DASH") {
                    syncMode = oldSyncMode
                }

                let newWallet = EnabledWallet_v_0_13(
                        coinId: oldWallet.coinId,
                        accountId: oldWallet.accountId,
                        derivation: derivation,
                        syncMode: syncMode
                )

                try newWallet.insert(db)
            }
        }

        migrator.registerMigration("renameDaiCoinToSai") { db in
            guard let wallet = try EnabledWallet_v_0_13.filter(EnabledWallet_v_0_13.Columns.coinId == "DAI").fetchOne(db) else {
                return
            }

            let newWallet = EnabledWallet_v_0_13(
                    coinId: "SAI",
                    accountId: wallet.accountId,
                    derivation: wallet.derivation,
                    syncMode: wallet.syncMode
            )

            try wallet.delete(db)
            try newWallet.save(db)
        }

        migrator.registerMigration("createBlockchainSettings") { db in
            try db.create(table: BlockchainSettingRecord.databaseTableName) { t in
                t.column(BlockchainSettingRecord.Columns.coinType.name, .text).notNull()
                t.column(BlockchainSettingRecord.Columns.key.name, .text).notNull()
                t.column(BlockchainSettingRecord.Columns.value.name, .text).notNull()

                t.primaryKey([BlockchainSettingRecord.Columns.coinType.name, BlockchainSettingRecord.Columns.key.name], onConflict: .replace)
            }
        }

        migrator.registerMigration("fillBlockchainSettingsFromEnabledWallets") { db in
            let wallets = try EnabledWallet_v_0_13.filter(EnabledWallet_v_0_13.Columns.coinId == "BTC" ||
                    EnabledWallet_v_0_13.Columns.coinId == "LTC" ||
                    EnabledWallet_v_0_13.Columns.coinId == "BCH" ||
                    EnabledWallet_v_0_13.Columns.coinId == "DASH").fetchAll(db)

            let derivationSettings: [BlockchainSettingRecord] = wallets.compactMap { [weak self] wallet in
                guard
                        let coin = self?.appConfigProvider.defaultCoins.first(where: { $0.id == wallet.coinId }),
                        let coinTypeKey = BlockchainSetting.key(for: coin.type),
                        let derivation = wallet.derivation
                        else {
                    return nil
                }

                return BlockchainSettingRecord(coinType: coinTypeKey, key: "derivation", value: derivation)
            }
            let syncSettings: [BlockchainSettingRecord] = wallets.compactMap { [weak self] wallet in
                guard
                        let coin = self?.appConfigProvider.defaultCoins.first(where: { $0.id == wallet.coinId }),
                        let coinTypeKey = BlockchainSetting.key(for: coin.type),
                        let syncMode = wallet.syncMode
                        else {
                    return nil
                }

                return BlockchainSettingRecord(coinType: coinTypeKey, key: "sync_mode", value: syncMode)
            }

            for setting in derivationSettings + syncSettings {
                try setting.insert(db)
            }
        }

        migrator.registerMigration("createCoins") { db in
            try db.create(table: CoinRecord.databaseTableName) { t in
                t.column(CoinRecord.Columns.coinId.name, .text).notNull()
                t.column(CoinRecord.Columns.title.name, .text).notNull()
                t.column(CoinRecord.Columns.code.name, .text).notNull()
                t.column(CoinRecord.Columns.decimal.name, .integer).notNull()
                t.column(CoinRecord.Columns.tokenType.name, .text).notNull()
                t.column(CoinRecord.Columns.erc20Address.name, .text)

                t.primaryKey([CoinRecord.Columns.coinId.name], onConflict: .replace)
            }
        }

        return migrator
    }

}

extension GrdbStorage: IEnabledWalletStorage {

    var enabledWallets: [EnabledWallet] {
        try! dbPool.read { db in
            try EnabledWallet.fetchAll(db)
        }
    }

    func save(enabledWallets: [EnabledWallet]) {
        _ = try! dbPool.write { db in
            for enabledWallet in enabledWallets {
                try enabledWallet.insert(db)
            }
        }
    }

    func delete(enabledWallets: [EnabledWallet]) {
        _ = try! dbPool.write { db in
            for enabledWallet in enabledWallets {
                try EnabledWallet.filter(EnabledWallet.Columns.coinId == enabledWallet.coinId && EnabledWallet.Columns.accountId == enabledWallet.accountId).deleteAll(db)
            }
        }
    }

    func clearEnabledWallets() {
        _ = try! dbPool.write { db in
            try EnabledWallet.deleteAll(db)
        }
    }

}

extension GrdbStorage: IAccountRecordStorage {

    var allAccountRecords: [AccountRecord] {
        return try! dbPool.read { db in
            try AccountRecord.fetchAll(db)
        }
    }

    func save(accountRecord: AccountRecord) {
        _ = try! dbPool.write { db in
            try accountRecord.insert(db)
        }
    }

    func deleteAccountRecord(by id: String) {
        _ = try! dbPool.write { db in
            try AccountRecord.filter(AccountRecord.Columns.id == id).deleteAll(db)
        }
    }

    func deleteAllAccountRecords() {
        _ = try! dbPool.write { db in
            try AccountRecord.deleteAll(db)
        }
    }

}

extension GrdbStorage: IPriceAlertRecordStorage {

    var priceAlertRecords: [PriceAlertRecord] {
        try! dbPool.read { db in
            try PriceAlertRecord.fetchAll(db)
        }
    }

    func priceAlertRecord(forCoinCode coinCode: String) -> PriceAlertRecord? {
        try! dbPool.read { db in
            try PriceAlertRecord.filter(PriceAlertRecord.Columns.coinCode == coinCode).fetchOne(db)
        }
    }

    func save(priceAlertRecords: [PriceAlertRecord]) {
        _ = try! dbPool.write { db in
            for record in priceAlertRecords {
                try record.insert(db)
            }
        }
    }

    func deleteAllPriceAlertRecords() {
        _ = try! dbPool.write { db in
            try PriceAlertRecord.deleteAll(db)
        }
    }

}

extension GrdbStorage: IPriceAlertRequestRecordStorage {

    var priceAlertRequestRecords: [PriceAlertRequestRecord] {
        try! dbPool.read { db in
            try PriceAlertRequestRecord.fetchAll(db)
        }
    }

    func save(priceAlertRequestRecords: [PriceAlertRequestRecord]) {
        _ = try! dbPool.write { db in
            for record in priceAlertRequestRecords {
                try record.insert(db)
            }
        }
    }

    func delete(priceAlertRequestRecords: [PriceAlertRequestRecord]) {
        _ = try! dbPool.write { db in
            for priceAlertRequestRecord in priceAlertRequestRecords {
                try priceAlertRequestRecord.delete(db)
            }
        }
    }

}

extension GrdbStorage: IBlockchainSettingsRecordStorage {

    func blockchainSettings(coinTypeKey: String, settingKey: String) -> BlockchainSettingRecord? {
        try? dbPool.read { db in
            try BlockchainSettingRecord.filter(BlockchainSettingRecord.Columns.coinType == coinTypeKey && BlockchainSettingRecord.Columns.key == settingKey).fetchOne(db)
        }
    }

    func save(blockchainSettings: [BlockchainSettingRecord]) {
        _ = try! dbPool.write { db in
            for setting in blockchainSettings {
                try setting.insert(db)
            }
        }
    }

    func deleteAll(settingKey: String) {
        _ = try! dbPool.write { db in
            try BlockchainSettingRecord.filter(BlockchainSettingRecord.Columns.key == settingKey).deleteAll(db)
        }
    }

}

extension GrdbStorage: ICoinRecordStorage {

    var coinRecords: [CoinRecord] {
        try! dbPool.read { db in
            try CoinRecord.order(CoinRecord.Columns.title.asc).fetchAll(db)
        }
    }

    func save(coinRecord: CoinRecord) {
        _ = try! dbPool.write { db in
            try coinRecord.insert(db)
        }
    }

}

extension GrdbStorage: ILogStorage {
    func log(date: Date, level: Logger.Level, message: String, file: String?, function: String?, line: Int?, context: [String]?) {
        print("\(date) \(level) \(context?.joined(separator: " ")) \(message)")
    }
}
