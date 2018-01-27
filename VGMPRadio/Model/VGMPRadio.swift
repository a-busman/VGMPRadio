//
//  VGMPRadio.swift
//  VGMPRadio
//
//  Created by Alex Busman on 1/15/18.
//  Copyright © 2018 Alex Busman. All rights reserved.
//

import UIKit
import Alamofire
import Kanna
import CoreData

enum BackendError: Error {
    case urlError(reason: String)
    case objectSerialization(reason: String)
}

class VGMPRadio {
    enum VGMPRadioError: Error {
        case indexOutOfRange
    }
    class var vgmpradioUrl: URL {
        get {
            return URL(string: "https://vgmpradio2.com")!
        }
    }
    class func getPlaylists(withCompletion completionHandler: @escaping (Result<[Playlist]>) -> Void) {
        let manager = Alamofire.SessionManager.default
        manager.request(VGMPRadio.vgmpradioUrl).responseString {
            response in
            if let error = response.error {
                completionHandler(.failure(error))
                return
            }
            let htmlResponse = response.result.value
            let list = VGMPRadio.parseHtmlForPlaylist(htmlResponse)
            completionHandler(.success(list))
        }
        // TODO: Get actual playlists from website
        
    }
    
    private class func parseHtmlForPlaylist(_ _html: String?) -> [Playlist] {
        var playlistList: [Playlist] = []
        guard let html = _html,
              let doc = try? Kanna.HTML(html: html, encoding: .utf8),
              let managedContext = Util.getManagedContext(),
              let entity = NSEntityDescription.entity(forEntityName: "Playlist", in: managedContext) else {
            return []
        }
        
        // Find playlist section in page
        for (i, playlist) in doc.css("li[class^='page_item']").enumerated() {
            // Separate link and name
            guard let innerHtml = playlist.innerHTML,
                  let playlistHtml = try? Kanna.HTML(html: innerHtml, encoding: .utf8),
                  let title = playlist.content else {
                    continue
            }
            let link = playlistHtml.css("a")
            guard let urlString = link[0]["href"] else {
                continue
            }
            
            let playlistFetchRequest = NSFetchRequest<Playlist>(entityName: "Playlist")
            playlistFetchRequest.predicate = NSPredicate(format: "title == %@", title)
            var playlistObjects: [Playlist] = []
            do {
                playlistObjects = try Util.getManagedContext()?.fetch(playlistFetchRequest) ?? []
            } catch {
                NSLog("Error fetching playlist with title \(title): \(error.localizedDescription)")
            }
            if playlistObjects.count > 0 {
                playlistList.append(contentsOf: playlistObjects)
                continue
            }
            let newPlaylist = Playlist(entity: entity, insertInto: managedContext)
            newPlaylist.title = playlist.content
            newPlaylist.hasNew = false
            newPlaylist.index = Int16(i)
            newPlaylist.sourceUrl = URL(string: urlString)
            playlistList.append(newPlaylist)
        }
        return playlistList
    }
    
    private class func parseHtmlForSongs(_ _html: String?) -> [Song] {
        var songList: [Song] = []
        guard let html = _html,
            let doc = try? Kanna.HTML(html: html, encoding: .utf8),
            let managedContext = Util.getManagedContext(),
            let entity = NSEntityDescription.entity(forEntityName: "Song", in: managedContext) else {
                return []
        }
        
        // Find playlist section in page
        for songListJson in doc.css("script[class^='cue-playlist-data']") {
            // Separate link and name
            guard let data = songListJson.content?.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tracks = json?["tracks"] as? [[String: Any]] else {
                    continue
            }
            
            for track in tracks {
                guard let audioId = track["audioId"] as? Int else {
                    continue
                }
                
                let songFetchRequest = NSFetchRequest<Song>(entityName: "Song")
                songFetchRequest.predicate = NSPredicate(format: "audioId == %d", audioId)
                var songObjects: [Song] = []
                do {
                    songObjects = try Util.getManagedContext()?.fetch(songFetchRequest) ?? []
                } catch {
                    NSLog("Error fetching song with audioId \(audioId): \(error.localizedDescription)")
                }
                if songObjects.count > 0 {
                    songList.append(contentsOf: songObjects)
                    continue
                }

                let song = Song(entity: entity, insertInto: managedContext)
                let urlString = track["audioUrl"] as! String
                
                if let schemeEnd = urlString.index(of: "/"),
                   let percentPath = urlString[schemeEnd...].addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                    song.sourceUrl = URL(string: "https:" + percentPath)
                }
                
                if let artist = track["artist"] as? String {
                    song.game = artist
                }
                
                if let albumArtUrl = track["artworkUrl"] as? String,
                   let schemeEnd = albumArtUrl.index(of: "/"),
                   let percentPath = albumArtUrl[schemeEnd...].addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                        song.albumArtUrl = URL(string: "https:" + percentPath)
                }
                
                if let title = track["title"] as? String {
                    if song.game == nil || song.game! == "" {
                        song.title = String(title.split(separator: "-").last!).trimmingCharacters(in: .whitespacesAndNewlines)
                        if let lastHyphenIndex = title.range(of: "-", options: .backwards)?.lowerBound {
                            song.game = String(title[..<lastHyphenIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } else {
                        song.title = title
                    }
                }
                if let lengthString = track["length"] as? String,
                   let minString = lengthString.split(separator: ":").first,
                   let secString = lengthString.split(separator: ":").last {
                    var seconds = Int32(secString)!
                    seconds += Int32(minString)! * 60
                    song.length = seconds
                }
                songList.append(song)
            }
        }
        return songList
    }
    
    class func getSongs(playlist: Playlist, index: Int, withCompletion completionHandler: @escaping (Result<[Song]>, Int) -> Void) {
        guard let url = playlist.sourceUrl else {
            completionHandler(.failure(BackendError.objectSerialization(reason: "No URL provided")), index)
            return
        }
        let manager = Alamofire.SessionManager.default
        manager.request(url).responseString {
            response in
            if let error = response.error {
                completionHandler(.failure(error), index)
                return
            }
            let htmlResponse = response.result.value
            let list = VGMPRadio.parseHtmlForSongs(htmlResponse)
            completionHandler(.success(list), index)
        }
    }
    
    class func playlistSort(p1: Playlist, p2: Playlist) throws -> Bool {
        if p1.index < 0 {
            throw VGMPRadioError.indexOutOfRange
        }
        if p1.index < p2.index {
            return true
        } else {
            return false
        }
    }
}
