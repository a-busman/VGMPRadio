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
    
    var indicies: [Int] = []
    var indexIntoIndicies: Int = -1
    
    var currentNowPlayingInfo: [String : Any] = [:]
    
    var currentPlaylistIndex: Int = -1
    var currentPlaylist: Playlist?
    var currentSong: Song?
    var currentSongIndex: Int = -1
    
    var shouldUpdateNowPlaying = true
    
    var nowPlayingViewMinimumBottom: CGFloat = 60.0
    
    var currentlyPlaying: Bool = false
    var currentlySeekingBack: Bool = false
    var currentlySeekingForward: Bool = false
    
    var currentRate: Float = 0.0
    
    var seekTimer: Timer?
    
    var isMaximized: Bool = false
    
    var nowPlayingIsHidden: Bool = true
    
    var shuffle: Bool = false
    var repeats: Bool = false
    var repeat1: Bool = false
    
    private var _firstLayout: Bool = true
    
    private var _snapshotView: UIView?
    
    var currentTheme: Theme = .dark
    
    var originalOffset: CGFloat = 0.0
    var targetOffset:   CGFloat = 0.0

    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        self.currentTheme = Theme(rawValue: UserDefaults.standard.integer(forKey: "theme")) ?? .light
        self.shuffle = UserDefaults.standard.bool(forKey: "shuffle")
        self.repeats = UserDefaults.standard.bool(forKey: "repeats")
        self.repeat1 = UserDefaults.standard.bool(forKey: "repeat1")
        
        self.currentPlaylist = VGMPRadio.getLastPlaylist()
        self.currentSong     = VGMPRadio.getLastSong()
        
        if self.currentSong != nil {
            self.songListNavigationControllerContainer?.updateSelectedPlaylist(index: Int(self.currentPlaylist?.index ?? 0), songIndex: Int(self.currentSong?.audioId ?? 0))
        }
        
        self.currentPlaylistIndex = Int(self.currentPlaylist?.index ?? -1)
        
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
        
        commandCenter.seekForwardCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            let seekEvent = event as! MPSeekCommandEvent
            if seekEvent.type == MPSeekCommandEventType.beginSeeking {
                self.seekTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { (timer) in
                    self.currentRate = self.currentRate * 2.0
                    self.player?.setRate(self.currentRate, time: kCMTimeInvalid , atHostTime: kCMTimeInvalid)
                    if self.currentRate == 16.0 {
                        timer.invalidate()
                    }
                }
                self.currentRate = 2.0
                self.currentlySeekingForward = true
                self.player?.setRate(2.0, time: kCMTimeInvalid , atHostTime: kCMTimeInvalid)
            } else if seekEvent.type == MPSeekCommandEventType.endSeeking {
                self.currentlySeekingForward = false
                self.seekTimer?.invalidate()
                self.currentRate = self.currentlyPlaying ? 1.0 : 0.0
                self.player?.setRate(self.currentlyPlaying ? 1.0 : 0.0, time: kCMTimeInvalid , atHostTime: kCMTimeInvalid)
            }
            return .success
        }
        
        commandCenter.seekBackwardCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            let seekEvent = event as! MPSeekCommandEvent
            if seekEvent.type == MPSeekCommandEventType.beginSeeking {
                self.seekTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { (timer) in
                    self.currentRate = self.currentRate * 2.0
                    self.player?.setRate(self.currentRate, time: kCMTimeInvalid , atHostTime: kCMTimeInvalid)
                    if self.currentRate == -16.0 {
                        timer.invalidate()
                    }
                }
                self.currentlySeekingBack = true
                self.currentRate = -2.0
                self.player?.setRate(-2.0, time: kCMTimeInvalid , atHostTime: kCMTimeInvalid)
            } else if seekEvent.type == MPSeekCommandEventType.endSeeking {
                self.currentlySeekingBack = false
                self.seekTimer?.invalidate()
                self.currentRate = self.currentlyPlaying ? 1.0 : 0.0
                self.player?.setRate(self.currentlyPlaying ? 1.0 : 0.0, time: kCMTimeInvalid , atHostTime: kCMTimeInvalid)
            }
            return .success
        }
        
        commandCenter.changeShuffleModeCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            let shuffleStatus = event as! MPChangeShuffleModeCommandEvent
            
            if shuffleStatus.shuffleType == .off {
                self.shuffle = false
                let _currentSongIndex = self.indicies[self.currentSongIndex]
                self.currentSongIndex = _currentSongIndex
                self.indicies = Array(stride(from: 0, to: self.currentPlaylist?.songs?.count ?? 0, by: 1))
            } else {
                self.shuffle = true
                let _currentSongIndex = self.currentSongIndex
                self.indicies.remove(at: _currentSongIndex)
                self.currentSongIndex = 0
                self.indicies = [_currentSongIndex] + self.indicies.shuffled()
            }
            UserDefaults.standard.set(self.shuffle, forKey: "shuffle")
            self.nowPlayingViewController?.shuffle(enabled: self.shuffle)

            return .success
        }
        
        commandCenter.changeRepeatModeCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            let repeatStatus = event as! MPChangeRepeatModeCommandEvent
            
            if repeatStatus.repeatType == .all {
                self.repeats = true
                self.repeat1 = false
            } else if repeatStatus.repeatType == .one {
                self.repeats = true
                self.repeat1 = true
            } else {
                self.repeats = false
                self.repeat1 = false
            }
            UserDefaults.standard.set(self.repeats, forKey: "repeats")
            UserDefaults.standard.set(self.repeat1, forKey: "repeat1")
            self.nowPlayingViewController?.repeat(enabled: self.repeats, one: self.repeat1)
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleAudioInterruption), name: .AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
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
            self.songListNavigationControllerContainer?.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Theme", style: .plain, target: self, action: #selector(self.themeChange))

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
            self.nowPlayingViewMinimumBottom = 60.0 + self.view.safeAreaInsets.bottom
            self._firstLayout = false
            self.nowPlayingViewController?.theme = self.currentTheme
            self.songListNavigationControllerContainer?.theme = self.currentTheme
            self.nowPlayingViewController?.shuffle(enabled: self.shuffle)
            if self.shuffle {
                MPRemoteCommandCenter.shared().changeShuffleModeCommand.currentShuffleType = .items
            } else {
                MPRemoteCommandCenter.shared().changeShuffleModeCommand.currentShuffleType = .off
            }
            if self.repeat1 {
                MPRemoteCommandCenter.shared().changeRepeatModeCommand.currentRepeatType = .one
            } else if self.repeats {
                MPRemoteCommandCenter.shared().changeRepeatModeCommand.currentRepeatType = .all
            } else {
                MPRemoteCommandCenter.shared().changeRepeatModeCommand.currentRepeatType = .off
            }
            Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false, block: { (timer) in
                if self.currentSong != nil {
                    self.songSelected(playlist: self.currentPlaylist!, songIndex: Int(self.currentSong!.audioId), playlistIndex: Int(self.currentPlaylist!.index), play: false)
                }
            })
            self.nowPlayingViewController?.repeat(enabled: self.repeats, one: self.repeat1)
        }
    }
    
    @objc func handleAudioInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSessionInterruptionType(rawValue: typeValue) else {
                return
        }
        
        if type == .began {
            self.doPause()
        }
        else if type == .ended {
            guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSessionInterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                self.doPlay()
            }
        }
    }
    
    func nowPlayingTapped() {
        if !self.isMaximized {
            self._snapshotView = self.songListView?.snapshotView(afterScreenUpdates: false)
            if self._snapshotView != nil {
                self.songListView?.addSubview(self._snapshotView!)
            }
            self.nowPlayingViewController?.like(favorite: self.currentSong?.favorite ?? false, dislike: self.currentSong?.dislike ?? false)
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
            self.songListNavigationControllerContainer?.tableView?.reloadData()
            self.nowPlayingViewTopConstraint?.constant = -self.nowPlayingViewMinimumBottom
            self.isMaximized = false
            self._snapshotView?.removeFromSuperview()

            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: .curveEaseOut, animations: {
                self.view.layoutIfNeeded()
                self.shadowView?.alpha = 0.0
                self.songListView?.transform = .identity
                self.setNeedsStatusBarAppearanceUpdate()
            }, completion: nil)
            UIViewPropertyAnimator(duration: 0.5, dampingRatio: 1.0, animations: {
                self.songListView?.layer.cornerRadius = 0.0
                self.nowPlayingView?.layer.cornerRadius = 0.0
            }).startAnimation()
            self.nowPlayingViewController?.updateViewOnTap(maximized: false, duration: 0.5)
        }
    }
    
    @IBAction func nowPlayingPanned(sender: UIPanGestureRecognizer) {
        let y = sender.translation(in: self.view).y
        let percentage = min(100.0, max(0, (-(self.nowPlayingViewTopConstraint?.constant ?? 0) - self.nowPlayingViewMinimumBottom) / (((self.view.frame.height) - 33.0) - self.nowPlayingViewMinimumBottom)))
        switch (sender.state) {
        case .began:
            if self.isMaximized {
                self.originalOffset = -(self.view.frame.height - 33.0)
                self.targetOffset   = -self.nowPlayingViewMinimumBottom
                self.nowPlayingViewController?.unbendDragHandle()
            } else {
                self._snapshotView = self.songListView?.snapshotView(afterScreenUpdates: false)
                if self._snapshotView != nil {
                    self.songListView?.addSubview(self._snapshotView!)
                }
                self.originalOffset = -self.nowPlayingViewMinimumBottom
                self.targetOffset   = -(self.view.frame.height - 33.0)
                self.nowPlayingViewController?.bendDragHandle()
            }
            self.nowPlayingViewTopConstraint?.constant = self.originalOffset + y
            self.view.layoutIfNeeded()
        case .changed:
            if self.originalOffset + y >= -(self.view.frame.height - 33.0) && self.originalOffset + y <= -self.nowPlayingViewMinimumBottom {
                self.nowPlayingViewTopConstraint?.constant = self.originalOffset + (self.isMaximized ? y / 2.0 : y)
                self.shadowView?.alpha = percentage * 0.5
                self.songListView?.transform = CGAffineTransform.identity.scaledBy(x: 1.0 - ((1 - 0.94) * percentage), y: 1.0 - ((1 - 0.94) * percentage))

                self.view.layoutIfNeeded()
                if !self.isMaximized {
                    self.songListView?.layer.cornerRadius = 12.0 * percentage
                    self.nowPlayingView?.layer.cornerRadius = 12.0 * percentage
                    self.nowPlayingViewController?.updateView(percentage: percentage)
                }
            }
        case .ended:
            NSLog("\(sender.velocity(in: self.view).y)")
            if (self.originalOffset + y > -self.view.frame.height / 2.0 && !(sender.velocity(in: self.view).y < -300.0)) || sender.velocity(in: self.view).y > 300.0  {
                self.songListNavigationControllerContainer?.tableView?.reloadData()
                let prevLocation = self.nowPlayingViewTopConstraint?.constant ?? 0
                self.nowPlayingViewTopConstraint?.constant = -self.nowPlayingViewMinimumBottom
                self.isMaximized = false
                
                UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: fabs(sender.velocity(in: self.view).y) / (prevLocation - self.nowPlayingViewMinimumBottom), options: .curveLinear, animations: {
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
            } else if (self.originalOffset + y <= -self.view.frame.height / 2.0 && !(sender.velocity(in: self.view).y > 300.0)) || sender.velocity(in: self.view).y < -300.0 {
                self.nowPlayingViewController?.like(favorite: self.currentSong?.favorite ?? false, dislike: self.currentSong?.dislike ?? false)
                let prevLocation = self.nowPlayingViewTopConstraint?.constant ?? 0
                self.nowPlayingViewTopConstraint?.constant = -(self.view.frame.height - 33.0)
                self.isMaximized = true
                UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: fabs(sender.velocity(in: self.view).y) / (prevLocation - (self.view.frame.height - 33)), options: .curveLinear, animations: {
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
            }
        default:
            NSLog("default")
        }
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
        let _ = Util.deleteAllData(entity: "Playlist")
        let _ = Util.deleteAllData(entity: "Song")
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
    }
    
    func updateNowPlayingInfo() {
        self.nowPlayingViewController?.nowPlaying = self.currentlyPlaying
        if let song = self.currentSong {
            self.nowPlayingViewController?.updateNowPlaying(title: song.title, game: song.game, playlist: self.currentPlaylist?.title)
            self.nowPlayingViewController?.like(favorite: song.favorite, dislike: song.dislike)
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
                    self.nowPlayingViewController?.backgroundImageView?.image = image
                    self.currentNowPlayingInfo[MPMediaItemPropertyArtwork] = mediaItemArtwork
                    self.nowPlayingViewController?.hasAlbumArt = true
                } else {
                    self.nowPlayingViewController?.hasAlbumArt = false
                    let mediaItemArtwork = MPMediaItemArtwork(boundsSize: CGSize(width: 768, height: 768), requestHandler: { (size) -> UIImage in
                        return #imageLiteral(resourceName: "music_note")
                    })
                    self.currentNowPlayingInfo[MPMediaItemPropertyArtwork] = mediaItemArtwork
                    self.nowPlayingViewController?.backgroundImageView?.image = nil
                }
            })
        }
        UserDefaults.standard.set(Int(self.currentPlaylist?.index ?? -1), forKey: "lastPlaylistIndex")
        UserDefaults.standard.set(Int(self.currentSong?.audioId ?? -1), forKey: "lastSongId")
        MPNowPlayingInfoCenter.default().nowPlayingInfo = self.currentNowPlayingInfo
    }
    
    func updateCurrentSong(play: Bool) {
        let index: Int = self.indicies[self.currentSongIndex]
        guard let player = self.player,
              let songs = self.currentPlaylist?.songs,
              let song = songs[index] as? Song,
              let url = song.sourceUrl else {
            NSLog("Couldn't play song at index \(index)")
            return
        }
        self.currentSong = song
        if let currentItem = player.currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
        }
        let playerItem = AVPlayerItem(url: url)
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        player.replaceCurrentItem(with: playerItem)
        if play {
            player.play()
        }
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
    
    func hideNowPlaying() {
        if !self.nowPlayingIsHidden {
            self.nowPlayingIsHidden = true
            self.nowPlayingViewTopConstraint?.constant = 0.0
            self.nowPlayingViewController?.view.setNeedsLayout()
            self.songListNavigationControllerContainer?.tableView?.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            self.songListNavigationControllerContainer?.tableView?.scrollIndicatorInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            self.nowPlayingViewController?.backgroundImageView?.alpha = 0.0
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
    
    @objc func playerDidFinishPlaying(notification: NSNotification) {
        if !self.currentlySeekingBack {
            if self.repeat1 {
                self.player?.seek(to: CMTime(seconds: 0.0, preferredTimescale: 60))
                self.player?.play()
            } else {
                self.doNext()
            }
        }
    }
    
    func doScrub(percentage: Double) {
        if let duration = self.player?.currentItem?.duration.seconds {
            self.player?.seek(to: CMTime(seconds: percentage * duration, preferredTimescale: 1))
        }
        
    }
    
    func doPause() {
        if self.currentSongIndex < 0 || self.currentSongIndex >= self.indicies.count {
            return
        }
        self.songListNavigationControllerContainer?.updateCurrentlyPlayingSong(song: Int(self.currentSong?.audioId ?? 0), playlist: self.currentPlaylistIndex)

        if let currentTime = self.player?.currentItem?.currentTime().seconds {
            self.currentNowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        }
        self.currentNowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        self.player?.pause()
        self.currentlyPlaying = false
        self.updateNowPlayingInfo()
        self.songListNavigationControllerContainer?.pause(song: Int(self.currentSong?.audioId ?? 0), playlist: self.currentPlaylistIndex)
        self.songListNavigationControllerContainer?.updatePlayStatus(isPlaying: false, isStopped: false)
    }
    
    func doPlay() {
        if self.currentSongIndex < 0 || self.currentSongIndex >= self.indicies.count {
            return
        }
        self.songListNavigationControllerContainer?.updateCurrentlyPlayingSong(song: Int(self.currentSong?.audioId ?? 0), playlist: self.currentPlaylistIndex)
        if let currentTime = self.player?.currentItem?.currentTime().seconds {
            self.currentNowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        }
        self.currentNowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        self.player?.play()
        self.currentlyPlaying = true
        self.updateNowPlayingInfo()
        self.songListNavigationControllerContainer?.play(song: Int(self.currentSong?.audioId ?? 0), playlist: self.currentPlaylistIndex)
        self.songListNavigationControllerContainer?.updatePlayStatus(isPlaying: true, isStopped: false)
    }
    
    func doNext() {
        if self.currentSongIndex < 0 || self.currentSongIndex >= self.indicies.count {
            return
        }
        if let playlist = self.currentPlaylist,
            let songCount = playlist.songs?.count {
            if self.currentSongIndex < songCount - 1 {
                self.currentSongIndex += 1
                let index = self.indicies[self.currentSongIndex]
                if let nextSong = self.currentPlaylist?.songs?[index] as? Song,
                    nextSong.dislike {
                    self.doNext()
                } else {
                    self.updateCurrentSong(play: self.currentlyPlaying)
                    self.songListNavigationControllerContainer?.updateCurrentlyPlayingSong(song: Int(self.currentSong?.audioId ?? 0), playlist: self.currentPlaylistIndex)
                }
            } else {
                if self.repeats {
                    self.currentSongIndex = 0
                    let index = self.indicies[self.currentSongIndex]
                    if let nextSong = self.currentPlaylist?.songs?[index] as? Song,
                        nextSong.dislike {
                        self.doNext()
                    } else {
                        self.updateCurrentSong(play: self.currentlyPlaying)
                        self.songListNavigationControllerContainer?.updateCurrentlyPlayingSong(song: Int(self.currentSong?.audioId ?? 0), playlist: self.currentPlaylistIndex)
                    }
                } else {
                    self.player?.pause()
                    self.songListNavigationControllerContainer?.stop(song: Int(self.currentSong?.audioId ?? 0), playlist: self.currentPlaylistIndex)
                    self.songListNavigationControllerContainer?.updatePlayStatus(isPlaying: false, isStopped: true)
                    self.currentlyPlaying = false
                    self.hideNowPlaying()
                }
            }
        }
    }
    
    func doPrevious() {
        if self.currentSongIndex < 0 || self.currentSongIndex >= self.indicies.count {
            return
        }
        if let currentItem = self.player?.currentItem {
            if currentItem.currentTime().seconds > 5.0 || self.currentSongIndex <= 0 {
                self.player?.seek(to: CMTime(seconds: 0.0, preferredTimescale: 60))
            } else {
                if self.currentSongIndex > 0 {
                    self.currentSongIndex -= 1
                    let index = self.indicies[self.currentSongIndex]
                    if let prevSong = self.currentPlaylist?.songs?[index] as? Song,
                        prevSong.dislike {
                        self.doPrevious()
                    } else {
                        self.updateCurrentSong(play: self.currentlyPlaying)
                        self.songListNavigationControllerContainer?.updateCurrentlyPlayingSong(song: Int(self.currentSong?.audioId ?? 0), playlist: self.currentPlaylistIndex)
                    }
                }
            }
            self.currentlyPlaying = true
        }
    }
    
    func save() {
        do {
            try Util.getManagedContext()?.save()
        } catch {
            fatalError("Failure to save context: \(error)")
        }
    }
}

extension MainContainerViewController: SongListViewControllerDelegate {
    func songSelected(playlist: Playlist, songIndex: Int, playlistIndex: Int, play: Bool) {
        self.currentPlaylist = playlist
        let songs = Array(playlist.songs!) as! [Song]
        let index = songs.index(where: { (item) -> Bool in
            item.audioId == songIndex
        }) ?? 0
        if self.shuffle {
            var newIndicies = Array(stride(from: 0, to: playlist.songs?.count ?? 0, by: 1))
            newIndicies.remove(at: index)
            newIndicies = [index] + newIndicies.shuffled()
            self.currentSongIndex = 0
            self.indicies = newIndicies
        } else {
            self.indicies = Array(stride(from: 0, to: playlist.songs?.count ?? 0, by: 1))
            self.currentSongIndex = index
        }
        self.currentSong = playlist.songs?[self.indicies[self.currentSongIndex]] as? Song
        self.currentPlaylistIndex = playlistIndex
        self.showNowPlayingMinimalView()
        self.currentlyPlaying = play
        self.updateCurrentSong(play: play)
        self.songListNavigationControllerContainer?.updateCurrentlyPlayingSong(song: Int(self.currentSong?.audioId ?? 0), playlist: self.currentPlaylistIndex)
    }
    
    func shuffleTapped(playlist: Playlist, playlistIndex: Int) {
        self.currentPlaylist = playlist
        self.shuffle = true
        UserDefaults.standard.set(self.shuffle, forKey: "shuffle")
        MPRemoteCommandCenter.shared().changeShuffleModeCommand.currentShuffleType = .items
        self.nowPlayingViewController?.shuffle(enabled: self.shuffle)
        self.currentSongIndex = 0
        self.indicies = stride(from: 0, to: playlist.songs?.count ?? 0, by: 1).shuffled()
        self.currentSong = playlist.songs?[self.indicies[self.currentSongIndex]] as? Song
        self.currentPlaylistIndex = playlistIndex
        self.showNowPlayingMinimalView()
        self.currentlyPlaying = true
        self.updateCurrentSong(play: true)
        self.songListNavigationControllerContainer?.updateCurrentlyPlayingSong(song: Int(self.currentSong?.audioId ?? 0), playlist: self.currentPlaylistIndex)
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
    
    func tapped() {
        self.nowPlayingTapped()
    }
    
    func seekForward(begin: Bool) {
        if begin {
            self.seekTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { (timer) in
                self.currentRate = self.currentRate * 2.0
                self.player?.setRate(self.currentRate, time: kCMTimeInvalid , atHostTime: kCMTimeInvalid)
                if self.currentRate == 16.0 {
                    timer.invalidate()
                }
            }
            self.currentRate = 2.0
            self.currentlySeekingForward = true
            self.player?.setRate(2.0, time: kCMTimeInvalid , atHostTime: kCMTimeInvalid)
        } else {
            self.currentlySeekingForward = false
            self.seekTimer?.invalidate()
            self.currentRate = self.currentlyPlaying ? 1.0 : 0.0
            self.player?.setRate(self.currentlyPlaying ? 1.0 : 0.0, time: kCMTimeInvalid , atHostTime: kCMTimeInvalid)
        }
    }
    
    func seekBackward(begin: Bool) {
        if begin {
            self.seekTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { (timer) in
                self.currentRate = self.currentRate * 2.0
                self.player?.setRate(self.currentRate, time: kCMTimeInvalid , atHostTime: kCMTimeInvalid)
                if self.currentRate == -16.0 {
                    timer.invalidate()
                }
            }
            self.currentRate = -2.0
            self.currentlySeekingForward = true
            self.player?.setRate(-2.0, time: kCMTimeInvalid , atHostTime: kCMTimeInvalid)
        } else {
            self.currentlySeekingForward = false
            self.seekTimer?.invalidate()
            self.currentRate = self.currentlyPlaying ? 1.0 : 0.0
            self.player?.setRate(self.currentlyPlaying ? 1.0 : 0.0, time: kCMTimeInvalid , atHostTime: kCMTimeInvalid)
        }
    }
    
    func shuffleToggled() {
        self.shuffle = !self.shuffle
        if self.shuffle {
            let _currentSongIndex = self.currentSongIndex
            self.indicies.remove(at: _currentSongIndex)
            self.currentSongIndex = 0
            self.indicies = [_currentSongIndex] + self.indicies.shuffled()
            MPRemoteCommandCenter.shared().changeShuffleModeCommand.currentShuffleType = .items
        } else {
            let _currentSongIndex = self.indicies[self.currentSongIndex]
            self.currentSongIndex = _currentSongIndex
            self.indicies = Array(stride(from: 0, to: self.currentPlaylist?.songs?.count ?? 0, by: 1))
            MPRemoteCommandCenter.shared().changeShuffleModeCommand.currentShuffleType = .off
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = self.currentNowPlayingInfo
        UserDefaults.standard.set(self.shuffle, forKey: "shuffle")
        self.nowPlayingViewController?.shuffle(enabled: self.shuffle)
    }
    
    func repeatToggled() {
        if self.repeats && self.repeat1 {
            self.repeats = false
            self.repeat1 = false
            MPRemoteCommandCenter.shared().changeRepeatModeCommand.currentRepeatType = .off
        } else if self.repeats {
            self.repeat1 = true
            MPRemoteCommandCenter.shared().changeRepeatModeCommand.currentRepeatType = .one
        } else {
            self.repeats = true
            MPRemoteCommandCenter.shared().changeRepeatModeCommand.currentRepeatType = .all
        }
        UserDefaults.standard.set(self.repeats, forKey: "repeats")
        UserDefaults.standard.set(self.repeat1, forKey: "repeat1")
        self.nowPlayingViewController?.repeat(enabled: self.repeats, one: self.repeat1)
    }
    
    func favorite() {
        if let song = self.currentSong {
            song.favorite = !song.favorite
            song.dislike = false
            if self.currentPlaylist?.isFavorites ?? false && !song.favorite {
                self.currentPlaylist?.removeFromSongs(song)
            }
            self.save()
            self.nowPlayingViewController?.like(favorite: song.favorite, dislike: song.dislike)
        }
    }
    
    func dislike() {
        if let song = self.currentSong {
            song.dislike = !song.dislike
            if self.currentPlaylist?.isFavorites ?? false && song.favorite {
                self.currentPlaylist?.removeFromSongs(song)
            }
            song.favorite = false
            self.save()
            self.nowPlayingViewController?.like(favorite: song.favorite, dislike: song.dislike)
        }
    }
}
