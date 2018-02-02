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
        manager.session.getAllTasks { (tasks) in
            tasks.forEach({$0.cancel()})
        }
        manager.request(VGMPRadio.vgmpradioUrl).responseString(queue: DispatchQueue.global(qos: .default)) {
            response in
            if let error = response.error {
                completionHandler(.failure(error))
                return
            }
            let htmlResponse = response.result.value
            let playlistFetchRequest = NSFetchRequest<Playlist>(entityName: "Playlist")
            playlistFetchRequest.predicate = NSPredicate(format: "isFavorites == %@", NSNumber(value: true))
            var playlistObjects: [Playlist] = []
            DispatchQueue.main.sync {
                do {
                    playlistObjects = try Util.getManagedContext()?.fetch(playlistFetchRequest) ?? []
                } catch {
                    NSLog("Error fetching playlist with title \(NSLocalizedString("Likes", comment: "")): \(error.localizedDescription)")
                }
            }
            var favoritesList = playlistObjects.first

            if favoritesList == nil {
                DispatchQueue.main.sync {
                    guard let managedContext = Util.getManagedContext(),
                        let entity = NSEntityDescription.entity(forEntityName: "Playlist", in: managedContext) else {
                            return
                    }
                    favoritesList = Playlist(entity: entity, insertInto: managedContext)
                }
                favoritesList?.title = NSLocalizedString("Likes", comment: "")
                favoritesList?.index = 0
                favoritesList?.isFavorites = true
                
            }
            let list = [favoritesList!] + VGMPRadio.parseHtmlForPlaylist(htmlResponse)
            completionHandler(.success(list))
        }
    }
    
    class func getLastPlaylist() -> Playlist? {
        let index = UserDefaults.standard.integer(forKey: "lastPlaylistIndex")
        
        let playlistFetchRequest = NSFetchRequest<Playlist>(entityName: "Playlist")
        playlistFetchRequest.predicate = NSPredicate(format: "index == %d", index)
        var playlistObjects: [Playlist] = []
        do {
            playlistObjects = try Util.getManagedContext()?.fetch(playlistFetchRequest) ?? []
        } catch {
            NSLog("Error fetching playlist with index \(index)): \(error.localizedDescription)")
        }
        return playlistObjects.first
    }
    
    class func getLastSong() -> Song? {
        let id = UserDefaults.standard.integer(forKey: "lastSongId")
        
        let songFetchRequest = NSFetchRequest<Song>(entityName: "Song")
        songFetchRequest.predicate = NSPredicate(format: "audioId == %d", id)
        var songObjects: [Song] = []
        do {
            songObjects = try Util.getManagedContext()?.fetch(songFetchRequest) ?? []
        } catch {
            NSLog("Error fetching song with audioId \(id)): \(error.localizedDescription)")
        }
        return songObjects.first
    }
    
    private class func parseHtmlForPlaylist(_ _html: String?) -> [Playlist] {
        var playlistList: [Playlist] = []
        guard let html = _html,
              let doc = try? Kanna.HTML(html: html, encoding: .utf8) else {
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
            DispatchQueue.main.sync {
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
                    return
                }
                guard let managedContext = Util.getManagedContext(),
                    let entity = NSEntityDescription.entity(forEntityName: "Playlist", in: managedContext) else {
                        return
                }
                let newPlaylist = Playlist(entity: entity, insertInto: managedContext)
            
                newPlaylist.title = playlist.content
                newPlaylist.hasNew = false
                newPlaylist.index = Int16(i+1)  // +1 due to favorites list being first index always
                newPlaylist.sourceUrl = urlString
                playlistList.append(newPlaylist)
            }
        }
        return playlistList
    }
    
    private class func parseHtmlForSongs(_ _html: String?) -> [Song] {
        var songList: [Song] = []
        guard let html = _html,
            let doc = try? Kanna.HTML(html: html, encoding: .utf8) else {
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
                DispatchQueue.main.sync {
                    let songFetchRequest = NSFetchRequest<Song>(entityName: "Song")
                    songFetchRequest.predicate = NSPredicate(format: "audioId == %d", audioId)
                    var songObjects: [Song] = []
                    do {
                        songObjects = try Util.getManagedContext()?.fetch(songFetchRequest) ?? []
                    } catch {
                        NSLog("Error fetching song with audioId \(audioId): \(error.localizedDescription)")
                    }
                    var song: Song! = songObjects.first
                    if song != nil {
                        if let _ = songList.index(where: { (foundSong) -> Bool in
                            foundSong.audioId == songObjects.first!.audioId
                        }) {
                            return
                        }
                    }

                    guard let managedContext = Util.getManagedContext(),
                        let entity = NSEntityDescription.entity(forEntityName: "Song", in: managedContext) else {
                            return
                    }
                    if song == nil {
                        song = Song(entity: entity, insertInto: managedContext)
                    }
                
                    let urlString = track["audioUrl"] as! String
                    
                    if let schemeEnd = urlString.index(of: "/"),
                       let percentPath = urlString[schemeEnd...].addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                        song.sourceUrl = "https:" + percentPath
                    }
                    
                    if let artist = track["artist"] as? String {
                        song.game = artist
                    }
                    
                    song.audioId = Int32(audioId)
                    
                    if let albumArtUrl = track["artworkUrl"] as? String,
                       let schemeEnd = albumArtUrl.index(of: "/"),
                       let percentPath = albumArtUrl[schemeEnd...].addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                            song.albumArtUrl = "https:" + percentPath
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
        }
        return songList
    }
    
    class func getSongs(playlist: Playlist, index: Int, getNext: Bool, withCompletion completionHandler: @escaping (Result<[Song]>, Int, Bool, Bool) -> Void) {
        if playlist.isFavorites {
            let songFetchRequest = NSFetchRequest<Song>(entityName: "Song")
            songFetchRequest.predicate = NSPredicate(format: "favorite == %@", NSNumber(value: true))
            var songObjects: [Song] = []
            do {
                songObjects = try Util.getManagedContext()?.fetch(songFetchRequest) ?? []
            } catch {
                NSLog("Error fetching favorite songs")
            }
            completionHandler(.success(songObjects), index, false, getNext)
        } else {
            guard let url = playlist.sourceUrl else {
                completionHandler(.failure(BackendError.objectSerialization(reason: "No URL provided")), index, false, getNext)
                return
            }
            let manager = Alamofire.SessionManager.default
            manager.session.getAllTasks { (tasks) in
                tasks.forEach({$0.cancel()})
            }
            manager.request(URL(string: url)!).responseString(queue: DispatchQueue.global(qos: .default)) {
                response in
                if let error = response.error {
                    completionHandler(.failure(error), index, true, getNext)
                    return
                }
                let htmlResponse = response.result.value
                let list = VGMPRadio.parseHtmlForSongs(htmlResponse)
                completionHandler(.success(list), index, true, getNext)
            }
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
