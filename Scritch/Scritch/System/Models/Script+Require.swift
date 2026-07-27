//
//  Script+Require.swift
//  Scritch
//
//  Created by Ivan on 6/29/20.
//  Copyright © 2020 OKatBest. All rights reserved.
//

import Foundation
import JavaScriptCore

extension Script {
    
    // `@scritch/` is the preferred prefix, but `@boop/` is still honoured so that
    // scripts written for upstream Boop keep working unmodified.
    static private let libraryPrefixes = ["@scritch/", "@boop/"]
    static private let moduleExt = ".js"
    
    func setupRequire(context: JSContext) {
        let require: @convention(block) (String) -> (JSValue?) = {
             [unowned self] path in
            
            var path = path
            
            if !path.hasSuffix(Script.moduleExt) {
                path += Script.moduleExt
            }
            
            guard
                let url = self.url(for: path),
                let rawCode = try? String(contentsOf: url)
            else {
                return nil
            }
            
            // This is not ideal, I tried using native JSC bindings
            // but no luck getting it to play nice. TODO I guess?
            
           let wrappedCode =
"""
/***********************************
*     Start of Scritch's wrapper      *
***********************************/
            
(function() {
    var module = {
        exports: {}
    };
            
    const moduleWrapper = (function (exports, module) {

/***********************************
 *      End of Scritch's wrapper      *
 ***********************************/

\(rawCode)
            
/***********************************
*     Start of Scritch's wrapper      *
***********************************/
            
    }).apply(module.exports, [module.exports, module]);

    return module.exports;
})();
            
/***********************************
*      End of Scritch's wrapper      *
***********************************/
            
"""
            
            return JSContext.current().evaluateScript(wrappedCode, withSourceURL: url)
        }
        
        context.setObject(require, forKeyedSubscript: "require" as NSString)

    }
    
    private func url(for path: String) -> URL? {
        if let prefix = Script.libraryPrefixes.first(where: path.starts(with:)) {
            let fileName = String(path.dropFirst(prefix.count).dropLast(Script.moduleExt.count))
            return Bundle.main.url(forResource: fileName, withExtension: Script.moduleExt, subdirectory: "scripts/lib")
        }
        
        guard
            !self.isBuiltInt,
            let url = try? ScriptManager.getBookmarkURL()
        else {
            // For now, built in scripts can't import custom stuff.
            return nil
        }
        
        return url.appendingPathComponent(path, isDirectory: false)
                   
    }
}
