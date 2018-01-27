//
//  NowPlayingViewController.swift
//  VGMPRadio
//
//  Created by Alex Busman on 1/18/18.
//  Copyright © 2018 Alex Busman. All rights reserved.
//
import Foundation
import UIKit
import MarqueeLabel
import MediaPlayer

protocol NowPlayingViewControllerDelegate {
    func playPauseTrack()
    func nextTrack()
    func previousTrack()
    func scrubTrack(percentage: Double)
    func shuffleTracks()
    func repeatTracks()
}

class NowPlayingViewController: UIViewController {
    @IBOutlet weak var albumArtImageView:    UIImageView?
    @IBOutlet weak var backgroundImageView:  UIImageView?
    @IBOutlet weak var titleSmallLabel:      UILabel?
    @IBOutlet weak var playPauseSmallView:   UIView?
    @IBOutlet weak var nextTrackSmallView:   UIView?
    @IBOutlet weak var playPauseSmallButton: UIButton?
    @IBOutlet weak var nextTrackSmallButton: UIButton?
    @IBOutlet weak var visualEffectView:     UIVisualEffectView?
    @IBOutlet weak var playPauseButton:      UIButton?
    @IBOutlet weak var nextTrackButton:      UIButton?
    @IBOutlet weak var prevTrackButton:      UIButton?
    @IBOutlet weak var volumeDownImageView:  UIImageView?
    @IBOutlet weak var volumeUpImageView:    UIImageView?
    @IBOutlet weak var fakeVolumeSlider:     UISlider?
    @IBOutlet weak var scrubBarSlider:       ScrubBar?
    @IBOutlet weak var currentTimeLabel:     UILabel?
    @IBOutlet weak var timeRemainingLabel:   UILabel?
    
    @IBOutlet weak var titleMarquee: MarqueeLabel?
    @IBOutlet weak var gameMarquee:  MarqueeLabel?
    
    @IBOutlet weak var albumArtLeadingConstraint:  NSLayoutConstraint?
    @IBOutlet weak var albumArtTrailingConstraint: NSLayoutConstraint?
    @IBOutlet weak var albumArtTopConstraint:      NSLayoutConstraint?
    
    @IBOutlet weak var backgroundAlbumArtWidthConstraint:  NSLayoutConstraint?
    @IBOutlet weak var backgroundAlbumArtHeightConstraint: NSLayoutConstraint?
    
    @IBOutlet weak var scrubBarWidthConstraint:  NSLayoutConstraint?
    @IBOutlet weak var scrubBarBottomConstraint: NSLayoutConstraint?
    
    @IBOutlet weak var volumeViewPlaceholder:  UIView?
    @IBOutlet weak var airPlayViewPlaceholder: UIView?
    
    @IBOutlet weak var currentTimeTopConstraint:   NSLayoutConstraint?
    @IBOutlet weak var timeRemainingTopConstraint: NSLayoutConstraint?
        
    var playSmallImage:  UIImage? = #imageLiteral(resourceName: "play")
    var nextSmallImage:  UIImage? = #imageLiteral(resourceName: "FF")
    var pauseSmallImage: UIImage? = #imageLiteral(resourceName: "pause")
    
    var playImage:  UIImage? = #imageLiteral(resourceName: "play")
    var pauseImage: UIImage? = #imageLiteral(resourceName: "pause")
    var nextImage:  UIImage? = #imageLiteral(resourceName: "FF")
    var prevImage:  UIImage? = #imageLiteral(resourceName: "RW")
    
    var volUpImage:   UIImage? = #imageLiteral(resourceName: "volume_up")
    var volDownImage: UIImage? = #imageLiteral(resourceName: "volume_down")
    
    let scrubBarBottomDefault: CGFloat = -27.0
    let scrubBarBottomFocused: CGFloat = -15.0
    let minimumArtLeadingConstraint:  CGFloat =   20.0
    let minimumArtTrailingConstraint: CGFloat = -305.0
    let minimumArtTopConstraint:      CGFloat =    5.0
    let maximumArtConstraints:        CGFloat =   63.0
    let scrubPlayingConstraints: CGFloat = 50.0
    
