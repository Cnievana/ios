//
//  NCManageDatabase.swift
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 06/05/17.
//  Copyright © 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import RealmSwift

class NCManageDatabase: NSObject {
        
    static let sharedInstance: NCManageDatabase = {
        let instance = NCManageDatabase()
        return instance
    }()
    
    override init() {
        
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.sharedInstance.capabilitiesGroups)
        
        let configCompact = Realm.Configuration(
            
            fileURL: dirGroup?.appendingPathComponent("\(appDatabaseNextcloud)/\(k_databaseDefault)"),
            
            shouldCompactOnLaunch: { totalBytes, usedBytes in
            // totalBytes refers to the size of the file on disk in bytes (data + free space)
            // usedBytes refers to the number of bytes used by data in the file
            
            // Compact if the file is over 100MB in size and less than 50% 'used'
            let oneHundredMB = 100 * 1024 * 1024
            return (totalBytes > oneHundredMB) && (Double(usedBytes) / Double(totalBytes)) < 0.5
        })
        
        do {
            // Realm is compacted on the first open if the configuration block conditions were met.
            _ = try Realm(configuration: configCompact)
        } catch {
            // handle error compacting or opening Realm
        }
        
        let config = Realm.Configuration(
        
            fileURL: dirGroup?.appendingPathComponent("\(appDatabaseNextcloud)/\(k_databaseDefault)"),
            schemaVersion: 6,
            
            migrationBlock: { migration, oldSchemaVersion in
                // We haven’t migrated anything yet, so oldSchemaVersion == 0
                if (oldSchemaVersion < 6) {
                    // Nothing to do!
                    // Realm will automatically detect new properties and removed properties
                    // And will update the schema on disk automatically
                }
        })

