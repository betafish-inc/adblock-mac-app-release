//
//  AdBlock_Tests.swift
//  AdBlock-Tests
//
//  Created by Brent Montrose on 7/19/18.
//  Copyright © 2018 BetaFish. All rights reserved.
//

import XCTest
import SwiftyBeaver

class AdBlock_Tests: XCTestCase {

    var whitelistManagerStatusObserverRefForSetup: Disposable? = nil
    var whitelistManagerStatusObserverRefForTearDown: Disposable? = nil
    let validURLsForSetUp: [String] = ["https://data.example.com/test/index.html", "https://getadblock2.com", "https://google3.com", "https://mail.google4.com/one/two.html", "http://mail.google4.com/one/two.html", "mail.google.com/one/two.html", "mail.google.com", "example.com/test/"]
    var currentURLIndex = 0
    var startUpExpectation: XCTestExpectation? = nil
    var tearDownExpectation: XCTestExpectation? = nil


    func whitelistManagerStatusChangeObserverForSetup(data: (WhitelistManagerStatus, WhitelistManagerStatus)) {
        if (data.0 == .whitelistUpdateCompleted && data.1 == .idle) {
            if (currentURLIndex == validURLsForSetUp.count) {
                whitelistManagerStatusObserverRefForSetup?.dispose()
                currentURLIndex = 0
                startUpExpectation?.fulfill()
            } else if (currentURLIndex < validURLsForSetUp.count) {
                WhitelistManager.shared.add(validURLsForSetUp[currentURLIndex])
                currentURLIndex = currentURLIndex + 1
            }
        }
    }

    func whitelistManagerStatusChangeObserverForTearDown(data: (WhitelistManagerStatus, WhitelistManagerStatus)) {
        if (data.0 == .whitelistUpdateCompleted && data.1 == .idle) {
            if (currentURLIndex == validURLsForSetUp.count) {
                whitelistManagerStatusObserverRefForTearDown?.dispose()
                currentURLIndex = 0
                tearDownExpectation?.fulfill()
            } else if (currentURLIndex < validURLsForSetUp.count) {
                WhitelistManager.shared.remove(validURLsForSetUp[currentURLIndex])
                currentURLIndex = currentURLIndex + 1
            }
        }
    }

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testAddExistsRemove() {
        // initial set up

        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        startUpExpectation = expectation(description: "Loading whitelist entries")
        whitelistManagerStatusObserverRefForSetup = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForSetup)

