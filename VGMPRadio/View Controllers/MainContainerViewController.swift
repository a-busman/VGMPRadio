//
//  ViewController.swift
//  VGMPRadio
//
//  Created by Alex Busman on 1/12/18.
//  Copyright © 2018 Alex Busman. All rights reserved.
//

import UIKit

import AVFoundation
import MediaPlayer
import Kingfisher

class MainContainerViewController: UIViewController {
    
    @IBOutlet weak var songListView:   UIView?
    @IBOutlet weak var nowPlayingView: UIView?
    @IBOutlet weak var nowPlayingViewTopConstraint: NSLayoutConstraint?
    @IBOutlet weak var shadowView: UIView?
    
    var songListNavigationControllerContainer: SongListViewController?
    var nowPlayingViewController: NowPlayingViewController?
    var player: AVPlayer?
    var currentUrl: URL?
    
    var currentNowPlayingInfo: [String : Any] = [:]
    
    var currentPlaylistIndex: Int = -1
    var currentPlaylist: Playlist?
    var currentSongIndex: Int = -1
    
    var shouldUpdateNowPlaying = true
    
    let nowPlayingViewMinimumBottom: CGFloat = 60.0
    
    var currentlyPlaying: Bool = false
    
    var isMaximized: Bool = false
    
    var nowPlayingIsHidden: Bool = true
    
    private var _firstLayout: Bool = true
    
    private var _snapshotView: UIView?
    
