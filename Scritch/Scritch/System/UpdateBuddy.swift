//
//  UpdateBuddy.swift
//  Scritch
//
//  Created by Ivan on 5/30/20.
//  Copyright © 2020 OKatBest. All rights reserved.
//

import Foundation

class UpdateBuddy: NSObject {
    
    @IBOutlet weak var statusView: StatusView!
    
    var firstCheck = true
    
    override init() {
        super.init()
        self.check()
    }
    
    /// Scritch has no release feed of its own yet, so update checking is a no-op.
    /// Pointing this at upstream Boop's feed would report their releases as ours.
    /// To re-enable, host a `version.json` and set `updateFeed` to its URL.
    static let updateFeed: URL? = nil

    func check() {

        guard let url = UpdateBuddy.updateFeed else {
            return
        }

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil

        let session = URLSession.init(configuration: config)

        session.dataTask(with: URLRequest(url: url), completionHandler: { data, response, error -> Void in
            guard let data = data else {
                return
            }
            
            DispatchQueue.main.async {
                try? self.handleResponse(data: data)
            }
            
        }).resume()
    }
    
    private func handleResponse(data: Data) throws {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(VersionContainer.self, from: data)
        
        #if APPSTORE
        
        let latest = payload.mas
        
        #else
        
        let latest = payload.standalone
        
        #endif
        
        guard let thisVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return
        }
        
        if latest.version.compare(thisVersion, options: .numeric) == .orderedDescending {
            self.statusView.setStatus(.updateAvailable(latest.link))
        } else if !firstCheck {
            self.statusView.setStatus(.success("Scritch is up to date!"))
        }
        
        self.firstCheck = false
    }
}