        Realm.Configuration.defaultConfiguration = config
        _ = try! Realm()
    }
    
    //MARK: -
    //MARK: Utility Database

    func clearTable(_ table : Object.Type, account: String?) {
        
        let results : Results<Object>
        let realm = try! Realm()
        
        realm.beginWrite()
        
        if let account = account {
            results = realm.objects(table).filter("account = %@", account)
        } else {
            results = realm.objects(table)
        }
        
        realm.delete(results)

        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    func removeDB() {
        
        let realmURL = Realm.Configuration.defaultConfiguration.fileURL!
        let realmURLs = [
            realmURL,
            realmURL.appendingPathExtension("lock"),
            realmURL.appendingPathExtension("note"),
            realmURL.appendingPathExtension("management")
        ]
        for URL in realmURLs {
            do {
                try FileManager.default.removeItem(at: URL)
            } catch let error {
                print("[LOG] Could not write to database: ", error)
            }
        }
    }
    
    func getThreadConfined(_ table: Object) -> Any {
     
        // id tradeReference = [[NCManageDatabase sharedInstance] getThreadConfined:metadata];
        return ThreadSafeReference(to: table)
    }
    
    func putThreadConfined(_ tableRef: Any) -> Object? {
        
        //tableMetadata *metadataThread = (tableMetadata *)[[NCManageDatabase sharedInstance] putThreadConfined:tradeReference];
        let realm = try! Realm()
        
        return realm.resolve(tableRef as! ThreadSafeReference<Object>)
    }
    
    func isTableInvalidated(_ table: Object) -> Bool {
     
        return table.isInvalidated
    }
    
    //MARK: -
    //MARK: Table Account
    
    func addAccount(_ account: String, url: String, user: String, password: String) {

        let realm = try! Realm()
        
        realm.beginWrite()
            
        let addObject = tableAccount()
            
        addObject.account = account
            
        // Brand
        if NCBrandOptions.sharedInstance.use_default_auto_upload {
                
            addObject.autoUpload = true
            addObject.autoUploadImage = true
            addObject.autoUploadVideo = true

            addObject.autoUploadWWAnVideo = true
        }
            
        addObject.password = password
        addObject.url = url
        addObject.user = user
        addObject.username = user

        realm.add(addObject)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    func setAccountPassword(_ account: String, password: String) -> tableAccount? {
        
        let realm = try! Realm()
        
        realm.beginWrite()

        guard let result = realm.objects(tableAccount.self).filter("account = %@", account).first else {
            realm.cancelWrite()
            return nil
        }
        
        result.password = password
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }
        
        return result
    }
    
    func deleteAccount(_ account: String) {
        
        let realm = try! Realm()
        
        realm.beginWrite()

        guard let result = realm.objects(tableAccount.self).filter("account = %@", account).first else {
            realm.cancelWrite()
            return
        }
        
        realm.delete(result)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }

    func getAccountActive() -> tableAccount? {
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableAccount.self).filter("active = true").first else {
            return nil
        }
        
        return result
    }

    func getAccounts() -> [String]? {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAccount.self).sorted(byKeyPath: "account", ascending: true)
        
        if results.count > 0 {
            return Array(results.map { $0.account })
        }
        
        return nil
    }
    
    func getAccount(predicate: NSPredicate) -> tableAccount? {
        
        let realm = try! Realm()
        
        if let result = realm.objects(tableAccount.self).filter(predicate).first {
            return tableAccount.init(value: result)
        }
        
        return nil
    }
    
    func getAccountAutoUploadFileName() -> String {
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableAccount.self).filter("active = true").first else {
            return ""
        }
        
        if result.autoUploadFileName.characters.count > 0 {
            return result.autoUploadFileName
        } else {
            return NCBrandOptions.sharedInstance.folderDefaultAutoUpload
        }
    }
    
    func getAccountAutoUploadDirectory(_ activeUrl : String) -> String {
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableAccount.self).filter("active = true").first else {
            return ""
        }
        
        if result.autoUploadDirectory.characters.count > 0 {
            return result.autoUploadDirectory
        } else {
            return CCUtility.getHomeServerUrlActiveUrl(activeUrl)
        }
    }

    func getAccountAutoUploadPath(_ activeUrl : String) -> String {
        
        let cameraFileName = self.getAccountAutoUploadFileName()
        let cameraDirectory = self.getAccountAutoUploadDirectory(activeUrl)
     
        let folderPhotos = CCUtility.stringAppendServerUrl(cameraDirectory, addFileName: cameraFileName)!
        
        return folderPhotos
    }
    
    func setAccountActive(_ account: String) -> tableAccount {
        
        let realm = try! Realm()
        
        var activeAccount = tableAccount()
        
        do {
            try realm.write {
            
                let results = realm.objects(tableAccount.self)

                for result in results {
                
                    if result.account == account {
                    
                        result.active = true
                        activeAccount = result
                    
                    } else {
                    
                        result.active = false
                    }
                }
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
        
        return activeAccount
    }

    func setAccountAutoUploadProperty(_ property: String, state: Bool) {
        
        let realm = try! Realm()
        
        realm.beginWrite()

        guard let result = realm.objects(tableAccount.self).filter("active = true").first else {
            realm.cancelWrite()
            return
        }
        
        if (tableAccount().objectSchema.properties.contains { $0.name == property }) {
            
            result[property] = state
            
            do {
                try realm.commitWrite()
            } catch let error {
                print("[LOG] Could not write to database: ", error)
            }
        } else {
            print("property not found")
        }
    }
    
    func setAccountAutoUploadFileName(_ fileName: String?) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                if let result = realm.objects(tableAccount.self).filter("active = true").first {
                    
                    if let fileName = fileName {
                        
                        result.autoUploadFileName = fileName
                        
                    } else {
                        
                        result.autoUploadFileName = self.getAccountAutoUploadFileName()
                    }
                }
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
    }

    func setAccountAutoUploadDirectory(_ serverUrl: String?, activeUrl: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                if let result = realm.objects(tableAccount.self).filter("active = true").first {
                    
                    if let serverUrl = serverUrl {
                        
                        result.autoUploadDirectory = serverUrl
                        
                    } else {
                        
                        result.autoUploadDirectory = self.getAccountAutoUploadDirectory(activeUrl)
                    }
                }
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
    }
    
    func setAccountsUserProfile(_ userProfile: OCUserProfile) {
     
        guard let tblAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                guard let result = realm.objects(tableAccount.self).filter("account = %@", tblAccount.account).first else {
                    return
                }
                
                // Copy user -> username 
                // https://github.com/nextcloud/ios/issues/331
                if result.username.characters.count == 0 {
                    result.username = result.user
                }
                
                // Update user with ID
                if userProfile.id.characters.count > 0 {
                    result.user = userProfile.id
                }
                
                result.enabled = userProfile.enabled
                result.address = userProfile.address
                result.displayName = userProfile.displayName
                result.email = userProfile.email
                result.phone = userProfile.phone
                result.twitter = userProfile.twitter
                result.webpage = userProfile.webpage
                
                result.quota = userProfile.quota
                result.quotaFree = userProfile.quotaFree
                result.quotaRelative = userProfile.quotaRelative
                result.quotaTotal = userProfile.quotaTotal
                result.quotaUsed = userProfile.quotaUsed
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
    }
    
    //MARK: -
    //MARK: Table Activity

    func getActivity(predicate: NSPredicate) -> [tableActivity] {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableActivity.self).filter(predicate).sorted(byKeyPath: "date", ascending: false)
        
        return Array(results.map { tableActivity.init(value:$0) })
    }

    func addActivityServer(_ listOfActivity: [OCActivity]) {
    
        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {
            
                for activity in listOfActivity {
                    
                    if realm.objects(tableActivity.self).filter("idActivity = %d", activity.idActivity).first == nil {
                        
                        // Add new Activity
                        let addObject = tableActivity()
                
                        addObject.account = tableAccount.account
                
                        if let date = activity.date {
                            addObject.date = date as NSDate
                        }
                        
                        addObject.idActivity = Double(activity.idActivity)
                        addObject.link = activity.link
                        addObject.note = activity.subject
                        addObject.type = k_activityTypeInfo

                        realm.add(addObject)
                    }
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    func addActivityClient(_ file: String, fileID: String, action: String, selector: String, note: String, type: String, verbose: Bool, activeUrl: String?) {

        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        var noteReplacing : String = ""
        
        if let activeUrl = activeUrl {
            noteReplacing = note.replacingOccurrences(of: "\(activeUrl)\(webDAV)", with: "")
        }
        
        noteReplacing = note.replacingOccurrences(of: "\(k_domain_session_queue).", with: "")

        let realm = try! Realm()
        
        if realm.isInWriteTransaction {
        
            print("[LOG] Could not write to database, addActivityClient is already in write transaction")
            
        } else {
            
            do {
                try realm.write {
                
                    // Add new Activity
                    let addObject = tableActivity()
                
                    addObject.account = tableAccount.account
                    addObject.action = action
                    addObject.file = file
                    addObject.fileID = fileID
                    addObject.note = noteReplacing
                    addObject.selector = selector
                    addObject.type = type
                    addObject.verbose = verbose
                
                    realm.add(addObject)
                }
            } catch let error {
                print("[LOG] Could not write to database: ", error)
            }
        }
    }
    
    //MARK: -
    //MARK: Table Capabilities
    
    func addCapabilities(_ capabilities: OCCapabilities) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }

        let realm = try! Realm()
        
        do {
            try realm.write {
            
                let result = realm.objects(tableCapabilities.self).filter("account = %@", tableAccount.account).first

                var resultCapabilities = tableCapabilities()
            
                if let result = result {
                    resultCapabilities = result
                }
                
                resultCapabilities.account = tableAccount.account
                resultCapabilities.themingBackground = capabilities.themingBackground
                resultCapabilities.themingColor = capabilities.themingColor
                resultCapabilities.themingLogo = capabilities.themingLogo
                resultCapabilities.themingName = capabilities.themingName
                resultCapabilities.themingSlogan = capabilities.themingSlogan
                resultCapabilities.themingUrl = capabilities.themingUrl
                resultCapabilities.versionMajor = capabilities.versionMajor
                resultCapabilities.versionMinor = capabilities.versionMinor
                resultCapabilities.versionMicro = capabilities.versionMicro
                resultCapabilities.versionString = capabilities.versionString
            
                if result == nil {
                    realm.add(resultCapabilities)
                }
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
    }
    
    func getCapabilites() -> tableCapabilities? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }
        
        let realm = try! Realm()

        return realm.objects(tableCapabilities.self).filter("account = %@", tableAccount.account).first
    }
    
    func getServerVersion() -> Int {

        guard let tableAccount = self.getAccountActive() else {
            return 0
        }

        let realm = try! Realm()
        
        guard let result = realm.objects(tableCapabilities.self).filter("account = %@", tableAccount.account).first else {
            return 0
        }

        return result.versionMajor
    }

    func compareServerVersion(_ versionCompare: String) -> Int {
        
        guard let tableAccount = self.getAccountActive() else {
            return 0
        }
        
        let realm = try! Realm()
        
        guard let capabilities = realm.objects(tableCapabilities.self).filter("account = %@", tableAccount.account).first else {
            return -1
        }
        
        let versionServer = capabilities.versionString
        
        var v1 = versionServer.characters.split(separator:".").map { Int(String($0)) }
        var v2 = versionCompare.characters.split(separator:".").map { Int(String($0)) }
        
        var result = 0
        for i in 0..<max(v1.count,v2.count) {
            let left = i >= v1.count ? 0 : v1[i]
            let right = i >= v2.count ? 0 : v2[i]
            
            if (left == right) {
                result = 0
            } else if left! > right! {
                return 1
            } else if right! > left! {
                return -1
            }
        }
        return result
    }
    
    //MARK: -
    //MARK: Table Certificates
    
    func addCertificates(_ certificateLocation: String) {
    
        let realm = try! Realm()
        
        do {
            try realm.write {

                let addObject = tableCertificates()
            
                addObject.certificateLocation = certificateLocation
            
                realm.add(addObject)
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
    }
    
    func getCertificatesLocation(_ localCertificatesFolder: String) -> [String] {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableCertificates.self)
    
        return Array(results.map { "\(localCertificatesFolder)\($0.certificateLocation)" })
    }
    
    //MARK: -
    //MARK: Table Directory
    
    func addDirectory(serverUrl: String, permissions: String?) -> String {
        
        guard let tableAccount = self.getAccountActive() else {
            return ""
        }
        
        let realm = try! Realm()
        
        var directoryID: String = ""

        do {
            try realm.write {
            
                let result = realm.objects(tableDirectory.self).filter("account = %@ AND serverUrl = %@", tableAccount.account, serverUrl).first
            
                if result == nil || (result?.isInvalidated)! {
                
                    let addObject = tableDirectory()
                    addObject.account = tableAccount.account
                
                    directoryID = NSUUID().uuidString
                    addObject.directoryID = directoryID
                
                    if let permissions = permissions {
                        addObject.permissions = permissions
                    }
                    addObject.serverUrl = serverUrl
                    realm.add(addObject, update: true)
                
                } else {
                
                    if let permissions = permissions {
                        result!.permissions = permissions
                    }
                    directoryID = result!.directoryID
                    realm.add(result!, update: true)
                }
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
        
        return directoryID
    }
    
    func deleteDirectoryAndSubDirectory(serverUrl: String) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableDirectory.self).filter("account = %@ AND serverUrl BEGINSWITH %@", tableAccount.account, serverUrl)
        
        // Delete table Metadata & LocalFile
        for result in results {
            
            self.deleteMetadata(predicate: NSPredicate(format: "directoryID = %@", result.directoryID), clearDateReadDirectoryID: result.directoryID)
            
            self.deleteLocalFile(predicate: NSPredicate(format: "fileID = %@", result.fileID))
        }
        
        // Delete table Dirrectory
        do {
            try realm.write {
                realm.delete(results)
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
    }
    
    func setDirectory(serverUrl: String, serverUrlTo: String?, etag: String?) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {
            
                guard let result = realm.objects(tableDirectory.self).filter("account = %@ AND serverUrl = %@", tableAccount.account, serverUrl).first else {
                    return
                }
                
                if let serverUrlTo = serverUrlTo {
                    result.serverUrl = serverUrlTo

                }
                if let etag = etag {
                    result.etag = etag
                }
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
    }
    
    func clearDateRead(serverUrl: String?, directoryID: String?) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {

                var predicate = NSPredicate()
            
                if let serverUrl = serverUrl {
                    predicate = NSPredicate(format: "account = %@ AND serverUrl = %@", tableAccount.account, serverUrl)
                }
                
                if let directoryID = directoryID {
                    predicate = NSPredicate(format: "account = %@ AND directoryID = %@", tableAccount.account, directoryID)
                }
            
                guard let result = realm.objects(tableDirectory.self).filter(predicate).first else {
                    return
                }
                
                result.dateReadDirectory = nil
                result.etag = ""
                realm.add(result, update: true)
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
    }
    
    func getTableDirectory(predicate: NSPredicate) -> tableDirectory? {
        
        guard self.getAccountActive() != nil else {
            return nil
        }
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableDirectory.self).filter(predicate).first else {
            return nil
        }
        
        return tableDirectory.init(value: result)
    }
    
    func getTablesDirectory(predicate: NSPredicate, sorted: String, ascending: Bool) -> [tableDirectory]? {
        
        guard self.getAccountActive() != nil else {
            return nil
        }
        
        let realm = try! Realm()
        let results = realm.objects(tableDirectory.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
        
        if (results.count > 0) {
            return Array(results.map { tableDirectory.init(value:$0) })
        } else {
            return nil
        }
    }
    
    func getDirectoryID(_ serverUrl: String?) -> String? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }
        
        guard let serverUrl = serverUrl else {
            return nil
        }
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableDirectory.self).filter("account = %@ AND serverUrl = %@", tableAccount.account,serverUrl).first else {
            return self.addDirectory(serverUrl: serverUrl, permissions: nil)
        }
        
        return result.directoryID
    }
    
    func getServerUrl(_ directoryID: String?) -> String? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }
        
        guard let directoryID = directoryID else {
            return nil
        }
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableDirectory.self).filter("account = %@ AND directoryID = %@", tableAccount.account, directoryID).first else {
            return nil
        }
        
        return result.serverUrl
    }
    
    func setDateReadDirectory(directoryID: String) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        realm.beginWrite()
        
        guard let result = realm.objects(tableDirectory.self).filter("account = %@ AND directoryID = %@", tableAccount.account, directoryID).first else {
            realm.cancelWrite()
            return
        }
            
        result.dateReadDirectory = NSDate()
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    func setClearAllDateReadDirectory() {
        
        guard self.getAccountActive() != nil else {
            return
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {
            
                let results = realm.objects(tableDirectory.self)

                for result in results {
                    result.dateReadDirectory = nil;
                    result.etag = ""
                }
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
    }
    
    func setDirectoryLock(serverUrl: String, lock: Bool) -> Bool {
        
        guard let tableAccount = self.getAccountActive() else {
            return false
        }
        
        let realm = try! Realm()
        
        var update = false
        
        do {
            try realm.write {
            
                guard let result = realm.objects(tableDirectory.self).filter("account = %@ AND serverUrl = %@", tableAccount.account, serverUrl).first else {
                    realm.cancelWrite()
                    return
                }
                
                result.lock = lock
                update = true
            }
        } catch let error {
            print("Could not write to database: ", error)
            return false
        }
        
        return update
    }
    
    func setAllDirectoryUnLock() {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }

        let realm = try! Realm()
        
        do {
            try realm.write {
            
                let results = realm.objects(tableDirectory.self).filter("account = %@", tableAccount.account)

                for result in results {
                    result.lock = false;
                }
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
    }

    //MARK: -
    //MARK: Table External Sites
    
    func addExternalSites(_ externalSites: OCExternalSites) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()

        do {
            try realm.write {
            
                let addObject = tableExternalSites()
            
                addObject.account = tableAccount.account
                addObject.idExternalSite = externalSites.idExternalSite
                addObject.icon = externalSites.icon
                addObject.lang = externalSites.lang
                addObject.name = externalSites.name
                addObject.url = externalSites.url
                addObject.type = externalSites.type
           
                realm.add(addObject)
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
    }

    func deleteExternalSites() {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {
            
                let results = realm.objects(tableExternalSites.self).filter("account = %@", tableAccount.account)

                realm.delete(results)
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
    }
    
    func getAllExternalSites(predicate: NSPredicate) -> [tableExternalSites] {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableExternalSites.self).filter(predicate).sorted(byKeyPath: "idExternalSite", ascending: true)
        
        return Array(results)
    }

    //MARK: -
    //MARK: Table GPS
    
    func addGeocoderLocation(_ location: String, placemarkAdministrativeArea: String, placemarkCountry: String, placemarkLocality: String, placemarkPostalCode: String, placemarkThoroughfare: String, latitude: String, longitude: String) {

        let realm = try! Realm()

        realm.beginWrite()

        // Verify if exists
        guard realm.objects(tableGPS.self).filter("latitude = %@ AND longitude = %@", latitude, longitude).first == nil else {
            realm.cancelWrite()
            return
        }
        
        // Add new GPS
        let addObject = tableGPS()
            
        addObject.latitude = latitude
        addObject.location = location
        addObject.longitude = longitude
        addObject.placemarkAdministrativeArea = placemarkAdministrativeArea
        addObject.placemarkCountry = placemarkCountry
        addObject.placemarkLocality = placemarkLocality
        addObject.placemarkPostalCode = placemarkPostalCode
        addObject.placemarkThoroughfare = placemarkThoroughfare
            
        realm.add(addObject)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    func getLocationFromGeoLatitude(_ latitude: String, longitude: String) -> String? {
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableGPS.self).filter("latitude = %@ AND longitude = %@", latitude, longitude).first else {
            return nil
        }
        
        return result.location
    }

    //MARK: -
    //MARK: Table LocalFile
    
    func addLocalFile(metadata: tableMetadata) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {
            
                let addObject = tableLocalFile()
            
                addObject.account = tableAccount.account
                addObject.date = metadata.date
                addObject.etag = metadata.etag
                addObject.exifDate = NSDate()
                addObject.exifLatitude = "-1"
                addObject.exifLongitude = "-1"
                addObject.fileID = metadata.fileID
                addObject.fileName = metadata.fileName
                addObject.fileNamePrint = metadata.fileNamePrint
                addObject.size = metadata.size
            
                realm.add(addObject, update: true)
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
    }
    
    func deleteLocalFile(predicate: NSPredicate) {
        
        guard self.getAccountActive() != nil else {
            return
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {

                let results = realm.objects(tableLocalFile.self).filter(predicate)

                realm.delete(results)
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
    }
    
    func setLocalFile(fileID: String, date: NSDate?, exifDate: NSDate?, exifLatitude: String?, exifLongitude: String?, fileName: String?, fileNamePrint: String?) {
        
        guard self.getAccountActive() != nil else {
            return
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                guard let result = realm.objects(tableLocalFile.self).filter("fileID = %@", fileID).first else {
                    realm.cancelWrite()
                    return
                }
                
                if let date = date {
                    result.date = date
                }
                if let exifDate = exifDate {
                    result.exifDate = exifDate
                }
                if let exifLatitude = exifLatitude {
                    result.exifLatitude = exifLatitude
                }
                if let exifLongitude = exifLongitude {
                    result.exifLongitude = exifLongitude
                }
                if let fileName = fileName {
                    result.fileName = fileName
                }
                if let fileNamePrint = fileNamePrint {
                    result.fileNamePrint = fileNamePrint
                }
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
    }
    
    func getTableLocalFile(predicate: NSPredicate) -> tableLocalFile? {
        
        guard self.getAccountActive() != nil else {
            return nil
        }
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableLocalFile.self).filter(predicate).first else {
            return nil
        }

        return tableLocalFile.init(value: result)
    }

    //MARK: -
    //MARK: Table Metadata
    
    func addMetadata(_ metadata: tableMetadata) -> tableMetadata? {
        
        guard self.getAccountActive() != nil else {
            return nil
        }
        
        if metadata.isInvalidated {
            return nil
        }
        
        let directoryID = metadata.directoryID
        let realm = try! Realm()
        
        do {
            try realm.write {
                realm.add(metadata, update: true)
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
        
        self.setDateReadDirectory(directoryID: directoryID)
        
        return tableMetadata.init(value: metadata)
    }
    
    func addMetadatas(_ metadatas: [tableMetadata], serverUrl: String?) -> [tableMetadata]? {
        
        guard self.getAccountActive() != nil else {
            return nil
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                for metadata in metadatas {
                    realm.add(metadata, update: true)
                }
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
        
        if let serverUrl = serverUrl {
            if let directoryID = self.getDirectoryID(serverUrl) {
                self.setDateReadDirectory(directoryID: directoryID)
            }
        }
        
        return Array(metadatas.map { tableMetadata.init(value:$0) })
    }

    func deleteMetadata(predicate: NSPredicate, clearDateReadDirectoryID: String?) {
        
        guard self.getAccountActive() != nil else {
            return
        }
        
        var directoriesID = [String]()
        
        let realm = try! Realm()
        
        realm.beginWrite()

        let results = realm.objects(tableMetadata.self).filter(predicate)
        
        if let clearDateReadDirectoryID = clearDateReadDirectoryID {
            directoriesID.append(clearDateReadDirectoryID)
        } else {
            for result in results {
                directoriesID.append(result.directoryID)
            }
        }
        
        realm.delete(results)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
        
        for directoryID in directoriesID {
            self.setDateReadDirectory(directoryID: directoryID)
        }
    }
    
    func moveMetadata(fileName: String, directoryID: String, directoryIDTo: String) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {
            
                let results = realm.objects(tableMetadata.self).filter("account = %@ AND fileName = %@ AND directoryID = %@", tableAccount.account, fileName, directoryID)
        
                for result in results {
                    result.directoryID = directoryIDTo
                }
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
        
        self.setDateReadDirectory(directoryID: directoryID)
        self.setDateReadDirectory(directoryID: directoryIDTo)
    }
    
    func updateMetadata(_ metadata: tableMetadata) -> tableMetadata? {
        
        let directoryID = metadata.directoryID
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                realm.add(metadata, update: true)
            }
        } catch let error {
            print("Could not write to database: ", error)
            return nil
        }
        
        self.setDateReadDirectory(directoryID: directoryID)
        
        return tableMetadata.init(value: metadata)
    }
    
    func setMetadataSession(_ session: String?, sessionError: String?, sessionSelector: String?, sessionSelectorPost: String?, sessionTaskIdentifier: Int, sessionTaskIdentifierPlist: Int, predicate: NSPredicate) {
        
        guard self.getAccountActive() != nil else {
            return
        }
        
        let realm = try! Realm()
        
        realm.beginWrite()

        guard let result = realm.objects(tableMetadata.self).filter(predicate).first else {
            realm.cancelWrite()
            return
        }
        
        if let session = session {
            result.session = session
        }
        if let sessionError = sessionError {
            result.sessionError = sessionError
        }
        if let sessionSelector = sessionSelector {
            result.sessionSelector = sessionSelector
        }
        if let sessionSelectorPost = sessionSelectorPost {
            result.sessionSelectorPost = sessionSelectorPost
        }
        if sessionTaskIdentifier != Int(k_taskIdentifierNULL) {
            result.sessionTaskIdentifier = sessionTaskIdentifier
        }
        if sessionTaskIdentifierPlist != Int(k_taskIdentifierNULL) {
            result.sessionTaskIdentifierPlist = sessionTaskIdentifierPlist
        }
        
        let directoryID : String? = result.directoryID
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
        
        if let directoryID = directoryID {
            // Update Date Read Directory
            self.setDateReadDirectory(directoryID: directoryID)
        }
    }
    
    func setMetadataFavorite(fileID: String, favorite: Bool) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        realm.beginWrite()

        guard let result = realm.objects(tableMetadata.self).filter("account = %@ AND fileID = %@", tableAccount.account, fileID).first else {
            realm.cancelWrite()
            return
        }
        
        result.favorite = favorite
        
        let directoryID : String? = result.directoryID
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
        
        if let directoryID = directoryID {
            // Update Date Read Directory
            self.setDateReadDirectory(directoryID: directoryID)
        }
    }
    
    func setMetadataStatus(fileID: String, status: Double) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
                
        let realm = try! Realm()
        
        realm.beginWrite()
        
        guard let result = realm.objects(tableMetadata.self).filter("account = %@ AND fileID = %@", tableAccount.account, fileID).first else {
            realm.cancelWrite()
            return
        }
        
        result.status = status
        
        let directoryID : String? = result.directoryID
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
        
        if let directoryID = directoryID {
            // Update Date Read Directory
            self.setDateReadDirectory(directoryID: directoryID)
        }
    }

    func getMetadata(predicate: NSPredicate) -> tableMetadata? {
        
        guard self.getAccountActive() != nil else {
            return nil
        }
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableMetadata.self).filter(predicate).first else {
            return nil
        }
        
        return tableMetadata.init(value: result)
    }
    
    func getMetadatas(predicate: NSPredicate, sorted: String?, ascending: Bool) -> [tableMetadata]? {
        
        guard self.getAccountActive() != nil else {
            return nil
        }
        
        let realm = try! Realm()
        let results : Results<tableMetadata>
        
        if let sorted = sorted {
            
            if (tableMetadata().objectSchema.properties.contains { $0.name == sorted }) {
                results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
            } else {
                results = realm.objects(tableMetadata.self).filter(predicate)
            }
            
        } else {
            
            results = realm.objects(tableMetadata.self).filter(predicate)
        }
        
        if (results.count > 0) {
            return Array(results.map { tableMetadata.init(value:$0) })
        } else {
            return nil
        }
    }
    
    func getMetadataAtIndex(predicate: NSPredicate, sorted: String, ascending: Bool, index: Int) -> tableMetadata? {
        
        guard self.getAccountActive() != nil else {
            return nil
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
        
        if (results.count > 0  && results.count > index) {
            return tableMetadata.init(value: results[index])
        } else {
            return nil
        }
    }
    
    func getMetadataFromFileName(_ fileName: String, directoryID: String) -> tableMetadata? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableMetadata.self).filter("account = %@ AND directoryID = %@ AND (fileName = %@ OR fileNameData = %@)", tableAccount.account, directoryID, fileName, fileName).first else {
            return nil
        }
        
        return tableMetadata.init(value: result)
    }
    
    func getTableMetadataDownload() -> [tableMetadata]? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }
        
        let predicate = NSPredicate(format: "account = %@ AND (session = %@ OR session = %@) AND (sessionTaskIdentifier != %i OR sessionTaskIdentifierPlist != %i)", tableAccount.account, k_download_session, k_download_session_foreground, Int(k_taskIdentifierDone), Int(k_taskIdentifierDone))
        
        return self.getMetadatas(predicate: predicate, sorted: nil, ascending: false)
    }
    
    func getTableMetadataDownloadWWan() -> [tableMetadata]? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }

        let predicate = NSPredicate(format: "account = %@ AND session = %@ AND (sessionTaskIdentifier != %i OR sessionTaskIdentifierPlist != %i)", tableAccount.account, k_download_session_wwan, Int(k_taskIdentifierDone), Int(k_taskIdentifierDone))
        
        return self.getMetadatas(predicate: predicate, sorted: nil, ascending: false)
    }
    
    func getTableMetadataUpload() -> [tableMetadata]? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }

        let predicate = NSPredicate(format: "account = %@ AND (session = %@ OR session = %@) AND (sessionTaskIdentifier != %i OR sessionTaskIdentifierPlist != %i)", tableAccount.account, k_upload_session, k_upload_session_foreground, Int(k_taskIdentifierDone), Int(k_taskIdentifierDone))
        
        return self.getMetadatas(predicate: predicate, sorted: nil, ascending: false)
    }
    
    func getTableMetadataUploadWWan() -> [tableMetadata]? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }
        
        let predicate = NSPredicate(format: "account = %@ AND session = %@ AND (sessionTaskIdentifier != %i OR sessionTaskIdentifierPlist != %i)", tableAccount.account, k_upload_session_wwan, Int(k_taskIdentifierDone), Int(k_taskIdentifierDone))
        
        return self.getMetadatas(predicate: predicate, sorted: nil, ascending: false)
    }
    
    func getTableMetadatasPhotos(serverUrl: String) -> [tableMetadata]? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }
        
        let realm = try! Realm()
        
        let directories = realm.objects(tableDirectory.self).filter(NSPredicate(format: "account = %@ AND serverUrl BEGINSWITH %@", tableAccount.account, serverUrl)).sorted(byKeyPath: "serverUrl", ascending: true)
        let directoriesID = Array(directories.map { $0.directoryID })
        
        let metadatas = realm.objects(tableMetadata.self).filter(NSPredicate(format: "account = %@ AND session = '' AND type = 'file' AND (typeFile = %@ OR typeFile = %@) AND directoryID IN %@", tableAccount.account, k_metadataTypeFile_image, k_metadataTypeFile_video, directoriesID)).sorted(byKeyPath: "date", ascending: false)
            
        return Array(metadatas.map { tableMetadata.init(value:$0) })
    }
    
    //MARK: -
    //MARK: Table Photo Library
    
    func addPhotoLibrary(_ assets: [PHAsset]) -> Bool {
        
        guard let tableAccount = self.getAccountActive() else {
            return false
        }

        let realm = try! Realm()
        
        if realm.isInWriteTransaction {
            
            print("[LOG] Could not write to database, addPhotoLibrary is already in write transaction")
            return false
            
        } else {
        
            do {
                try realm.write {
                
                    var creationDateString = ""

                    for asset in assets {
                    
                        let addObject = tablePhotoLibrary()
                    
                        addObject.account = tableAccount.account
                        addObject.assetLocalIdentifier = asset.localIdentifier
                        addObject.mediaType = asset.mediaType.rawValue
                    
                        if let creationDate = asset.creationDate {
                            addObject.creationDate = creationDate as NSDate
                            creationDateString = String(describing: creationDate)
                        } else {
                            creationDateString = ""
                        }
                        
                        if let modificationDate = asset.modificationDate {
                            addObject.modificationDate = modificationDate as NSDate
                        }
                        
                        addObject.idAsset = "\(tableAccount.account)\(asset.localIdentifier)\(creationDateString)"

                        realm.add(addObject, update: true)
                    }
                }
            } catch let error {
                print("Could not write to database: ", error)
                return false
            }
        }
        
        return true
    }
    
    func getPhotoLibraryIdAsset(image: Bool, video: Bool) -> [String]? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }
        
        let realm = try! Realm()
        
        var predicate = NSPredicate()
        
        if (image && video) {
         
            predicate = NSPredicate(format: "account = %@ AND (mediaType = %i || mediaType = %i)", tableAccount.account, PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
            
        } else if (image) {
            
            predicate = NSPredicate(format: "account = %@ AND mediaType = %i", tableAccount.account, PHAssetMediaType.image.rawValue)

        } else if (video) {
            
            predicate = NSPredicate(format: "account = %@ AND mediaType = %i", tableAccount.account, PHAssetMediaType.video.rawValue)
        }
        
        let results = realm.objects(tablePhotoLibrary.self).filter(predicate)
        
        let idsAsset = results.map { $0.idAsset }
        
        return Array(idsAsset)
    }
    
    func getPhotoLibrary(predicate: NSPredicate) -> [tablePhotoLibrary] {
        
        let realm = try! Realm()
        
        let results = realm.objects(tablePhotoLibrary.self).filter(predicate)
        
        return Array(results.map { tablePhotoLibrary.init(value:$0) })
    }
    
    //MARK: -
    //MARK: Table Queue Download
    
    func addQueueDownload(fileID: String, downloadData: Bool, downloadPlist: Bool, selector: String, selectorPost: String?, serverUrl: String, session: String) -> Bool {
        
        guard let tableAccount = self.getAccountActive() else {
            return false
        }
        
        let realm = try! Realm()
        
        if realm.isInWriteTransaction {
            
            print("[LOG] Could not write to database, addQueueDownload is already in write transaction")
            return false
            
        } else {
            
            do {
                try realm.write {
                    
                    // Add new
                    let addObject = tableQueueDownload()
                        
                    addObject.account = tableAccount.account
                    addObject.fileID = fileID
                    addObject.downloadData = downloadData
                    addObject.downloadPlist = downloadPlist
                    addObject.selector = selector
                        
                    if let selectorPost = selectorPost {
                        addObject.selectorPost = selectorPost
                    }
                    
                    addObject.serverUrl = serverUrl
                    addObject.session = session
                    
                    realm.add(addObject, update: true)
                }
            } catch let error {
                print("[LOG] Could not write to database: ", error)
                return false
            }
        }
        
        return true
    }
    
    func addQueueDownload(metadatasNet: [CCMetadataNet]) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                for metadataNet in metadatasNet {
                        
                    // Add new
                    let addObject = tableQueueDownload()
                    
                    addObject.account = tableAccount.account
                    addObject.fileID = metadataNet.fileID
                    addObject.downloadData = metadataNet.downloadData
                    addObject.downloadPlist = metadataNet.downloadPlist
                    addObject.selector = metadataNet.selector
                    
                    if let selectorPost = metadataNet.selectorPost {
                        addObject.selectorPost = selectorPost
                    }
                    
                    addObject.serverUrl = metadataNet.serverUrl
                    addObject.session = metadataNet.session
                    
                    realm.add(addObject, update: true)
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }

    func getQueueDownload() -> CCMetadataNet? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }
        
        let realm = try! Realm()
        
        realm.beginWrite()
        
        guard let result = realm.objects(tableQueueDownload.self).filter("account = %@", tableAccount.account).first else {
            realm.cancelWrite()
            return nil
        }
        
        let metadataNet = CCMetadataNet()
        
        metadataNet.fileID = result.fileID
        metadataNet.downloadData = result.downloadData
        metadataNet.downloadPlist = result.downloadPlist
        metadataNet.selector = result.selector
        metadataNet.selectorPost = result.selectorPost
        metadataNet.serverUrl = result.serverUrl
        metadataNet.session = result.session
        metadataNet.taskStatus = Int(k_taskStatusResume)
        
        // delete record
        realm.delete(result)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }
        
        return metadataNet
    }
    
    func countQueueDownload(session: String?) -> Int {
        
        guard let tableAccount = self.getAccountActive() else {
            return 0
        }
        
        let realm = try! Realm()
        let results : Results<tableQueueDownload>
        
        if let session = session {
            results = realm.objects(tableQueueDownload.self).filter("account = %@ AND session = %@", tableAccount.account, session)
        } else {
            results = realm.objects(tableQueueDownload.self).filter("account = %@", tableAccount.account)
        }
        
        return results.count
    }

    
    //MARK: -
    //MARK: Table Queue Upload
    
    func addQueueUpload(metadataNet: CCMetadataNet) -> Bool {
        
        guard let tableAccount = self.getAccountActive() else {
            return false
        }
        
        let realm = try! Realm()
        
        if realm.isInWriteTransaction {
            
            print("[LOG] Could not write to database, addQueueUpload is already in write transaction")
            return false
            
        } else {
            
            do {
                try realm.write {
                    
                    if realm.objects(tableQueueUpload.self).filter("account = %@ AND assetLocalIdentifier = %@ AND selector = %@", tableAccount.account, metadataNet.assetLocalIdentifier, metadataNet.selector).first == nil {
                        
                        // Add new
                        let addObject = tableQueueUpload()
                        
                        addObject.account = tableAccount.account
                        addObject.assetLocalIdentifier = metadataNet.assetLocalIdentifier
                        addObject.fileName = metadataNet.fileName
                        addObject.selector = metadataNet.selector
                        
                        if let selectorPost = metadataNet.selectorPost {
                            addObject.selectorPost = selectorPost
                        }
                        
                        addObject.serverUrl = metadataNet.serverUrl
                        addObject.session = metadataNet.session
                        addObject.priority = metadataNet.priority
                        
                        realm.add(addObject)
                    }
                }
            } catch let error {
                print("[LOG] Could not write to database: ", error)
                return false
            }
        }
        
        return true
    }
    
    func addQueueUpload(metadatasNet: [CCMetadataNet]) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                for metadataNet in metadatasNet {
                    
                    if realm.objects(tableQueueUpload.self).filter("account = %@ AND assetLocalIdentifier = %@ AND selector = %@", tableAccount.account, metadataNet.assetLocalIdentifier, metadataNet.selector).first == nil {
                        
                        // Add new
                        let addObject = tableQueueUpload()
                        
                        addObject.account = tableAccount.account
                        addObject.assetLocalIdentifier = metadataNet.assetLocalIdentifier
                        addObject.fileName = metadataNet.fileName
                        addObject.selector = metadataNet.selector
                        
                        if let selectorPost = metadataNet.selectorPost {
                            addObject.selectorPost = selectorPost
                        }
                        
                        addObject.serverUrl = metadataNet.serverUrl
                        addObject.session = metadataNet.session
                        addObject.priority = metadataNet.priority
                        
                        realm.add(addObject)
                    }
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    func getQueueUpload(selector: String) -> CCMetadataNet? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }
        
        let realm = try! Realm()
        
        realm.beginWrite()
        
        guard let result = realm.objects(tableQueueUpload.self).filter("account = %@ AND selector = %@ AND lock == false", tableAccount.account, selector).sorted(byKeyPath: "priority", ascending: false).first else {
            realm.cancelWrite()
            return nil
        }
        
        let metadataNet = CCMetadataNet()
        
        metadataNet.assetLocalIdentifier = result.assetLocalIdentifier
        metadataNet.fileName = result.fileName
        metadataNet.priority = result.priority
        metadataNet.selector = result.selector
        metadataNet.selectorPost = result.selectorPost
        metadataNet.serverUrl = result.serverUrl
        metadataNet.session = result.session
        metadataNet.taskStatus = Int(k_taskStatusResume)
        
        // Lock
        result.lock = true
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }
        
        return metadataNet
    }
    
    func getLockQueueUpload() -> [tableQueueUpload]? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableQueueUpload.self).filter("account = %@ AND lock = true", tableAccount.account)
        
        return Array(results.map { tableQueueUpload.init(value:$0) })
    }
    
    func unlockQueueUpload(assetLocalIdentifier: String) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        realm.beginWrite()
        
        guard let result = realm.objects(tableQueueUpload.self).filter("account = %@ AND assetLocalIdentifier = %@", tableAccount.account, assetLocalIdentifier).first else {
            realm.cancelWrite()
            return
        }
        
        // UnLock
        result.lock = false
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    func getPriorityQueueUpload(assetLocalIdentifier: String) -> NSInteger {
        
        guard let tableAccount = self.getAccountActive() else {
            return 0
        }
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableQueueUpload.self).filter("account = %@ AND assetLocalIdentifier = %@", tableAccount.account, assetLocalIdentifier).first else {
            return 0
        }
        
        return result.priority
    }

    func setPriorityQueueUpload(assetLocalIdentifier: String, priority: NSInteger) -> Bool {
        
        guard let tableAccount = self.getAccountActive() else {
            return false
        }
        
        let realm = try! Realm()
        
        realm.beginWrite()
        
        guard let result = realm.objects(tableQueueUpload.self).filter("account = %@ AND assetLocalIdentifier = %@", tableAccount.account, assetLocalIdentifier).first else {
            realm.cancelWrite()
            return false
        }
        
        // priority
        if (result.priority <= Int(k_priorityAutoUploadError)) {
            result.priority = result.priority - 1            
        } else {
            result.priority = priority
        }
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return false
        }
        
        return true
    }
    
    func deleteQueueUpload(assetLocalIdentifier: String, selector: String) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                if let result = realm.objects(tableQueueUpload.self).filter("account = %@ AND assetLocalIdentifier = %@ AND selector = %@", tableAccount.account, assetLocalIdentifier, selector).first {
                    realm.delete(result)
                }
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
    }
    
    func countQueueUpload(session: String?) -> Int {
        
        guard let tableAccount = self.getAccountActive() else {
            return 0
        }
        
        let realm = try! Realm()
        let results : Results<tableQueueUpload>
        
        if let session = session {
            results = realm.objects(tableQueueUpload.self).filter("account = %@ AND session = %@", tableAccount.account, session)
        } else {
            results = realm.objects(tableQueueUpload.self).filter("account = %@", tableAccount.account)
        }
        
        return results.count
    }

    //MARK: -
    //MARK: Table Share
    
    func addShareLink(_ share: String, fileName: String, serverUrl: String) -> [String:String]? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }
        
        let realm = try! Realm()

        realm.beginWrite()

        // Verify if exists
        let result = realm.objects(tableShare.self).filter("account = %@ AND fileName = %@ AND serverUrl = %@", tableAccount.account, fileName, serverUrl).first
        
        if result != nil {
            
            result?.shareLink = share
            
        } else {
        
            // Add new
            let addObject = tableShare()
            
            addObject.account = tableAccount.account
            addObject.fileName = fileName
            addObject.serverUrl = serverUrl
            addObject.shareLink = share
            
            realm.add(addObject)
        }
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }

        return ["\(serverUrl)\(fileName)" : share]
    }

    func addShareUserAndGroup(_ share: String, fileName: String, serverUrl: String) -> [String:String]? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }
        
        let realm = try! Realm()

        realm.beginWrite()

        // Verify if exists
        let result = realm.objects(tableShare.self).filter("account = %@ AND fileName = %@ AND serverUrl = %@", tableAccount.account, fileName, serverUrl).first
        
        if result != nil {
            
            result?.shareUserAndGroup = share
            
        } else {
            
            // Add new
            let addObject = tableShare()
                
            addObject.account = tableAccount.account
            addObject.fileName = fileName
            addObject.serverUrl = serverUrl
            addObject.shareUserAndGroup = share
                
            realm.add(addObject)
        }
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
        
        return ["\(serverUrl)\(fileName)" : share]
    }
    
    func unShare(_ share: String, fileName: String, serverUrl: String, sharesLink: [String:String], sharesUserAndGroup: [String:String]) -> [Any]? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }
        
        var sharesLink = sharesLink
        var sharesUserAndGroup = sharesUserAndGroup
        
        let realm = try! Realm()
        
        realm.beginWrite()

        let results = realm.objects(tableShare.self).filter("account = %@ AND (shareLink CONTAINS %@ OR shareUserAndGroup CONTAINS %@)", tableAccount.account, share, share)
        
        if (results.count > 0) {
            
            let result = results[0]
            
            if (result.shareLink.contains(share)) {
                result.shareLink = ""
            }
                
            if (result.shareUserAndGroup.contains(share)) {
                    
                var shares : [String] = result.shareUserAndGroup.components(separatedBy: ",")
                if let index = shares.index(of:share) {
                    shares.remove(at: index)
                }
                result.shareUserAndGroup = shares.joined(separator: ",")
            }
            
            if (result.shareLink.characters.count > 0) {
                sharesLink.updateValue(result.shareLink, forKey:"\(serverUrl)\(fileName)")
            } else {
                sharesLink.removeValue(forKey: "\(serverUrl)\(fileName)")
            }
            
            if (result.shareUserAndGroup.characters.count > 0) {
                sharesUserAndGroup.updateValue(result.shareUserAndGroup, forKey:"\(serverUrl)\(fileName)")
            } else {
                sharesUserAndGroup.removeValue(forKey: "\(serverUrl)\(fileName)")
            }
            
            if (result.shareLink.characters.count == 0 && result.shareUserAndGroup.characters.count == 0) {
                realm.delete(result)
            }
        }
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }

        return [sharesLink, sharesUserAndGroup]
    }
    
    func removeShareActiveAccount() {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {
            
                let results = realm.objects(tableShare.self).filter("account = %@", tableAccount.account)

                realm.delete(results)
            }
        } catch let error {
            print("Could not write to database: ", error)
        }
    }
    
    func updateShare(_ items: [String:OCSharedDto], activeUrl: String) -> [Any]? {
        
        guard self.getAccountActive() != nil else {
            return nil
        }
        
        var sharesLink = [String:String]()
        var sharesUserAndGroup = [String:String]()

        self.removeShareActiveAccount()
     
        var itemsLink = [OCSharedDto]()
        var itemsUsersAndGroups = [OCSharedDto]()
        
        for (_, itemOCSharedDto) in items {
            
            if (itemOCSharedDto.shareType == Int(shareTypeLink.rawValue)) {
                itemsLink.append(itemOCSharedDto)
            }
            
            if (itemOCSharedDto.shareWith.characters.count > 0 && (itemOCSharedDto.shareType == Int(shareTypeUser.rawValue) || itemOCSharedDto.shareType == Int(shareTypeGroup.rawValue) || itemOCSharedDto.shareType == Int(shareTypeRemote.rawValue)  )) {
                itemsUsersAndGroups.append(itemOCSharedDto)
            }
        }
        
        // Manage sharesLink

        for itemOCSharedDto in itemsLink {
            
            let fullPath = CCUtility.getHomeServerUrlActiveUrl(activeUrl) + "\(itemOCSharedDto.path!)"
            let fileName = NSString(string: fullPath).lastPathComponent
            var serverUrl = NSString(string: fullPath).substring(to: (fullPath.characters.count - fileName.characters.count - 1))
            
            if serverUrl.hasSuffix("/") {
                serverUrl = NSString(string: serverUrl).substring(to: (serverUrl.characters.count - 1))
            }
            
            if itemOCSharedDto.idRemoteShared > 0 {
                let sharesLinkReturn = self.addShareLink("\(itemOCSharedDto.idRemoteShared)", fileName: fileName, serverUrl: serverUrl)
                if sharesLinkReturn != nil {
                    for (key,value) in sharesLinkReturn! {
                        sharesLink.updateValue(value, forKey:key)
                    }
                }
            }
        }
        
        // Manage sharesUserAndGroup
        
        var paths = [String:[String]]()
        
        for itemOCSharedDto in itemsUsersAndGroups {
            
            if paths[itemOCSharedDto.path] != nil {
                
                var share : [String] = paths[itemOCSharedDto.path]!
                share.append("\(itemOCSharedDto.idRemoteShared)")
                paths[itemOCSharedDto.path] = share
                
            } else {
                
                paths[itemOCSharedDto.path] = ["\(itemOCSharedDto.idRemoteShared)"]
            }
        }
        
        for (path, idsRemoteSharedArray) in paths {
            
            let idsRemoteShared = idsRemoteSharedArray.joined(separator: ",")
            
            print("[LOG] share \(String(describing: idsRemoteShared))")
            
            let fullPath = CCUtility.getHomeServerUrlActiveUrl(activeUrl) + "\(path)"
            let fileName = NSString(string: fullPath).lastPathComponent
            var serverUrl = NSString(string: fullPath).substring(to: (fullPath.characters.count - fileName.characters.count - 1))
            
            if serverUrl.hasSuffix("/") {
                serverUrl = NSString(string: serverUrl).substring(to: (serverUrl.characters.count - 1))
            }
            
            let sharesUserAndGroupReturn = self.addShareUserAndGroup(idsRemoteShared, fileName: fileName, serverUrl: serverUrl)
            if sharesUserAndGroupReturn != nil {
                for (key,value) in sharesUserAndGroupReturn! {
                    sharesUserAndGroup.updateValue(value, forKey:key)
                }
            }
        }
        
        return [sharesLink, sharesUserAndGroup]
    }
    
    func getShares() -> [Any]? {

        guard let tableAccount = self.getAccountActive() else {
            return nil
        }

        var sharesLink = [String:String]()
        var sharesUserAndGroup = [String:String]()
        
        let realm = try! Realm()

        let results = realm.objects(tableShare.self).filter("account = %@", tableAccount.account)
        
        for resultShare in results {
            
            if (resultShare.shareLink.characters.count > 0) {
                sharesLink = [resultShare.shareLink: "\(resultShare.serverUrl)\(resultShare.fileName)"]
            }
            
            if (resultShare.shareUserAndGroup.characters.count > 0) {
                sharesUserAndGroup = [resultShare.shareUserAndGroup: "\(resultShare.serverUrl)\(resultShare.fileName)"]
            }
        }
        
        return [sharesLink, sharesUserAndGroup]
    }
    
    func getTableShares() -> [tableShare]? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableShare.self).filter("account = %@", tableAccount.account).sorted(byKeyPath: "fileName", ascending: true)
        
        return Array(results)
    }

    
    //MARK: -
    //MARK: Migrate func
    
    func addTableAccountFromCoredata(_ table: TableAccount) {
        
        let realm = try! Realm()
        
        realm.beginWrite()

        let results = realm.objects(tableAccount.self).filter("account = %@", table.account!)
        if (results.count == 0) {
            
            let addAccount = tableAccount()
                
            addAccount.account = table.account!
            if table.active == 1 {
                addAccount.active = true
            }
            if table.cameraUpload == 1 {
                addAccount.autoUpload = true
            }
            if table.cameraUploadBackground == 1 {
                addAccount.autoUploadBackground = true
            }
            if table.cameraUploadCreateSubfolder == 1 {
                addAccount.autoUploadCreateSubfolder = true
            }
            if table.cameraUploadFolderName != nil {
                addAccount.autoUploadFileName = table.cameraUploadFolderName!
            }
            if table.cameraUploadFolderPath != nil {
                addAccount.autoUploadDirectory = table.cameraUploadFolderPath!
            }
            if table.cameraUploadFull == 1 {
                addAccount.autoUploadFull = true
            }
            if table.cameraUploadPhoto == 1 {
                addAccount.autoUploadImage = true
            }
            if table.cameraUploadVideo == 1 {
                addAccount.autoUploadVideo = true
            }
            if table.cameraUploadWWAnPhoto == 1 {
                addAccount.autoUploadWWAnPhoto = true
            }
            if table.cameraUploadWWAnVideo == 1 {
                addAccount.autoUploadWWAnVideo = true
            }
            addAccount.password = table.password!
            addAccount.url = table.url!
            addAccount.user = table.user!
                
            realm.add(addAccount)
        }
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }

    func addTableDirectoryFromCoredata(_ table: TableDirectory) {
        
        let realm = try! Realm()
        
        realm.beginWrite()

        let results = realm.objects(tableDirectory.self).filter("directoryID = %@", table.directoryID!)
        if (results.count == 0) {
            
            let addObject = tableDirectory()
                
            addObject.account = table.account!
            addObject.directoryID = table.directoryID!
            addObject.etag = table.rev!
            if table.favorite == 1 {
                addObject.favorite = true
            }
            addObject.fileID = table.fileID!
            if table.lock == 1 {
                addObject.lock = true
            }
            addObject.permissions = table.permissions!
            addObject.serverUrl = table.serverUrl!
            
            realm.add(addObject)
        }
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }

    func addTableLocalFileFromCoredata(_ table: TableLocalFile) {
        
        let realm = try! Realm()
        
        realm.beginWrite()

        let results = realm.objects(tableLocalFile.self).filter("fileID = %@", table.fileID!)
        if (results.count == 0) {
            
            let addObject = tableLocalFile()
            
            addObject.account = table.account!
                
            if table.date != nil {
                addObject.date = table.date! as NSDate
            } else {
                addObject.date = NSDate()
            }
            
            if (table.rev != nil) {
                addObject.etag = table.rev!
            } else {
                realm.cancelWrite()
                return
            }
            
            if table.exifDate != nil {
                addObject.exifDate = table.exifDate! as NSDate
            }
            addObject.exifLatitude = table.exifLatitude!
            addObject.exifLongitude = table.exifLongitude!
            if table.favorite == 1 {
                addObject.favorite = true
            }
            addObject.fileID = table.fileID!
            addObject.fileName = table.fileName!
            addObject.fileNamePrint = table.fileNamePrint!
            addObject.size = table.size as! Double

            realm.add(addObject)
        }
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    //MARK: -
}