    let artPlayingConstraints: CGFloat = 32.0

    let minimumBackgroundArtConstraints: CGFloat = 0.0
    let maximumBackgroundArtConstraints: CGFloat = 0.0
    
    let hiddenBackgroundArtConstraints: CGFloat = -50.0
    
    let timeMovedDownValue: CGFloat = 0.0
    private var _duration: Double = 0.0
    
    var duration: Double {
        set(newValue) {
            if newValue != self._duration {
                self.timeRemainingLabel?.text = String(format: "-%d:%02d", Int(newValue / 60), Int(newValue.truncatingRemainder(dividingBy: 60)))
                self.currentTimeLabel?.text = "0:00"
                self.scrubBarSlider?.setValue(0.0, animated: false)
                self._currentScrubBarValue = 0.0
                self._duration = newValue
            }
        }
        get {
            return self._duration
        }
    }
    
    var isMaximized: Bool = false
    
    var volumeView:  MPVolumeView = MPVolumeView()
    var airPlayView: MPVolumeView = MPVolumeView()
    
    private var _currentScrubBarValue: Float = 0.0
    private var _currentlyScrubbing: Bool = false
    
    private var _nowPlaying: Bool = false
    private var _hasAlbumArt: Bool = false
    private var _firstLoad: Bool = true
    private var _currentTheme: Theme = .dark
    
