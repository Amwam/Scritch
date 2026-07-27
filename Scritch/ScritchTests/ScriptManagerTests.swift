//
//  ScriptManagerTests.swift
//  ScritchTests
//
//  Created by Ivan on 3/21/20.
//  Copyright © 2020 OKatBest. All rights reserved.
//

import XCTest
@testable import Scritch

class ScriptManagerTests: XCTestCase {
    
    let manager = ScriptManager()


    func testManager() {
        XCTAssertFalse(manager.scripts.isEmpty)
    }

}