        WhitelistManager.shared.add(validURLsForSetUp[currentURLIndex])
        currentURLIndex = currentURLIndex + 1
        wait(for: [startUpExpectation!], timeout: 10.0)
        XCTAssert((WhitelistManager.shared.getAllItems()?.count)! >= validURLsForSetUp.count)
        validURLsForSetUp.forEach {
            XCTAssert(WhitelistManager.shared.exists($0) == true)
        }
        XCTAssert(WhitelistManager.shared.exists("https://") == false)
        XCTAssert(WhitelistManager.shared.exists("https://data.example.com/test/index.html") == true)
        WhitelistManager.shared.status.set(newValue: .idle)
        // tear down
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        tearDownExpectation = expectation(description: "removing whitelist entries")
        whitelistManagerStatusObserverRefForTearDown = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForTearDown)
        WhitelistManager.shared.remove(validURLsForSetUp[currentURLIndex])
        currentURLIndex = currentURLIndex + 1
        wait(for: [tearDownExpectation!], timeout: 10.0)
    }

    func testURLValidation() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssert("https://code.example.com/test/test1.html".isValidUrl() == true)
        XCTAssert("https://example.com/test/".isValidUrl() == true)
        XCTAssert("https://google.com".isValidUrl() == true)
        XCTAssert("https://mail.google.com/one/two.html".isValidUrl() == true)
        XCTAssert("http://code.example.com/test/test1.html".isValidUrl() == true)
        XCTAssert("http://example.com/test/".isValidUrl() == true)
        XCTAssert("http://google.com".isValidUrl() == true)
        XCTAssert("http://mail.google.com/one/two.html".isValidUrl() == true)
        XCTAssert("http://mail.google.com/one/two.html#first".isValidUrl() == true)
        XCTAssert("https://example.com/test//installed/?u=z7v5ftfk59075024".isValidUrl() == true)
        XCTAssert("https://example.com/test//installed?u".isValidUrl() == true)
        XCTAssert("https://google".isValidUrl() == true)
        XCTAssert("www.google.com".isValidUrl() == true)
        XCTAssert("google.com".isValidUrl() == true)
        XCTAssert("e.com".isValidUrl() == true)

        XCTAssert("e".isValidUrl() == false)
        XCTAssert("https//code.example.com/test/test1.html".isValidUrl() == false)
        XCTAssert("https:/example.com/test/".isValidUrl() == false)
        XCTAssert("https://".isValidUrl() == false)
        XCTAssert("https:".isValidUrl() == false)
        XCTAssert("://".isValidUrl() == false)
        XCTAssert(":".isValidUrl() == false)
        XCTAssert("".isValidUrl() == false)
        XCTAssert("😕".isValidUrl() == false)
    }

    func testSubDomainParsing() {
        XCTAssert(WhitelistManager.shared.domainAndParents("http://www.google.com/this/ine.html").count == 3)
        XCTAssert(WhitelistManager.shared.domainAndParents("https://www.google.com/this/ine.html").count == 3)
        XCTAssert(WhitelistManager.shared.domainAndParents("https://google.com").count == 2)
        XCTAssert(WhitelistManager.shared.domainAndParents("http://google.com").count == 2)
        XCTAssert(WhitelistManager.shared.domainAndParents("google.com").count == 2)
        XCTAssert(WhitelistManager.shared.domainAndParents("mail.google.com").count == 3)
    }

    func testRemoveDomainWithURL() {
        // initial set up

        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        startUpExpectation = expectation(description: "Loading whitelist entries")
        whitelistManagerStatusObserverRefForSetup = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForSetupOfRemoveDomainWithURL)
        // add a white-list domain rule
        WhitelistManager.shared.add("domainexample.com")
        wait(for: [startUpExpectation!], timeout: 10.0)
        // verify the above rule exists
        XCTAssert((WhitelistManager.shared.getAllItems()?.count)! >= 1)
        XCTAssert(WhitelistManager.shared.exists("domainexample.com") == true)
        XCTAssert(WhitelistManager.shared.exists("https://data.domainexample.com/index.html") == true)
        XCTAssert(WhitelistManager.shared.exists("https://") == false)
        WhitelistManager.shared.status.set(newValue: .idle)
        // tear down
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        tearDownExpectation = expectation(description: "removing whitelist entries")
        whitelistManagerStatusObserverRefForTearDown = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForTearDownOfRemoveDomainWithURL)
        // remove the rule using specific URL from the domain above to simulate the Safari toolbar action
        WhitelistManager.shared.remove("https://data.domainexample.com/index.html")
        wait(for: [tearDownExpectation!], timeout: 10.0)
        XCTAssert(WhitelistManager.shared.exists("domainexample.com") == false)
    }

    func testExactMatchFind() {
        // initial set up

        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        startUpExpectation = expectation(description: "Loading whitelist entries")
        whitelistManagerStatusObserverRefForSetup = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForSetupOfRemoveDomainWithURL)
        // add a white-list domain rule
        WhitelistManager.shared.add("exactmatch.com")
        wait(for: [startUpExpectation!], timeout: 10.0)
        // verify the above rule exists
        XCTAssert((WhitelistManager.shared.getAllItems()?.count)! >= 1)
        XCTAssert(WhitelistManager.shared.exists("exactmatch.com", exactMatch: true) == true)
        XCTAssert(WhitelistManager.shared.exists("exactmatch.com") == true)
        XCTAssert(WhitelistManager.shared.exists("https://data.exactmatch.com/index.html", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("https://data.exactmatch.com/index.html") == true)
        XCTAssert(WhitelistManager.shared.exists("https://") == false)
        XCTAssert(WhitelistManager.shared.exists("https://", exactMatch: true) == false)
        WhitelistManager.shared.status.set(newValue: .idle)
        // intermediate tear down
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        tearDownExpectation = expectation(description: "removing whitelist entries")
        whitelistManagerStatusObserverRefForTearDown = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForTearDownOfRemoveDomainWithURL)
        // remove the rule using a specific URL
        WhitelistManager.shared.remove("exactmatch.com")
        wait(for: [tearDownExpectation!], timeout: 10.0)
        XCTAssert(WhitelistManager.shared.exists("exactmatch.com") == false)
    }

    func testHTTP_ProtocalFind() {
        // initial set up

        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        startUpExpectation = expectation(description: "Loading whitelist entries")
        whitelistManagerStatusObserverRefForSetup = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForSetupOfRemoveDomainWithURL)
        // add a white-list domain rule
        WhitelistManager.shared.add("http://code.example.com/test/")
        wait(for: [startUpExpectation!], timeout: 10.0)
        // verify the above rule exists
        XCTAssert((WhitelistManager.shared.getAllItems()?.count)! >= 1)
        XCTAssert(WhitelistManager.shared.exists("example.com/test/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("example.com/test/") == false)

        XCTAssert(WhitelistManager.shared.isEnabled("http://code.example.com/test/") ==  true)
        XCTAssert(WhitelistManager.shared.isEnabled("https://code.example.com/test/") ==  false)

        XCTAssert(WhitelistManager.shared.exists("http://code.example.com/test/", exactMatch: true) ==  true)
        XCTAssert(WhitelistManager.shared.exists("http://code.example.com/test/") == true)
        XCTAssert(WhitelistManager.shared.exists("https://code.example.com/test/test2/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("https://code.example.com/test/test2/") == false)
        XCTAssert(WhitelistManager.shared.exists("code.example.com/test/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("code.example.com/test/") == true)
        XCTAssert(WhitelistManager.shared.exists("code.example.com/test") == true)

        WhitelistManager.shared.status.set(newValue: .idle)
        // intermediate tear down
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        tearDownExpectation = expectation(description: "removing whitelist entries")
        whitelistManagerStatusObserverRefForTearDown = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForTearDownOfRemoveDomainWithURL)
        // remove the rule using a specific URL
        WhitelistManager.shared.remove("http://code.example.com/test/")
        wait(for: [tearDownExpectation!], timeout: 10.0)
        XCTAssert(WhitelistManager.shared.exists("example.com/test/") == false)
    }

    func testHTTP_ProtocalNoPathFind() {
        // initial set up

        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        startUpExpectation = expectation(description: "Loading whitelist entries")
        whitelistManagerStatusObserverRefForSetup = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForSetupOfRemoveDomainWithURL)
        // add a white-list domain rule
        WhitelistManager.shared.add("http:\\code.example1.com")
        wait(for: [startUpExpectation!], timeout: 10.0)
        // verify the above rule exists
        XCTAssert((WhitelistManager.shared.getAllItems()?.count)! >= 1)
        XCTAssert(WhitelistManager.shared.exists("example1.com/test/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("example1.com/test/") == false)

        XCTAssert(WhitelistManager.shared.isEnabled("https://code.example1.com/test/") ==  false)
        XCTAssert(WhitelistManager.shared.exists("http:\\code.example1.com", exactMatch: true) ==  true)
        XCTAssert(WhitelistManager.shared.exists("https://code.example1.com/test/test2/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("https://code.example1.com/test/test2/") == false)
        XCTAssert(WhitelistManager.shared.exists("code.example1.com/test/", exactMatch: true) == false)

        // The following test all currently fail because the path is not included in the match logic
        // in the exists & isEnabled methods
        XCTAssert(WhitelistManager.shared.exists("http://code.example1.com/test/") == true)
        XCTAssert(WhitelistManager.shared.isEnabled("http://code.example1.com/test/") ==  true)
        XCTAssert(WhitelistManager.shared.exists("code.example1.com/test/") == true)

        WhitelistManager.shared.status.set(newValue: .idle)
        // intermediate tear down
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        tearDownExpectation = expectation(description: "removing whitelist entries")
        whitelistManagerStatusObserverRefForTearDown = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForTearDownOfRemoveDomainWithURL)
        // remove the rule using a specific URL
        WhitelistManager.shared.remove("http://code.example1.com")
        wait(for: [tearDownExpectation!], timeout: 10.0)
        XCTAssert(WhitelistManager.shared.exists("example1.com/test/") == false)
    }


    func testHTTPS_ProtocalFind() {
        // initial set up

        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        startUpExpectation = expectation(description: "Loading whitelist entries")
        whitelistManagerStatusObserverRefForSetup = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForSetupOfRemoveDomainWithURL)
        // add a white-list domain rule
        WhitelistManager.shared.add("https://code.example2.com/test2/")
        wait(for: [startUpExpectation!], timeout: 10.0)

        // verify the above rule exists
        XCTAssert((WhitelistManager.shared.getAllItems()?.count)! >= 1)
        XCTAssert(WhitelistManager.shared.exists("example.com/test/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("example.com/test/") == false)

        XCTAssert(WhitelistManager.shared.isEnabled("http://code.example2.com/test2/") ==  false)
        XCTAssert(WhitelistManager.shared.isEnabled("https://code.example2.com/test2/") ==  true)

        XCTAssert(WhitelistManager.shared.exists("http://code.example.com/test/", exactMatch: true) ==  false)
        XCTAssert(WhitelistManager.shared.exists("http://code.example.com/test/") == false)
        XCTAssert(WhitelistManager.shared.exists("https://code.example.com/test//test2/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("https://code.example.com/test//test2/") == false)
        XCTAssert(WhitelistManager.shared.exists("code.example.com/test/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("code.example.com/test/") == false)

        XCTAssert(WhitelistManager.shared.exists("https://code.example2.com/test2/", exactMatch: true) == true)
        XCTAssert(WhitelistManager.shared.exists("https://code.example2.com/test2/") == true)
        XCTAssert(WhitelistManager.shared.exists("http://code.example2.com/test2/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("http://code.example2.com/test2/") == false)
        XCTAssert(WhitelistManager.shared.exists("code.example2.com/test2/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("code.example2.com/test2/") == true)
        XCTAssert(WhitelistManager.shared.exists("code.example2.com/test2") == true)

        XCTAssert(WhitelistManager.shared.exists("https://code.example5.com/test5/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("https://code.example5.com/test5/") == false)
        XCTAssert(WhitelistManager.shared.exists("http://code.example5.com/test5/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("http://code.example5.com/test5/") == false)
        XCTAssert(WhitelistManager.shared.exists("code.example5.com/test5/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("code.example5.com/test5/") == false)

        WhitelistManager.shared.status.set(newValue: .idle)
        // intermediate tear down
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        tearDownExpectation = expectation(description: "removing whitelist entries")

        whitelistManagerStatusObserverRefForTearDown = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForTearDownOfRemoveDomainWithURL)
        // remove the rule using a specific URL
        WhitelistManager.shared.remove("https://code.example2.com/test2/")
        wait(for: [tearDownExpectation!], timeout: 10.0)

        XCTAssert(WhitelistManager.shared.exists("example.com/test/") == false)
    }

    func testNoProtocalFind() {
        // initial set up

        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        startUpExpectation = expectation(description: "Loading whitelist entries")
        whitelistManagerStatusObserverRefForSetup = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForSetupOfRemoveDomainWithURL)
        // add a white-list domain rule
        WhitelistManager.shared.add("example6.com/test6/")
        wait(for: [startUpExpectation!], timeout: 10.0)
        // verify the above rule exists
        XCTAssert((WhitelistManager.shared.getAllItems()?.count)! >= 1)
        XCTAssert(WhitelistManager.shared.exists("example.com/test/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("example.com/test/") == false)

        XCTAssert(WhitelistManager.shared.exists("example6.com/test6/", exactMatch: true) == true)
        XCTAssert(WhitelistManager.shared.exists("example6.com/test6/") == true)
        XCTAssert(WhitelistManager.shared.exists("example6.com/test6/index.html", exactMatch: true) == false)

        // Currently, the next two test will fail, we may want to add logic
        // in the 'exists' method to check for various path combinations
        XCTAssert(WhitelistManager.shared.exists("example6.com/test6/index.html") == true)
        XCTAssert(WhitelistManager.shared.exists("example6.com/test6/path2") == true)


        WhitelistManager.shared.status.set(newValue: .idle)
        // intermediate tear down
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        tearDownExpectation = expectation(description: "removing whitelist entries")
        whitelistManagerStatusObserverRefForTearDown = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForTearDownOfRemoveDomainWithURL)
        // remove the rule using a specific URL
        WhitelistManager.shared.remove("example6.com/test6/")
        wait(for: [tearDownExpectation!], timeout: 10.0)
        XCTAssert(WhitelistManager.shared.exists("example6.com/test6/") == false)
    }

    func testPathFind() {
        // initial set up

        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        startUpExpectation = expectation(description: "Loading whitelist entries")
        whitelistManagerStatusObserverRefForSetup = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForSetupOfRemoveDomainWithURL)
        // add a white-list domain rule
        WhitelistManager.shared.add("example4.com/test4/")
        wait(for: [startUpExpectation!], timeout: 10.0)
        // verify the above rule exists
        XCTAssert((WhitelistManager.shared.getAllItems()?.count)! >= 1)
        XCTAssert(WhitelistManager.shared.exists("example.com/test/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("example.com/test/") == false)

        XCTAssert(WhitelistManager.shared.isEnabled("http://code.example4.com/test4/") ==  true)
        XCTAssert(WhitelistManager.shared.isEnabled("example4.com/test4/") ==  true)
        XCTAssert(WhitelistManager.shared.isEnabled("https://code.example4.com/test4/") ==  true)

        XCTAssert(WhitelistManager.shared.exists("http://code.example.com/test/", exactMatch: true) ==  false)
        XCTAssert(WhitelistManager.shared.exists("http://code.example.com/test/") == false)
        XCTAssert(WhitelistManager.shared.exists("https://code.example.com/test//test2/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("https://code.example.com/test//test2/") == false)
        XCTAssert(WhitelistManager.shared.exists("code.example.com/test/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("code.example.com/test/") == false)

        XCTAssert(WhitelistManager.shared.exists("https://code.example2.com/test2/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("https://code.example2.com/test2/") == false)
        XCTAssert(WhitelistManager.shared.exists("http://code.example2.com/test2/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("http://code.example2.com/test2/") == false)
        XCTAssert(WhitelistManager.shared.exists("code.example2.com/test2/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("code.example2.com/test2/") == false)

        XCTAssert(WhitelistManager.shared.exists("https://code.example4.com/test4/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("https://code.example4.com/test4/") == true)
        XCTAssert(WhitelistManager.shared.exists("http://code.example4.com/test4/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("http://code.example4.com/test4/") == true)
        XCTAssert(WhitelistManager.shared.exists("code.example4.com/test4/", exactMatch: true) == false)
        XCTAssert(WhitelistManager.shared.exists("code.example4.com/test4/") == true)
        XCTAssert(WhitelistManager.shared.exists("code.example4.com/test4") == true)

        WhitelistManager.shared.status.set(newValue: .idle)
        // intermediate tear down
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        tearDownExpectation = expectation(description: "removing whitelist entries")
        whitelistManagerStatusObserverRefForTearDown = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForTearDownOfRemoveDomainWithURL)
        // remove the rule using a specific URL
        WhitelistManager.shared.remove("code.example4.com/test4/")
        wait(for: [tearDownExpectation!], timeout: 10.0)
        XCTAssert(WhitelistManager.shared.exists("example.com/test/") == false)
    }


    func testDomainRemove() {
        // initial set up

        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        startUpExpectation = expectation(description: "Loading whitelist entries")
        whitelistManagerStatusObserverRefForSetup = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForSetupOfRemoveDomainWithURL)
        // add a white-list domain rule
        WhitelistManager.shared.add("domain.remove.com")
        wait(for: [startUpExpectation!], timeout: 10.0)
        // verify the above rule exists
        XCTAssert((WhitelistManager.shared.getAllItems()?.count)! >= 1)
        XCTAssert(WhitelistManager.shared.exists("domain.remove.com") == true)
        XCTAssert(WhitelistManager.shared.exists("https://data.domain.remove.com/index.html") == true)
        XCTAssert(WhitelistManager.shared.exists("https://") == false)
        XCTAssert(WhitelistManager.shared.exists("https://") == false)
        WhitelistManager.shared.status.set(newValue: .idle)
        // intermediate tear down
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        tearDownExpectation = expectation(description: "removing whitelist entries")
        whitelistManagerStatusObserverRefForTearDown = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForTearDownOfRemoveDomainWithURL)
        // try to remove the rule using a specific URL - the remove should fail
        WhitelistManager.shared.remove("https://www.example.remove.com/index.html")
        wait(for: [tearDownExpectation!], timeout: 10.0)
        // verify the above rule still exists
        XCTAssert((WhitelistManager.shared.getAllItems()?.count)! >= 1)
        XCTAssert(WhitelistManager.shared.exists("domain.remove.com") == true)
        XCTAssert(WhitelistManager.shared.exists("https://data.domain.remove.com/index.html") == true)
        XCTAssert(WhitelistManager.shared.exists("https://") == false)
        // final tear down
        if (whitelistManagerStatusObserverRefForSetup != nil) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
        }
        if (whitelistManagerStatusObserverRefForTearDown != nil) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
        }
        tearDownExpectation = expectation(description: "removing whitelist entries")
        whitelistManagerStatusObserverRefForTearDown = WhitelistManager.shared.status.didChange.addHandler(target: self, handler: AdBlock_Tests.whitelistManagerStatusChangeObserverForTearDownOfRemoveDomainWithURL)
        // try to remove the rule using a specific URL - the remove should fail
        WhitelistManager.shared.remove("domain.remove.com")
        wait(for: [tearDownExpectation!], timeout: 10.0)
        XCTAssert(WhitelistManager.shared.exists("domain.remove.com") == false)
    }

    func whitelistManagerStatusChangeObserverForSetupOfRemoveDomainWithURL(data: (WhitelistManagerStatus, WhitelistManagerStatus)) {
        if (data.0 == .whitelistUpdateCompleted && data.1 == .idle) {
            whitelistManagerStatusObserverRefForSetup?.dispose()
            startUpExpectation?.fulfill()
        }
    }

    func whitelistManagerStatusChangeObserverForTearDownOfRemoveDomainWithURL(data: (WhitelistManagerStatus, WhitelistManagerStatus)) {
        if (data.0 == .whitelistUpdateCompleted && data.1 == .idle) {
            whitelistManagerStatusObserverRefForTearDown?.dispose()
            tearDownExpectation?.fulfill()
        }
    }
    
    func testSelectorFilter() {
        XCTAssert(Filter.isSelectorFilter(text: "www.foo.com##IMG[src='http://randomimg.com']") == true)
        XCTAssert(Filter.isSelectorFilter(text: "www.foo.com#@#IMG[src='http://randomimg.com']") == true)
        XCTAssert(Filter.isSelectorFilter(text: "www.foo.com#@IMG[src='http://randomimg.com']") == false)
        XCTAssert(Filter.isSelectorFilter(text: "www.foo.com#?#IMG[src='http://randomimg.com']") == false)
        XCTAssert(Filter.isSelectorFilter(text: "www.foo.com#$#IMG[src='http://randomimg.com']") == false)
        XCTAssert(Filter.isSelectorFilter(text: "www.foo.com#@@#IMG[src='http://randomimg.com']") == false)
    }
    
    func testExcludeSelectorFilter() {
        XCTAssert(Filter.isSelectorExcludeFilter(text: "www.foo.com##IMG[src='http://randomimg.com']") == false)
        XCTAssert(Filter.isSelectorExcludeFilter(text: "www.foo.com#@#IMG[src='http://randomimg.com']") == true)
        XCTAssert(Filter.isSelectorExcludeFilter(text: "www.foo.com#@IMG[src='http://randomimg.com']") == false)
        XCTAssert(Filter.isSelectorExcludeFilter(text: "www.foo.com#?#IMG[src='http://randomimg.com']") == false)
        XCTAssert(Filter.isSelectorExcludeFilter(text: "www.foo.com#$#IMG[src='http://randomimg.com']") == false)
        XCTAssert(Filter.isSelectorExcludeFilter(text: "www.foo.com#@@#IMG[src='http://randomimg.com']") == false)
    }
    
    func testWhitelistFilter() {
        XCTAssert(Filter.isWhitelistFilter(text: "www.foo.com@@IMG[src='http://randomimg.com']") == false)
        XCTAssert(Filter.isWhitelistFilter(text: "@@IMG[src='http://randomimg.com']") == true)
    }
    
    func testComment() {
        XCTAssert(Filter.isComment(text: "! foo comment") == true)
        XCTAssert(Filter.isComment(text: "[adblock foo comment") == true)
        XCTAssert(Filter.isComment(text: "(adblock foo comment") == true)
        XCTAssert(Filter.isComment(text: " ! foo comment") == false)
        XCTAssert(Filter.isComment(text: " [ adblock foo comment") == false)
        XCTAssert(Filter.isComment(text: " ( adblock foo comment") == false)
    }
    
    func testSelectorFilterFromText() {
        XCTAssert(Filter.fromText(text: "www.foo.com##IMG[src='http://randomimg.com']") is SelectorFilter)
        XCTAssert(Filter.fromText(text: "www.foo.com#@#IMG[src='http://randomimg.com']") is SelectorFilter)
        XCTAssert((Filter.fromText(text: "www.foo.com#@IMG[src='http://randomimg.com']") is SelectorFilter) == false)
        let selectorFilter = Filter.fromText(text: "www.foo.com##IMG[src='http://randomimg.com']")
        XCTAssert(selectorFilter === Filter.fromText(text: "www.foo.com##IMG[src='http://randomimg.com']"))
        XCTAssert(selectorFilter === Filter.cache["www.foo.com##IMG[src='http://randomimg.com']"])
        XCTAssert(selectorFilter?.domains?.has["www.foo.com"] ?? false)
        let sFilter = selectorFilter as! SelectorFilter
        XCTAssert(sFilter.selector == "IMG[src='http://randomimg.com']")
    }
    
    func testContentFilterFromText() {
        XCTAssert(Filter.fromText(text: "foo.com#$#uabinject-defuser") is SnippetFilter)
        XCTAssert(Filter.fromText(text: "foo.com#$#hide-if-contains-and-matches-style span a") is SnippetFilter)
        XCTAssert((Filter.fromText(text: "www.foo.com#@IMG[src='http://randomimg.com']") is SnippetFilter) == false)
        let snippetFilter = Filter.fromText(text: "foo.com#$#uabinject-defuser")
        XCTAssert(snippetFilter === Filter.fromText(text: "foo.com#$#uabinject-defuser"))
        XCTAssert(snippetFilter === Filter.cache["foo.com#$#uabinject-defuser"])
        XCTAssert(snippetFilter?.domains?.has["foo.com"] ?? false)
        let sFilter = snippetFilter as! SnippetFilter
        XCTAssert(sFilter.body == "uabinject-defuser")
    }
    
    func testCachingAndImmutableFilters() {
        let text = "safariadblock.com##div"
        let f = Filter.fromText(text: text)
        XCTAssert(f === Filter.fromText(text: text))
        let fCopy = f?.stringValue
        let f2 = SelectorFilter.merge(filter: f as! SelectorFilter, excludeFiltersIn: [Filter.fromText(text: "safariadblock.com#@#div") as! SelectorFilter])
        XCTAssert(f?.domains != f2.domains)
        let fSecondCopy = f?.stringValue
        XCTAssert(fCopy == fSecondCopy)
        XCTAssert(f === Filter.fromText(text: text))
    }
    
    func testDomainSetClone() {
        let d = DomainSet(data: ["": true, "a.com": false,  "b.a.com": true])
        let d2 = d.clone()
        XCTAssert(d !== d2)
        XCTAssert(d.stringValue == d2.stringValue)
    }
    
    func testDomainSetSubtract() {
        func normalize(data: [String: Bool]) -> [String: Bool] {
            var result: [String: Bool] = [:]
            for (domain, dBool) in data {
                result[domain == "ALL" ? DomainSet.ALL : domain] = dBool
            }
            return result
        }
        
        func localTest(data1: [String: Bool], data2: [String: Bool], result: [String: Bool]) {
            let set1 = DomainSet(data: normalize(data: data1))
            set1.subtract(other: DomainSet(data: normalize(data: data2)))
            XCTAssert(set1.has == normalize(data: result))
        }
        
        let T = true
        let F = false
        localTest(data1: [ "ALL": T ], data2: [ "ALL": T ], result: [ "ALL": F ])
        localTest(data1: [ "ALL": T ], data2: [ "ALL": F, "a": T ], result: [ "ALL": T, "a": F ])
        localTest(data1: [ "ALL": F, "a": T ], data2: [ "ALL": F, "a": T ], result: [ "ALL": F ])
        localTest(data1: [ "ALL": F, "a": T ], data2: [ "ALL": F, "b": T ], result: [ "ALL": F, "a": T ])
        localTest(data1: [ "ALL": F, "a": T ], data2: [ "ALL": F, "s.a": T ], result: [ "ALL": F, "a": T, "s.a": F ])
        localTest(data1: [ "ALL": F, "a": T, "c.b.a": F ], data2: [ "ALL": F, "b.a": T ], result: [ "ALL": F, "a": T, "b.a": F ])
        localTest(data1: [ "ALL": F, "a": T, "d.c.b.a": F ], data2: [ "ALL": F, "b.a": T, "c.b.a": F ], result: [ "ALL": F, "a": T, "b.a": F, "c.b.a": T, "d.c.b.a": F ])
        localTest(data1: [ "ALL": T, "b.a": F ], data2: [ "ALL": F, "d": T ], result: [ "ALL": T, "d": F, "b.a": F ])
        localTest(data1: [ "ALL": F, "b.a": T ], data2: [ "ALL": T, "d": F ], result: [ "ALL": F ])
        localTest(data1: [ "ALL": T, "b.a": F ], data2: [ "ALL": T, "a": F ], result: [ "ALL": F, "a": T, "b.a": F ])
        localTest(data1: [ "ALL": F, "b.a": T, "d.c.b.a": F ], data2: [ "ALL": F, "a": T, "c.b.a": F ], result: [ "ALL": F, "c.b.a": T, "d.c.b.a": F ])
        localTest(data1: [ "ALL": F, "c.b.a": T, "d.c.b.a": F ], data2: [ "ALL": F, "a": T, "d.a": F ], result: [ "ALL": F ])
        localTest(data1: [ "ALL": F, "b.a": T, "c.b.a": F ], data2: [ "ALL": F, "d": T ], result: [ "ALL": F, "b.a": T, "c.b.a": F ])
        localTest(data1: [ "ALL": T, "b.a": F ], data2: [ "ALL": F, "a": T, "d.a": F ], result: [ "ALL": T, "a": F, "d.a": T ])
    }
    
    func testDomainSetComputedHas() {
        let set1 = DomainSet(data: ["": false, "s.a": true])
        let set2 = DomainSet(data: ["": false, "a": true])
        XCTAssert(!set1.computedHas(domain: "a"))
        XCTAssert(set2.computedHas(domain: "s.a"))
    }
    
    func testNormalizeLine() {
        XCTAssert(try! FilterNormalizer.normalizeLine(filterText: "a##z").filter == "a##z")
        XCTAssert(try! FilterNormalizer.normalizeLine(filterText: "##[style]").filter == "~mail.google.com,~mail.yahoo.com##[style]")
        XCTAssert(try! FilterNormalizer.normalizeLine(filterText: "google.com##[style]").filter == "~mail.google.com,google.com##[style]")
        XCTAssertThrowsError(try FilterNormalizer.normalizeLine(filterText: "google.com####[style]"))
        XCTAssertThrowsError(try FilterNormalizer.normalizeLine(filterText: "foo$bar=c s p = ba z,cs p = script-src  'self'"))
    }

    func testEnsureExcluded() {
        let entries = [
            [ "a##z", [], "a##z" ],
            [ "##z", [], "##z" ],
            [ "##z", ["a"], "~a##z" ],
            [ "##z", ["a", "b"], "~a,~b##z" ],
            
            [ "a##z", [], "a##z" ],
            [ "a##z", ["a"], "~a,a##z" ],
            [ "a##z", ["a", "b"], "~a,a##z" ],
            
            [ "a##z", ["s.a"], "~s.a,a##z" ],
            [ "a##z", ["s.a", "b"], "~s.a,a##z" ],
            [ "a##z", ["a", "s.b"], "~a,a##z" ],
            
            [ "s.a##z", [], "s.a##z" ],
            [ "s.a##z", ["b"], "s.a##z" ],
            [ "s.a##z", ["a", "b"], "s.a##z" ],
            [ "s.a##z", ["s.s.a"], "~s.s.a,s.a##z" ],
            
            [ "a,b##z", ["a"], "~a,a,b##z" ],
            [ "a,b##z", ["a"], "~a,a,b##z" ],
            
            // Excluding a parent of an included child doesn"t exclude the child.  This
            // is probably fine.
            [ "mail.google.com##div[style]", ["google.com"], "mail.google.com##div[style]" ],
            [ "##div[style]", ["mail.google.com", "mail.yahoo.com"], "~mail.google.com,~mail.yahoo.com##div[style]" ],
            [ "ex.com##div[style]", ["mail.google.com", "mail.yahoo.com"], "ex.com##div[style]" ],
            [ "google.com##div[style]", ["mail.google.com", "mail.yahoo.com"], "~mail.google.com,google.com##div[style]" ],
        ]
        
        for entry in entries {
            XCTAssert(try! FilterNormalizer.ensureExcluded(selectorFilterText: entry[0] as! String, excludedDomains: entry[1] as! [String]) == entry[2] as! String)
        }
    }
    
    func testSelectorFilterMerge() {
        func localTestEmpty(a: String, b: [String]) {
            var c: [Filter] = []
            for f in b {
                if let filter = Filter.fromText(text: f) {
                    c.append(filter)
                }
            }
            let first = SelectorFilter.merge(filter: Filter.fromText(text: a) as! SelectorFilter, excludeFiltersIn: c as? [SelectorFilter])
            let result = DomainSet(data: ["": false])
            XCTAssert(first.domains?.stringValue == result.stringValue)
        }
        
        func localTest(a: String, b: [String], c: String) {
            var d: [Filter] = []
            for f in b {
                if let filter = Filter.fromText(text: f) {
                    d.append(filter)
                }
            }
            let first = SelectorFilter.merge(filter: Filter.fromText(text: a) as! SelectorFilter, excludeFiltersIn: d as? [SelectorFilter])
            let second = Filter.fromText(text: c)
            XCTAssert(first.id != second?.id)
            first.id = second?.id ?? -1
            XCTAssert(first.stringValue == second?.stringValue)
        }
        
        let f = [
            "a.com##div",
            "b.com##div",
            "sub.a.com##div",
            "~a.com##div",
            "##div",
        ]
        
        XCTAssert(SelectorFilter.merge(filter: Filter.fromText(text: f[0]) as! SelectorFilter, excludeFiltersIn: nil) == (Filter.fromText(text: f[0]) as! SelectorFilter))
        localTestEmpty(a: f[0], b: [f[0]])
        localTestEmpty(a: f[0], b: [f[4]])
        localTestEmpty(a: f[0], b: [f[1], f[2], f[3], f[4]])
        localTestEmpty(a: f[1], b: [f[3]])
        localTest(a: f[0], b: [f[1]], c: "a.com##div")
        localTest(a: f[0], b: [f[2]], c: "a.com,~sub.a.com##div")
        localTest(a: f[0], b: [f[3]], c: "a.com##div")
        localTest(a: f[0], b: [f[1], f[2], f[3]], c: "a.com,~sub.a.com##div")
        localTest(a: f[1], b: [f[2]], c: f[1])
    }
    
    func testFilterParseBlockRegexRule() {
        //XCTAssert((Filter.fromText(text: "/ddd|f?a[s]d/") as! PatternFilter).rule == "ddd|f?a[s]d")
        XCTAssert((Filter.fromText(text: "*asdf*d**dd*") as! PatternFilter).rule == "asdf.*d.*dd")
        XCTAssert((Filter.fromText(text: "|*asd|f*d**dd*|") as! PatternFilter).rule == "^.*asd\\|f.*d.*dd.*$")
        XCTAssert((Filter.fromText(text: "dd[]{}$%<>&()d") as! PatternFilter).rule == "dd\\[\\]\\{\\}\\$\\%\\<\\>\\&\\(\\)d")
        
        //XCTAssert((Filter.fromText(text: "@@/ddd|f?a[s]d/") as! PatternFilter).rule == "ddd|f?a[s]d")
        XCTAssert((Filter.fromText(text: "@@*asdf*d**dd*") as! PatternFilter).rule == "asdf.*d.*dd")
        XCTAssert((Filter.fromText(text: "@@|*asd|f*d**dd*|") as! PatternFilter).rule == "^.*asd\\|f.*d.*dd.*$")
        XCTAssert((Filter.fromText(text: "@@dd[]{}$%<>&()d") as! PatternFilter).rule == "dd\\[\\]\\{\\}\\$\\%\\<\\>\\&\\(\\)d")
        
        XCTAssert((Filter.fromText(text: "bla$image") as! PatternFilter).rule == "bla")
        XCTAssert((Filter.fromText(text: "bla$background") as! PatternFilter).rule == "bla")
        XCTAssert((Filter.fromText(text: "bla$~image") as! PatternFilter).rule == "bla")
        XCTAssert((Filter.fromText(text: "bla$~background") as! PatternFilter).rule == "bla")
        
        XCTAssert((Filter.fromText(text: "@@bla$~script,~other") as! PatternFilter).rule == "bla")
        XCTAssert((Filter.fromText(text: "@@http://bla$~script,~other") as! PatternFilter).rule == "http\\:\\/\\/bla")
        XCTAssert((Filter.fromText(text: "@@|ftp://bla$~script,~other") as! PatternFilter).rule == "^ftp\\:\\/\\/bla")
        XCTAssert((Filter.fromText(text: "@@bla$~script,~other,document") as! PatternFilter).rule == "bla")
        XCTAssert((Filter.fromText(text: "@@bla$~script,~other,~document") as! PatternFilter).rule == "bla")
        XCTAssert((Filter.fromText(text: "@@bla$document") as! PatternFilter).rule == "bla")
        XCTAssert((Filter.fromText(text: "@@bla$~script,~other,elemhide") as! PatternFilter).rule == "bla")
        XCTAssert((Filter.fromText(text: "@@bla$~script,~other,~elemhide") as! PatternFilter).rule == "bla")
        XCTAssert((Filter.fromText(text: "@@bla$elemhide") as! PatternFilter).rule == "bla")
    }
    
    func testFilterKey() {
        //XCTAssert((Filter.fromText(text: "/ddd|f?a[s]d/") as! PatternFilter).key == nil)
        XCTAssert((Filter.fromText(text: "*asdf*d**dd*") as! PatternFilter).key == nil)
        XCTAssert((Filter.fromText(text: "|*asd|f*d**dd*|") as! PatternFilter).key == nil)
        XCTAssert((Filter.fromText(text: "dd[]{}$%<>&()d") as! PatternFilter).key == nil)
        //XCTAssert((Filter.fromText(text: "@@/ddd|f?a[s]d/") as! PatternFilter).key == nil)
        XCTAssert((Filter.fromText(text: "@@*asdf*d**dd*") as! PatternFilter).key == nil)
        XCTAssert((Filter.fromText(text: "@@|*asd|f*d**dd*|") as! PatternFilter).key == nil)
        XCTAssert((Filter.fromText(text: "@@dd[]{}$%<>&()d") as! PatternFilter).key == nil)
    }
    
    func testElementHidingRules() {
        XCTAssert((Filter.fromText(text: "##ddd") as! SelectorFilter).selector == "ddd")
        XCTAssert((Filter.fromText(text: "##body > div:first-child") as! SelectorFilter).selector == "body > div:first-child")
        XCTAssert((Filter.fromText(text: "fOO##ddd") as! SelectorFilter).selector == "ddd")
        XCTAssert((Filter.fromText(text: "Foo,bAr##ddd") as! SelectorFilter).selector == "ddd")
        XCTAssert((Filter.fromText(text: "foo,~baR##ddd") as! SelectorFilter).selector == "ddd")
        XCTAssert((Filter.fromText(text: "foo,~baz,bar##ddd") as! SelectorFilter).selector == "ddd")
    }
    
    func testElementHidingExceptions() {
        XCTAssert((Filter.fromText(text: "#@#ddd") as! SelectorFilter).selector == "ddd")
        XCTAssert((Filter.fromText(text: "#@#body > div:first-child") as! SelectorFilter).selector == "body > div:first-child")
        XCTAssert((Filter.fromText(text: "fOO#@#ddd") as! SelectorFilter).selector == "ddd")
        XCTAssert((Filter.fromText(text: "Foo,bAr#@#ddd") as! SelectorFilter).selector == "ddd")
        XCTAssert((Filter.fromText(text: "foo,~baR#@#ddd") as! SelectorFilter).selector == "ddd")
        XCTAssert((Filter.fromText(text: "foo,~baz,bar#@#ddd") as! SelectorFilter).selector == "ddd")
    }
    
    func testElemHideEmulationFilters() {
        // Check valid domain combinations (text)
        XCTAssert((Filter.fromText(text: "fOO.cOm#?#:-abp-properties(abc)") as! ElemHideEmulationFilter).text == "fOO.cOm#?#:-abp-properties(abc)")
        XCTAssert((Filter.fromText(text: "Foo.com,~bAr.com#?#:-abp-properties(abc)") as! ElemHideEmulationFilter).text == "Foo.com,~bAr.com#?#:-abp-properties(abc)")
        XCTAssert((Filter.fromText(text: "foo.com,~baR#?#:-abp-properties(abc)") as! ElemHideEmulationFilter).text == "foo.com,~baR#?#:-abp-properties(abc)")
        XCTAssert((Filter.fromText(text: "~foo.com,bar.com#?#:-abp-properties(abc)") as! ElemHideEmulationFilter).text == "~foo.com,bar.com#?#:-abp-properties(abc)")
        
        // Check valid domain combinations (selector)
        XCTAssert((Filter.fromText(text: "fOO.cOm#?#:-abp-properties(abc)") as! ElemHideEmulationFilter).selector == ":-abp-properties(abc)")
        XCTAssert((Filter.fromText(text: "Foo.com,~bAr.com#?#:-abp-properties(abc)") as! ElemHideEmulationFilter).selector == ":-abp-properties(abc)")
        XCTAssert((Filter.fromText(text: "foo.com,~baR#?#:-abp-properties(abc)") as! ElemHideEmulationFilter).selector == ":-abp-properties(abc)")
        XCTAssert((Filter.fromText(text: "~foo.com,bar.com#?#:-abp-properties(abc)") as! ElemHideEmulationFilter).selector == ":-abp-properties(abc)")
        
        // Check some special cases
        XCTAssert((Filter.fromText(text: "foo.com#?#abc") as! ElemHideEmulationFilter).text == "foo.com#?#abc")
        XCTAssert((Filter.fromText(text: "foo.com#?#:-abp-foobar(abc)") as! ElemHideEmulationFilter).text == "foo.com#?#:-abp-foobar(abc)")
        XCTAssert((Filter.fromText(text: "foo.com#?#aaa :-abp-properties(abc) bbb") as! ElemHideEmulationFilter).text == "foo.com#?#aaa :-abp-properties(abc) bbb")
        XCTAssert((Filter.fromText(text: "foo.com#?#:-abp-properties(|background-image: url(data:*))") as! ElemHideEmulationFilter).text == "foo.com#?#:-abp-properties(|background-image: url(data:*))")
        
        // Check some special cases
        XCTAssert((Filter.fromText(text: "foo.com#?#abc") as! ElemHideEmulationFilter).selector == "abc")
        XCTAssert((Filter.fromText(text: "foo.com#?#:-abp-foobar(abc)") as! ElemHideEmulationFilter).selector == ":-abp-foobar(abc)")
        XCTAssert((Filter.fromText(text: "foo.com#?#aaa :-abp-properties(abc) bbb") as! ElemHideEmulationFilter).selector == "aaa :-abp-properties(abc) bbb")
        XCTAssert((Filter.fromText(text: "foo.com#?#:-abp-properties(|background-image: url(data:*))") as! ElemHideEmulationFilter).selector == ":-abp-properties(|background-image: url(data:*))")
        
        // test matching -abp-properties= (https://issues.adblockplus.org/ticket/5037).
        XCTAssert((Filter.fromText(text: "foo.com##[-abp-properties-bogus='abc']") as! SelectorFilter).selector == "[-abp-properties-bogus='abc']")
    }
    
    func testElemHideRulesWithBraces() {
        XCTAssert((Filter.fromText(text: "###foo{color: red}") as! SelectorFilter).selector == "#foo{color: red}")
        XCTAssert((Filter.fromText(text: "foo.com#?#:-abp-properties(/margin: [3-4]{2}/)") as! ElemHideEmulationFilter).text == "foo.com#?#:-abp-properties(/margin: [3-4]{2}/)")
        XCTAssert((Filter.fromText(text: "foo.com#?#:-abp-properties(/margin: [3-4]{2}/)") as! ElemHideEmulationFilter).selector == ":-abp-properties(/margin: [3-4]{2}/)")
    }
    
}