    var currentTheme: Theme = .dark

    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        self.currentTheme = Theme(rawValue: UserDefaults.standard.integer(forKey: "theme")) ?? .dark
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.pauseCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            self.doPause()
            return .success
        }
        
        commandCenter.playCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            self.doPlay()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            self.doNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            self.doPrevious()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            let positionEvent = event as! MPChangePlaybackPositionCommandEvent
            self.player?.seek(to: CMTime(seconds: positionEvent.positionTime, preferredTimescale: 1))
            return .success
        }
        
        self.player = AVPlayer()
        self.player?.automaticallyWaitsToMinimizeStalling = false
        self.player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1.0/60.0, preferredTimescale: 60), queue: nil, using: { time in
            self.currentNowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time.seconds
            if time.seconds > 0.0 {
                self.currentNowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
            } else {
                self.currentNowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = self.currentNowPlayingInfo
            if let duration = self.player?.currentItem?.duration.seconds,
                !duration.isNaN {
                self.nowPlayingViewController?.updateScrubBar(seconds: time.seconds, updateBar: true)
            }
        })
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? UINavigationController,
            segue.identifier == "song_list_segue" {
            self.songListNavigationControllerContainer = vc.visibleViewController as? SongListViewController
            self.songListNavigationControllerContainer?.delegate = self
            self.songListNavigationControllerContainer?.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(self.themeChange))
            //self.songListNavigationControllerContainer?.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(self.deleteAll))
        } else if segue.identifier == "now_playing_segue" {
            self.nowPlayingViewController = segue.destination as? NowPlayingViewController
            self.nowPlayingViewController?.delegate = self
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        get {
            if self.currentTheme == .dark || self.isMaximized {
                return .lightContent
            } else {
                return .default
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        if self._firstLayout {
            self._firstLayout = false
            self.nowPlayingViewController?.theme = self.currentTheme
            self.songListNavigationControllerContainer?.theme = self.currentTheme
        }
    }
    @IBAction func nowPlayingTapped(sender: UITapGestureRecognizer) {
        if !self.isMaximized {
            self._snapshotView = self.songListView?.snapshotView(afterScreenUpdates: false)
            if self._snapshotView != nil {
                self.songListView?.addSubview(self._snapshotView!)
            }
            self.nowPlayingViewTopConstraint?.constant = -(self.view.frame.height - 33.0)
            self.isMaximized = true
            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: .curveEaseOut, animations: {
                self.view.layoutIfNeeded()
                self.shadowView?.alpha = 0.5
                self.setNeedsStatusBarAppearanceUpdate()
                self.songListView?.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            }, completion: nil)
            UIViewPropertyAnimator(duration: 0.5, dampingRatio: 1.0, animations: {
                self.songListView?.layer.cornerRadius = 12.0
                self.nowPlayingView?.layer.cornerRadius = 12.0
            }).startAnimation()

            self.nowPlayingViewController?.updateViewOnTap(maximized: true, duration: 0.5)
        } else {
            self.nowPlayingViewTopConstraint?.constant = -self.nowPlayingViewMinimumBottom
            self.isMaximized = false
            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: .curveEaseOut, animations: {
                self.view.layoutIfNeeded()
                self.shadowView?.alpha = 0.0
                self.songListView?.transform = .identity
                self.setNeedsStatusBarAppearanceUpdate()
            }, completion: { (complete) in
                self._snapshotView?.removeFromSuperview()
            })
            UIViewPropertyAnimator(duration: 0.5, dampingRatio: 1.0, animations: {
                self.songListView?.layer.cornerRadius = 0.0
                self.nowPlayingView?.layer.cornerRadius = 0.0
            }).startAnimation()
            self.nowPlayingViewController?.updateViewOnTap(maximized: false, duration: 0.5)
        }
    }
    
    @IBAction func nowPlayingPanned(sender: UIPanGestureRecognizer) {
        NSLog("Pan!")
    }
    
    @objc func themeChange(sender: UIBarButtonItem) {
        if self.currentTheme == .light {
            self.currentTheme = .dark
        } else {
            self.currentTheme = .light
        }
        self.nowPlayingViewController?.theme = self.currentTheme
        self.songListNavigationControllerContainer?.theme = self.currentTheme
        UserDefaults.standard.set(self.currentTheme.rawValue, forKey: "theme")
    }
    
    @objc func deleteAll(sender: UIBarButtonItem) {
        Util.deleteAllData(entity: "Playlist")
        Util.deleteAllData(entity: "Song")
    }
    
    func updateNowPlayingInfo() {
        if let song = self.currentPlaylist?.songs?[self.currentSongIndex] as? Song {
            self.nowPlayingViewController?.updateNowPlaying(title: song.title, game: song.game, playlist: self.currentPlaylist?.title)

            self.nowPlayingViewController?.titleSmallLabel?.text = song.title
            self.nowPlayingViewController?.duration = Double(song.length)
            self.nowPlayingViewController?.albumArtImageView?.kf.setImage(with: song.albumArtUrl, placeholder: #imageLiteral(resourceName: "music_note"), options: [.transition(.fade(0.5))], progressBlock: nil, completionHandler: { (image, error, cacheType, url) in
                if image != nil {
                    let mediaItemArtwork = MPMediaItemArtwork(boundsSize: CGSize(width: 768, height: 768), requestHandler: { (size) -> UIImage in
                        if let scaledImage = image?.image(with: size) {
                            return scaledImage
                        } else {
                            return image!
                        }
                    })
                    if let data = UIImagePNGRepresentation(image!) {
                        let png = UIImage(data: data)
                        self.nowPlayingViewController?.backgroundImageView?.image = png
                    }
                    self.currentNowPlayingInfo[MPMediaItemPropertyArtwork] = mediaItemArtwork
                    self.nowPlayingViewController?.hasAlbumArt = true
                } else {
                    self.nowPlayingViewController?.hasAlbumArt = false
                    let mediaItemArtwork = MPMediaItemArtwork(boundsSize: CGSize(width: 768, height: 768), requestHandler: { (size) -> UIImage in
                        return #imageLiteral(resourceName: "music_note")
                    })
                    self.currentNowPlayingInfo[MPMediaItemPropertyArtwork] = mediaItemArtwork
                }
            })
            self.nowPlayingViewController?.nowPlaying = self.currentlyPlaying
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = self.currentNowPlayingInfo
    }
    
    func playCurrentSong() {
        guard let player = self.player,
              let songs = self.currentPlaylist?.songs,
              let song = songs[self.currentSongIndex] as? Song,
              let url = song.sourceUrl else {
            NSLog("Couldn't play song at index \(self.currentSongIndex)")
            return
        }
        if let currentItem = player.currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
        }
        let playerItem = AVPlayerItem(url: url)
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        player.replaceCurrentItem(with: playerItem)
        player.play()
        self.currentNowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        self.currentNowPlayingInfo[MPMediaItemPropertyArtist] = song.game
        self.currentNowPlayingInfo[MPMediaItemPropertyAlbumTitle] = self.currentPlaylist?.title
        self.currentNowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = song.length
        self.currentNowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        self.updateNowPlayingInfo()
    }
    
    func showNowPlayingMinimalView() {
        if self.nowPlayingIsHidden {
            self.nowPlayingIsHidden = false
            self.nowPlayingViewTopConstraint?.constant = -self.nowPlayingViewMinimumBottom
            self.nowPlayingViewController?.view.setNeedsLayout()
            self.songListNavigationControllerContainer?.tableView?.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: self.nowPlayingViewMinimumBottom, right: 0.0)
            self.songListNavigationControllerContainer?.tableView?.scrollIndicatorInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: self.nowPlayingViewMinimumBottom, right: 0.0)
            self.nowPlayingViewController?.backgroundImageView?.alpha = 0.0
            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: .curveEaseOut, animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)
            
        }
    }
    
    @objc func playerDidFinishPlaying(notification: NSNotification) {
        self.doNext()
    }
    
    func doScrub(percentage: Double) {
        if let duration = self.player?.currentItem?.duration.seconds {
            self.player?.seek(to: CMTime(seconds: percentage * duration, preferredTimescale: 1))
        }
        
    }
    
    func doPause() {
        if let currentTime = self.player?.currentItem?.currentTime().seconds {
            self.currentNowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        }
        self.currentNowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        self.player?.pause()
        self.currentlyPlaying = false
        self.updateNowPlayingInfo()
        self.songListNavigationControllerContainer?.pause(song: self.currentSongIndex, playlist: self.currentPlaylistIndex)
        self.songListNavigationControllerContainer?.updatePlayStatus(isPlaying: false, isStopped: false)
    }
    
    func doPlay() {
        if let currentTime = self.player?.currentItem?.currentTime().seconds {
            self.currentNowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        }
        self.currentNowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        self.player?.play()
        self.currentlyPlaying = true
        self.updateNowPlayingInfo()
        self.songListNavigationControllerContainer?.play(song: self.currentSongIndex, playlist: self.currentPlaylistIndex)
        self.songListNavigationControllerContainer?.updatePlayStatus(isPlaying: true, isStopped: false)
    }
    
    func doNext() {
        if let playlist = self.currentPlaylist,
            let songCount = playlist.songs?.count {
            if self.currentSongIndex < songCount - 1 {
                self.currentSongIndex += 1
                self.songListNavigationControllerContainer?.updateCurrentlyPlayingSong(song: self.currentSongIndex, playlist: self.currentPlaylistIndex)
                self.playCurrentSong()
                self.currentlyPlaying = true
            } else {
                self.songListNavigationControllerContainer?.stop(song: self.currentSongIndex, playlist: self.currentPlaylistIndex)
                self.songListNavigationControllerContainer?.updatePlayStatus(isPlaying: false, isStopped: true)
                self.currentlyPlaying = false
            }
        }
    }
    
    func doPrevious() {
        if let currentItem = self.player?.currentItem {
            if currentItem.currentTime().seconds > 5.0 || self.currentSongIndex <= 0 {
                self.player?.seek(to: CMTime(seconds: 0.0, preferredTimescale: 60))
            } else {
                if self.currentSongIndex > 0 {
                    self.currentSongIndex -= 1
                    self.songListNavigationControllerContainer?.updateCurrentlyPlayingSong(song: self.currentSongIndex, playlist: self.currentPlaylistIndex)
                    self.playCurrentSong()
                }
            }
            self.currentlyPlaying = true
        }
    }
}

extension MainContainerViewController: SongListViewControllerDelegate {
    func songSelected(playlist: Playlist, songIndex: Int, playlistIndex: Int) {
        self.currentPlaylist = playlist
        self.currentSongIndex = songIndex
        self.currentPlaylistIndex = playlistIndex
        self.showNowPlayingMinimalView()
        self.currentlyPlaying = true
        self.playCurrentSong()
    }
}

extension MainContainerViewController: NowPlayingViewControllerDelegate {
    func playPauseTrack() {
        if self.currentlyPlaying {
            self.doPause()
        } else {
            self.doPlay()
        }
    }
    
    func nextTrack() {
        self.doNext()
    }
    
    func previousTrack() {
        self.doPrevious()
    }
    
    func scrubTrack(percentage: Double) {
        self.doScrub(percentage: percentage)
    }
    
    func shuffleTracks() {
        return
    }
    func repeatTracks() {
        return
    }
}