    var hasAlbumArt: Bool {
        set(newValue) {
            self._hasAlbumArt = newValue
            if !newValue {
                self.albumArtImageView?.layer.borderWidth = 0.5
            } else {
                self.albumArtImageView?.layer.borderWidth = 0.0
            }
        }
        get {
            return self._hasAlbumArt
        }
    }
    var nowPlaying: Bool {
        set(newValue) {
            self._nowPlaying = newValue
            if newValue == true {
                self.playPauseSmallButton?.setImage(self.pauseSmallImage, for: .normal)
                self.playPauseButton?.setImage(self.pauseImage, for: .normal)
                if self.isMaximized {
                    self.albumArtTopConstraint?.constant      =  self.artPlayingConstraints
                    self.albumArtLeadingConstraint?.constant  =  self.artPlayingConstraints
                    self.albumArtTrailingConstraint?.constant = -self.artPlayingConstraints
                    //self.backgroundAlbumArtHeightConstraint?.constant = self.maximumBackgroundArtConstraints
                    //self.backgroundAlbumArtWidthConstraint?.constant  = self.maximumBackgroundArtConstraints
                    self.view.setNeedsLayout()
                    UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.0, options: .curveEaseInOut, animations: {
                        self.backgroundImageView?.alpha = 1.0
                        self.view.layoutIfNeeded()
                    })
                }
            } else {
                self.playPauseSmallButton?.setImage(self.playSmallImage, for: .normal)
                self.playPauseButton?.setImage(self.playImage, for: .normal)
                if self.isMaximized {
                    self.albumArtTopConstraint?.constant      =  self.maximumArtConstraints
                    self.albumArtLeadingConstraint?.constant  =  self.maximumArtConstraints
                    self.albumArtTrailingConstraint?.constant = -self.maximumArtConstraints
                    //self.backgroundAlbumArtHeightConstraint?.constant = self.hiddenBackgroundArtConstraints
                    //self.backgroundAlbumArtWidthConstraint?.constant  = self.hiddenBackgroundArtConstraints
                    self.view.setNeedsLayout()
                    UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: .curveEaseInOut, animations: {
                        self.backgroundImageView?.alpha = 0.0
                        self.view.layoutIfNeeded()
                    }, completion: nil)
                }
            }
        }
        get {
            return self._nowPlaying
        }
    }
    
    var theme: Theme {
        set(newValue) {
            self._currentTheme = newValue
            if newValue == .light {
                self.visualEffectView?.effect = UIBlurEffect(style: .light)
                self.titleSmallLabel?.textColor = .black
                self.titleMarquee?.textColor = .black
                self.gameMarquee?.textColor = .black
                self.playSmallImage = self.playSmallImage?.invertColors()
                self.nextSmallImage = self.nextSmallImage?.invertColors()
                self.pauseSmallImage = self.pauseSmallImage?.invertColors()
                self.playImage = self.playImage?.invertColors()
                self.pauseImage = self.pauseImage?.invertColors()
                self.nextImage = self.nextImage?.invertColors()
                self.prevImage = self.prevImage?.invertColors()
                self.volUpImage = self.volUpImage?.invertColors()
                self.volDownImage = self.volDownImage?.invertColors()
            } else {
                self.visualEffectView?.effect = UIBlurEffect(style: .dark)
                self.titleSmallLabel?.textColor = .white
                self.titleMarquee?.textColor = .white
                self.gameMarquee?.textColor = .white
                self.playSmallImage = #imageLiteral(resourceName: "play")
                self.nextSmallImage = #imageLiteral(resourceName: "FF")
                self.pauseSmallImage = #imageLiteral(resourceName: "pause")
                self.playImage = #imageLiteral(resourceName: "play")
                self.pauseImage = #imageLiteral(resourceName: "pause")
                self.nextImage = #imageLiteral(resourceName: "FF")
                self.prevImage = #imageLiteral(resourceName: "RW")
                self.volUpImage = #imageLiteral(resourceName: "volume_up")
                self.volDownImage = #imageLiteral(resourceName: "volume_down")
            }
            
            if self._nowPlaying {
                self.playPauseSmallButton?.setImage(self.pauseSmallImage, for: .normal)
                self.playPauseButton?.setImage(self.pauseImage, for: .normal)
            } else {
                self.playPauseSmallButton?.setImage(self.playSmallImage, for: .normal)
                self.playPauseButton?.setImage(self.playImage, for: .normal)
            }
            self.nextTrackSmallButton?.setImage(self.nextSmallImage, for: .normal)
            self.nextTrackButton?.setImage(self.nextImage, for: .normal)
            self.prevTrackButton?.setImage(self.prevImage, for: .normal)
            self.volumeUpImageView?.image = self.volUpImage
            self.volumeDownImageView?.image = self.volDownImage
        }
        get {
            return self._currentTheme
        }
    }
    
    var delegate: NowPlayingViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.albumArtTrailingConstraint?.constant = self.minimumArtTrailingConstraint
        self.albumArtLeadingConstraint?.constant  = self.minimumArtLeadingConstraint
        self.albumArtTopConstraint?.constant      = self.minimumArtTopConstraint
        
        self.backgroundAlbumArtWidthConstraint?.constant  = self.minimumBackgroundArtConstraints
        self.backgroundAlbumArtHeightConstraint?.constant = self.minimumBackgroundArtConstraints
        self.prevTrackButton?.setImage(self.prevImage, for: .normal)
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if self._firstLoad {
            self.albumArtImageView?.layer.borderColor = UIColor(white: 0.8, alpha: 1.0).cgColor
            self._firstLoad = false
            self.fakeVolumeSlider?.setThumbImage(UIImage(), for: .normal)
            self.fakeVolumeSlider?.setThumbImage(UIImage(), for: .disabled)
            self.fakeVolumeSlider?.setValue(0.0, animated: false)
            self.fakeVolumeSlider?.isEnabled = false
            let activeImage = UIImage.circle(diameter: 31.0, fillColor: .darkGray)
            self.scrubBarSlider?.setThumbImage(UIImage.circle(diameter: 6.0, fillColor: .darkGray, offset: CGPoint(x: 0.5, y: 0.5)), for: .normal)
            self.scrubBarSlider?.setThumbImage(activeImage, for: .highlighted)
            self.scrubBarSlider?.setThumbImage(activeImage, for: .selected)
            self.scrubBarSlider?.setThumbImage(activeImage, for: .focused)
            self.scrubBarWidthConstraint?.constant = self.view.frame.width - self.maximumArtConstraints
            self.view.layoutIfNeeded()
        }
    }
    
    func updateViewOnTap(maximized: Bool, duration: TimeInterval) {
        self.isMaximized = maximized
        if maximized {
            self.titleMarquee?.restartLabel()
            self.gameMarquee?.restartLabel()
            if self.volumeViewPlaceholder != nil {
                self.volumeView = MPVolumeView(frame: self.volumeViewPlaceholder!.bounds)
                self.volumeView.showsRouteButton = false
                if self._currentTheme == .light {
                    self.volumeView.tintColor = .darkGray
                } else {
                    self.volumeView.tintColor = .white
                }
                self.volumeViewPlaceholder?.addSubview(self.volumeView)
            }
            if self.airPlayViewPlaceholder != nil {
                self.airPlayView = MPVolumeView(frame: self.airPlayViewPlaceholder!.bounds)
                self.airPlayView.showsVolumeSlider = false
                self.airPlayView.setRouteButtonImage(#imageLiteral(resourceName: "airplay_selected"), for: .selected)
                if self._currentTheme == .light {
                    self.airPlayView.setRouteButtonImage(#imageLiteral(resourceName: "airplay"), for: .normal)
                } else {
                    let invertedImage = #imageLiteral(resourceName: "airplay").invertColors()
                    self.airPlayView.setRouteButtonImage(invertedImage?.image(with: #imageLiteral(resourceName: "airplay").size), for: .normal)
                }
                self.airPlayView.tintColor = .darkGray
                self.airPlayViewPlaceholder?.addSubview(self.airPlayView)
            }
            if self._nowPlaying {
                self.albumArtTopConstraint?.constant      =  self.artPlayingConstraints
                self.albumArtLeadingConstraint?.constant  =  self.artPlayingConstraints
                self.albumArtTrailingConstraint?.constant = -self.artPlayingConstraints
                
                //self.backgroundAlbumArtWidthConstraint?.constant = self.maximumBackgroundArtConstraints
                //self.backgroundAlbumArtHeightConstraint?.constant = self.maximumBackgroundArtConstraints
            } else {
                self.albumArtTopConstraint?.constant      =  self.maximumArtConstraints
                self.albumArtLeadingConstraint?.constant  =  self.maximumArtConstraints
                self.albumArtTrailingConstraint?.constant = -self.maximumArtConstraints
                
                //self.backgroundAlbumArtWidthConstraint?.constant  = self.hiddenBackgroundArtConstraints
                //self.backgroundAlbumArtHeightConstraint?.constant = self.hiddenBackgroundArtConstraints
            }
            UIView.animate(withDuration: duration * 0.3) {
                self.playPauseSmallView?.alpha = 0.0
                self.nextTrackSmallView?.alpha = 0.0
                self.titleSmallLabel?.alpha = 0.0
                if self._nowPlaying {
                    self.backgroundImageView?.alpha = 1.0
                }
            }
            UIViewPropertyAnimator(duration: duration, dampingRatio: 1.0, animations: {
                self.albumArtImageView?.layer.cornerRadius = 8.0
            }).startAnimation()
        } else {
            self.albumArtTopConstraint?.constant      = self.minimumArtTopConstraint
            self.albumArtLeadingConstraint?.constant  = self.minimumArtLeadingConstraint
            self.albumArtTrailingConstraint?.constant = self.minimumArtTrailingConstraint
            
            //self.backgroundAlbumArtWidthConstraint?.constant  = self.minimumBackgroundArtConstraints
            //self.backgroundAlbumArtHeightConstraint?.constant = self.minimumBackgroundArtConstraints
            UIView.animate(withDuration: duration, animations: {
                self.playPauseSmallView?.alpha = 1.0
                self.nextTrackSmallView?.alpha = 1.0
                self.titleSmallLabel?.alpha = 1.0
                self.backgroundImageView?.alpha = 0.0
            }, completion: { (complete) in
                self.volumeView.removeFromSuperview()
                self.airPlayView.removeFromSuperview()
            })
            UIViewPropertyAnimator(duration: duration, dampingRatio: 1.0, animations: {
                self.albumArtImageView?.layer.cornerRadius = 5.0
            }).startAnimation()
        }
        UIView.animate(withDuration: duration, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: .curveEaseOut, animations: {
            if maximized {
                self.view.backgroundColor = UIColor(white: 1.0, alpha: 1.0)
            } else {
                self.view.backgroundColor = UIColor(white: 0.5, alpha: 0.0)
            }
            self.view.layoutIfNeeded()
        }, completion: nil)
        
    }
    
    func updateNowPlaying(title: String?, game: String?, playlist: String?)
    {
        self.titleSmallLabel?.text = title
        if let titleMarquee = self.titleMarquee {
            titleMarquee.text = title
            if titleMarquee.labelShouldScroll() {
                titleMarquee.leadingBuffer = 27.0
            } else {
                titleMarquee.leadingBuffer = 0.0
            }
        }
        if let gameMarquee = self.gameMarquee {
            if game != nil && playlist != nil {
                gameMarquee.text = "\(game!) － \(playlist!)"
            } else if game != nil {
                gameMarquee.text = "\(game!)"
            } else if playlist != nil {
                gameMarquee.text = "\(playlist!)"
            } else {
                gameMarquee.text = nil
            }
            if gameMarquee.labelShouldScroll() {
                gameMarquee.leadingBuffer = 27.0
            } else {
                gameMarquee.leadingBuffer = 0.0
            }
        }
    }
    
    func updateView(percentage: CGFloat) {
        self.albumArtTopConstraint?.constant = ((self.maximumArtConstraints - self.minimumArtTopConstraint) * percentage) + self.minimumArtTopConstraint
        self.albumArtLeadingConstraint?.constant = ((self.maximumArtConstraints - self.minimumArtLeadingConstraint) * percentage) + self.minimumArtLeadingConstraint
        self.albumArtTrailingConstraint?.constant = ((self.maximumArtConstraints - (-self.minimumArtTrailingConstraint)) * percentage) + self.minimumArtTrailingConstraint
        self.view.layoutIfNeeded()
    }
    
    func updateScrubBar(seconds: Double, updateBar: Bool) {
        if let slider = self.scrubBarSlider {
           if !self._currentlyScrubbing {
                let timeLeft = floor(self.duration) - floor(seconds)
                let percentageProgress = seconds / self.duration
                self.timeRemainingLabel?.text = String(format: "-%d:%02d", Int(timeLeft/60), Int(timeLeft.truncatingRemainder(dividingBy: 60)))
                self.currentTimeLabel?.text = String(format: "%d:%02d", Int(seconds/60), Int(seconds.truncatingRemainder(dividingBy: 60)))
                if updateBar {
                    self._currentScrubBarValue = Float(percentageProgress)
                    slider.setValue(Float(percentageProgress), animated: false)
                }
            } else if !updateBar {
                let timeLeft = floor(self.duration) - floor(seconds)
                self.timeRemainingLabel?.text = String(format: "-%d:%02d", Int(timeLeft/60), Int(timeLeft.truncatingRemainder(dividingBy: 60)))
                self.currentTimeLabel?.text = String(format: "%d:%02d", Int(seconds/60), Int(seconds.truncatingRemainder(dividingBy: 60)))
            }
        }
    }

    @IBAction func mediaButtonTouchUpInside(sender: UIButton) {
        if sender.tag == 0 {
            self.delegate?.playPauseTrack()
        } else if sender.tag == 1 {
            self.delegate?.nextTrack()
        } else if sender.tag == 2 {
            self.delegate?.playPauseTrack()
        } else if sender.tag == 3 {
            self.delegate?.nextTrack()
        } else if sender.tag == 4 {
            self.delegate?.previousTrack()
        }
    }
    
    @IBAction func mediaButtonTouchDown(sender: UIButton) {
        
    }
    
    @IBAction func mediaButtonTouchDragExit(sender: UIButton) {
        
    }
    
    @IBAction func scrubBarTouchDown(sender: UISlider) {
        self.scrubBarSlider?.setThumbImage(UIImage.circle(diameter: 31.0, fillColor: .darkGray), for: .normal)
        self.scrubBarBottomConstraint?.constant = self.scrubBarBottomFocused
        self.currentTimeTopConstraint?.constant = -12.0
        self.timeRemainingTopConstraint?.constant = -12.0
        self.view.layoutIfNeeded()
        if !self._nowPlaying {
            self.albumArtTopConstraint?.constant = self.artPlayingConstraints
        } else {
            self.albumArtLeadingConstraint?.constant  =  self.scrubPlayingConstraints
            self.albumArtTrailingConstraint?.constant = -self.scrubPlayingConstraints
        }
        if sender.value < 0.11 {
            self.currentTimeTopConstraint?.constant = self.timeMovedDownValue
        } else if sender.value > 0.87 {
            self.timeRemainingTopConstraint?.constant = self.timeMovedDownValue
        }
        UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: .curveEaseInOut, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
        self._currentlyScrubbing = true
    }
    
    @IBAction func scrubBarTouchUpInside(sender: UISlider) {
        self.scrubBarSlider?.setThumbImage(UIImage.circle(diameter: 6.0, fillColor: .darkGray, offset: CGPoint(x: 0.5, y: 0.5)), for: .normal)
        self.scrubBarBottomConstraint?.constant = self.scrubBarBottomDefault
        self.currentTimeTopConstraint?.constant = 0.0
        self.timeRemainingTopConstraint?.constant = 0.0
        if sender.value < 0.11 {
            self.currentTimeTopConstraint?.constant = 15.0
        } else if sender.value > 0.87 {
            self.timeRemainingTopConstraint?.constant = 15.0
        }
        self.view.layoutIfNeeded()
        if !self._nowPlaying {
            self.albumArtTopConstraint?.constant = self.maximumArtConstraints
        } else {
            self.albumArtLeadingConstraint?.constant  =  self.artPlayingConstraints
            self.albumArtTrailingConstraint?.constant = -self.artPlayingConstraints
        }
        self.currentTimeTopConstraint?.constant = 0.0
        self.timeRemainingTopConstraint?.constant = 0.0
        UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 1.0, options: .curveEaseInOut, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
        self.delegate?.scrubTrack(percentage: Double(sender.value))
        self._currentlyScrubbing = false
    }
    
    @IBAction func scrubBarValueChanged(sender: UISlider) {
        if sender.value < 0.11 && self._currentScrubBarValue >= 0.11 {
            self.currentTimeTopConstraint?.constant = self.timeMovedDownValue
            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: .curveEaseInOut, animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)
        } else if sender.value > 0.87 && self._currentScrubBarValue <= 0.87 {
            self.timeRemainingTopConstraint?.constant = self.timeMovedDownValue
            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: .curveEaseInOut, animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)
        } else if (sender.value >= 0.11 && sender.value <= 0.87) && (self._currentScrubBarValue < 0.11 || self._currentScrubBarValue > 0.87) {
            self.currentTimeTopConstraint?.constant = -12.0
            self.timeRemainingTopConstraint?.constant = -12.0
            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: .curveEaseInOut, animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)
        }
        self.updateScrubBar(seconds: self._duration * Double(sender.value), updateBar: false)
        self._currentScrubBarValue = sender.value
    }
}
