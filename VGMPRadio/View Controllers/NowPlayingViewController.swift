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
    func tapped()
    func shuffleToggled()
    func repeatToggled()
    func seekForward(begin: Bool)
    func seekBackward(begin: Bool)
    func favorite()
    func dislike()
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
    
    @IBOutlet weak var shuffleLabel: UILabel?
    @IBOutlet weak var shuffleImage: UIImageView?
    @IBOutlet weak var shuffleView:  UIView?
    
    @IBOutlet weak var repeatLabel: UILabel?
    @IBOutlet weak var repeatImage: UIImageView?
    @IBOutlet weak var repeatView:  UIView?
    
    @IBOutlet weak var titleMarquee: MarqueeLabel?
    @IBOutlet weak var gameMarquee:  MarqueeLabel?
    
    @IBOutlet weak var thumbsUpButton:   UIButton?
    @IBOutlet weak var thumbsDownButton: UIButton?
    
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
    
    @IBOutlet weak var thumbsDownTrailingConstraint: NSLayoutConstraint?
    @IBOutlet weak var prevTrackTrailingConstraint:  NSLayoutConstraint?
    @IBOutlet weak var nextTrackLeadingConstraint:   NSLayoutConstraint?
    @IBOutlet weak var thumbsUpLeadingConstraint:    NSLayoutConstraint?
    @IBOutlet weak var volumeWidthConstraint:        NSLayoutConstraint?
    
    @IBOutlet weak var handleView: UIView?
    
    @IBOutlet weak var ipadBlurView: UIVisualEffectView?
    
    var handleShape: CAShapeLayer?
        
    var playSmallImage:  UIImage? = #imageLiteral(resourceName: "play")
    var nextSmallImage:  UIImage? = #imageLiteral(resourceName: "FF")
    var pauseSmallImage: UIImage? = #imageLiteral(resourceName: "pause")
    
    var playImage:  UIImage? = #imageLiteral(resourceName: "play")
    var pauseImage: UIImage? = #imageLiteral(resourceName: "pause")
    var nextImage:  UIImage? = #imageLiteral(resourceName: "FF")
    var prevImage:  UIImage? = #imageLiteral(resourceName: "RW")
    
    var volUpImage:   UIImage? = #imageLiteral(resourceName: "volume_up")
    var volDownImage: UIImage? = #imageLiteral(resourceName: "volume_down")
    
    var thumbsUpImage: UIImage? = #imageLiteral(resourceName: "thumbs-up").invertColors()
    var thumbsUpFilledImage: UIImage? = #imageLiteral(resourceName: "thumbs-up-filled").invertColors()
    var thumbsDownImage: UIImage? = #imageLiteral(resourceName: "thumb-down").invertColors()
    var thumbsDownFilledImage: UIImage? = #imageLiteral(resourceName: "thumbs-down-filled").invertColors()
    
    let scrubBarBottomDefault:        CGFloat =  -27.0
    let scrubBarBottomFocused:        CGFloat =  -15.0
    let minimumArtLeadingConstraint:  CGFloat =   20.0
    var minimumArtTrailingConstraint: CGFloat = -305.0
    let minimumArtTopConstraint:      CGFloat =    5.0
    let maximumArtConstraints:        CGFloat =   63.0
    let scrubPlayingConstraints:      CGFloat =   50.0
    
    var buttonSpacing: CGFloat = 25.0
    
    let artPlayingConstraints: CGFloat = 32.0

    let minimumBackgroundArtConstraints: CGFloat = 0.0
    let maximumBackgroundArtConstraints: CGFloat = 0.0
    
    let hiddenBackgroundArtConstraints: CGFloat = -50.0
    
    let timeMovedDownValue: CGFloat = 0.0
    private var _duration: Double = 0.0
    
    var isSeeking: Bool = false
    var shouldResume: Bool = false
    var seekTimer: Timer?
    
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
                    self.albumArtTopConstraint?.constant = self.artPlayingConstraints
                    if self.view.frame.width == 320.0 {
                        self.albumArtLeadingConstraint?.constant  =  self.artPlayingConstraints + 20.0
                        self.albumArtTrailingConstraint?.constant = -(self.artPlayingConstraints + 20.0)
                    } else {
                        self.albumArtLeadingConstraint?.constant  =  self.artPlayingConstraints
                        self.albumArtTrailingConstraint?.constant = -self.artPlayingConstraints
                    }
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
                    if self.view.frame.width == 320.0 {
                        self.albumArtTopConstraint?.constant = self.artPlayingConstraints
                    } else {
                        self.albumArtTopConstraint?.constant =  self.maximumArtConstraints
                    }
                    self.albumArtLeadingConstraint?.constant  =  self.maximumArtConstraints
                    self.albumArtTrailingConstraint?.constant = -self.maximumArtConstraints
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
                self.ipadBlurView?.effect = UIBlurEffect(style: .light)
                self.titleSmallLabel?.textColor = .black
                self.titleMarquee?.textColor = .black
                self.gameMarquee?.textColor = .black
                self.currentTimeLabel?.textColor = .darkGray
                self.timeRemainingLabel?.textColor = .darkGray
                self.playSmallImage = self.playSmallImage?.invertColors()
                self.nextSmallImage = self.nextSmallImage?.invertColors()
                self.pauseSmallImage = self.pauseSmallImage?.invertColors()
                self.playImage = self.playImage?.invertColors()
                self.pauseImage = self.pauseImage?.invertColors()
                self.nextImage = self.nextImage?.invertColors()
                self.prevImage = self.prevImage?.invertColors()
                self.volUpImage = self.volUpImage?.invertColors()
                self.volDownImage = self.volDownImage?.invertColors()
                self.thumbsUpImage = #imageLiteral(resourceName: "thumbs-up")
                self.thumbsUpFilledImage = #imageLiteral(resourceName: "thumbs-up-filled")
                self.thumbsDownImage = #imageLiteral(resourceName: "thumb-down")
                self.thumbsDownFilledImage = #imageLiteral(resourceName: "thumbs-down-filled")
            } else {
                self.visualEffectView?.effect = UIBlurEffect(style: .dark)
                self.ipadBlurView?.effect = UIBlurEffect(style: .dark)
                self.titleSmallLabel?.textColor = .white
                self.titleMarquee?.textColor = .white
                self.gameMarquee?.textColor = .white
                self.currentTimeLabel?.textColor = .white
                self.timeRemainingLabel?.textColor = .white
                self.playSmallImage = #imageLiteral(resourceName: "play")
                self.nextSmallImage = #imageLiteral(resourceName: "FF")
                self.pauseSmallImage = #imageLiteral(resourceName: "pause")
                self.playImage = #imageLiteral(resourceName: "play")
                self.pauseImage = #imageLiteral(resourceName: "pause")
                self.nextImage = #imageLiteral(resourceName: "FF")
                self.prevImage = #imageLiteral(resourceName: "RW")
                self.volUpImage = #imageLiteral(resourceName: "volume_up")
                self.volDownImage = #imageLiteral(resourceName: "volume_down")
                self.thumbsUpImage = #imageLiteral(resourceName: "thumbs-up").invertColors()
                self.thumbsUpFilledImage = #imageLiteral(resourceName: "thumbs-up-filled").invertColors()
                self.thumbsDownImage = #imageLiteral(resourceName: "thumb-down").invertColors()
                self.thumbsDownFilledImage = #imageLiteral(resourceName: "thumbs-down-filled").invertColors()
            }
            let fillColor = self._currentTheme == .light ? UIColor.darkGray : UIColor.white
            let activeImage = UIImage.circle(diameter: 31.0, fillColor: fillColor)
            self.scrubBarSlider?.setThumbImage(UIImage.circle(diameter: 6.0, fillColor: fillColor, offset: CGPoint(x: 0.5, y: 0.5)), for: .normal)
            self.scrubBarSlider?.setThumbImage(activeImage, for: .highlighted)
            self.scrubBarSlider?.setThumbImage(activeImage, for: .selected)
            self.scrubBarSlider?.setThumbImage(activeImage, for: .focused)
            self.scrubBarSlider?.minimumTrackTintColor = self._currentTheme == .light ? UIColor.darkGray : UIColor.white
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
            
            self.thumbsUpButton?.setImage(self.thumbsUpImage, for: .normal)
            self.thumbsUpButton?.setImage(self.thumbsUpFilledImage, for: .selected)
            self.thumbsDownButton?.setImage(self.thumbsDownImage, for: .normal)
            self.thumbsDownButton?.setImage(self.thumbsDownFilledImage, for: .selected)
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
        self.splitViewController?.preferredDisplayMode = .allVisible
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if self._firstLoad {
            self.addDragHandle()
            if self.view.frame.width == 320.0 {
                self.thumbsDownTrailingConstraint?.constant = -15.0
                self.prevTrackTrailingConstraint?.constant  = -15.0
                self.nextTrackLeadingConstraint?.constant   =  15.0
                self.thumbsUpLeadingConstraint?.constant    =  15.0
                self.volumeWidthConstraint?.constant        = 220.0
            }
            self.minimumArtTrailingConstraint = -(self.view.frame.width - 70.0)
            self.albumArtTrailingConstraint?.constant = self.minimumArtTrailingConstraint
            self.albumArtImageView?.layer.borderColor = UIColor(white: 0.8, alpha: 1.0).cgColor
            self._firstLoad = false
            self.fakeVolumeSlider?.setThumbImage(UIImage(), for: .normal)
            self.fakeVolumeSlider?.setThumbImage(UIImage(), for: .disabled)
            self.fakeVolumeSlider?.setValue(0.0, animated: false)
            self.fakeVolumeSlider?.isEnabled = false
            let fillColor = self._currentTheme == .light ? UIColor.darkGray : UIColor.white
            let activeImage = UIImage.circle(diameter: 31.0, fillColor: fillColor)
            self.scrubBarSlider?.setThumbImage(UIImage.circle(diameter: 6.0, fillColor: fillColor, offset: CGPoint(x: 0.5, y: 0.5)), for: .normal)
            self.scrubBarSlider?.setThumbImage(activeImage, for: .highlighted)
            self.scrubBarSlider?.setThumbImage(activeImage, for: .selected)
            self.scrubBarSlider?.setThumbImage(activeImage, for: .focused)
            self.scrubBarWidthConstraint?.constant = self.view.frame.width - self.maximumArtConstraints
            self.view.layoutIfNeeded()
        }
    }
    
    func addDragHandle() {
        if let handleView = self.handleView {
            self.handleShape = CAShapeLayer()
            
            let path = UIBezierPath()
            
            path.move(to: CGPoint(x: 0.0, y: handleView.frame.height / 2.0))
            path.addLine(to: CGPoint(x: handleView.frame.width / 2.0, y: handleView.frame.height / 2.0))
            path.move(to: CGPoint(x: handleView.frame.width / 2.0, y: handleView.frame.height / 2.0))
            path.addLine(to: CGPoint(x: handleView.frame.width, y: handleView.frame.height / 2.0))
            self.handleShape?.path = path.cgPath
            self.handleShape?.fillColor = UIColor.gray.cgColor
            self.handleShape?.strokeColor = UIColor.gray.cgColor
            self.handleShape?.lineWidth = 5.0
            self.handleShape?.lineCap = kCALineCapRound
            self.handleShape?.lineJoin = kCALineJoinMiter
            handleView.layer.addSublayer(self.handleShape!)
        }
    }
    
    func bendDragHandle() {
        if let handleShape = self.handleShape,
           let handleView = self.handleView {
            let endPath = UIBezierPath()
            endPath.move(to: CGPoint(x: 0.0, y: 0.0))
            endPath.addLine(to: CGPoint(x: handleView.frame.width / 2.0, y: handleView.frame.height))
            endPath.move(to: CGPoint(x: handleView.frame.width / 2.0, y: handleView.frame.height))
            endPath.addLine(to: CGPoint(x: handleView.frame.width, y: 0.0))
            
            let animation = CABasicAnimation(keyPath: "path")
            animation.duration = 0.25
            animation.fromValue = handleShape.path
            animation.toValue = endPath.cgPath
            animation.timingFunction = CAMediaTimingFunction(name: "easeInEaseOut")
            handleShape.add(animation, forKey: "path")
            handleShape.path = endPath.cgPath
        }
    }
    
    func unbendDragHandle() {
        if let handleShape = self.handleShape,
            let handleView = self.handleView {
            let path = UIBezierPath()
            
            path.move(to: CGPoint(x: 0.0, y: handleView.frame.height / 2.0))
            path.addLine(to: CGPoint(x: handleView.frame.width / 2.0, y: handleView.frame.height / 2.0))
            path.move(to: CGPoint(x: handleView.frame.width / 2.0, y: handleView.frame.height / 2.0))
            path.addLine(to: CGPoint(x: handleView.frame.width, y: handleView.frame.height / 2.0))
            let animation = CABasicAnimation(keyPath: "path")
            animation.duration = 0.25
            animation.fromValue = handleShape.path
            animation.toValue = path.cgPath
            animation.timingFunction = CAMediaTimingFunction(name: "easeInEaseOut")
            handleShape.add(animation, forKey: "path")
            handleShape.path = path.cgPath
        }
    }
    func updateViewOnTap(maximized: Bool, duration: TimeInterval) {
        if maximized {
            if !self.isMaximized {
                self.titleMarquee?.restartLabel()
                self.gameMarquee?.restartLabel()
            }
            if self.volumeViewPlaceholder != nil {
                if self.volumeView.superview == nil {
                    self.volumeView = MPVolumeView(frame: self.volumeViewPlaceholder!.bounds)
                    self.volumeView.showsRouteButton = false
                }
                if self._currentTheme == .light {
                    self.volumeView.tintColor = .darkGray
                } else {
                    self.volumeView.tintColor = .white
                }
                if self.volumeView.superview == nil {
                    self.volumeViewPlaceholder?.addSubview(self.volumeView)
                }
            }
            if self.airPlayViewPlaceholder != nil {
                if self.airPlayView.superview == nil {
                    self.airPlayView = MPVolumeView(frame: self.airPlayViewPlaceholder!.bounds)
                    self.airPlayView.showsVolumeSlider = false
                    self.airPlayView.setRouteButtonImage(#imageLiteral(resourceName: "airplay_selected"), for: .selected)
                }
                if self._currentTheme == .light {
                    self.airPlayView.setRouteButtonImage(#imageLiteral(resourceName: "airplay"), for: .normal)
                } else {
                    let invertedImage = #imageLiteral(resourceName: "airplay").invertColors()
                    self.airPlayView.setRouteButtonImage(invertedImage?.image(with: #imageLiteral(resourceName: "airplay").size), for: .normal)
                }
                self.airPlayView.tintColor = .darkGray
                if self.airPlayView.superview == nil {
                    self.airPlayViewPlaceholder?.addSubview(self.airPlayView)
                }
            }
            if self._nowPlaying {
                self.albumArtTopConstraint?.constant      =  self.artPlayingConstraints
                if self.view.frame.width == 320.0 {
                    self.albumArtLeadingConstraint?.constant  =  self.artPlayingConstraints + 20.0
                    self.albumArtTrailingConstraint?.constant = -(self.artPlayingConstraints + 20.0)
                } else {
                    self.albumArtLeadingConstraint?.constant  =  self.artPlayingConstraints
                    self.albumArtTrailingConstraint?.constant = -self.artPlayingConstraints
                }
            } else {
                if self.view.frame.width == 320.0 {
                    self.albumArtTopConstraint?.constant = self.artPlayingConstraints
                } else {
                    self.albumArtTopConstraint?.constant =  self.maximumArtConstraints
                }
                self.albumArtLeadingConstraint?.constant  =  self.maximumArtConstraints
                self.albumArtTrailingConstraint?.constant = -self.maximumArtConstraints
            }
            UIView.animate(withDuration: duration * 0.3) {
                self.playPauseSmallView?.alpha = 0.0
                self.nextTrackSmallView?.alpha = 0.0
                self.titleSmallLabel?.alpha = 0.0
                self.handleView?.alpha = 1.0
                if self._nowPlaying {
                    self.backgroundImageView?.alpha = 1.0
                }
            }
            self.bendDragHandle()
            UIViewPropertyAnimator(duration: duration, dampingRatio: 1.0, animations: {
                self.albumArtImageView?.layer.cornerRadius = 8.0
            }).startAnimation()
        } else {
            self.albumArtTopConstraint?.constant      = self.minimumArtTopConstraint
            self.albumArtLeadingConstraint?.constant  = self.minimumArtLeadingConstraint
            self.albumArtTrailingConstraint?.constant = self.minimumArtTrailingConstraint
            
            self.handleView?.alpha = 0.0
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
        self.isMaximized = maximized
        
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
        if self.volumeViewPlaceholder != nil {
            if self.volumeView.superview == nil {
                self.volumeView = MPVolumeView(frame: self.volumeViewPlaceholder!.bounds)
                self.volumeView.showsRouteButton = false
                if self._currentTheme == .light {
                    self.volumeView.tintColor = .darkGray
                } else {
                    self.volumeView.tintColor = .white
                }
                self.volumeViewPlaceholder?.addSubview(self.volumeView)
            }
        }
        if self.airPlayViewPlaceholder != nil {
            if self.airPlayView.superview == nil {
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
        }
        
        let maxConstraint = self._nowPlaying ? self.artPlayingConstraints : self.maximumArtConstraints
        if self.view.frame.width == 320.0 {
            self.albumArtTopConstraint?.constant = ((self.artPlayingConstraints - self.minimumArtTopConstraint) * percentage) + self.minimumArtTopConstraint
            let newMax = self._nowPlaying ? self.artPlayingConstraints + 20.0 : self.maximumArtConstraints
            self.albumArtLeadingConstraint?.constant = ((newMax - self.minimumArtLeadingConstraint) * percentage) + self.minimumArtLeadingConstraint
            self.albumArtTrailingConstraint?.constant = self.minimumArtTrailingConstraint + ((-self.minimumArtTrailingConstraint - newMax) * percentage)
        } else {
            self.albumArtTopConstraint?.constant = ((maxConstraint - self.minimumArtTopConstraint) * percentage) + self.minimumArtTopConstraint
            self.albumArtLeadingConstraint?.constant = ((maxConstraint - self.minimumArtLeadingConstraint) * percentage) + self.minimumArtLeadingConstraint
            self.albumArtTrailingConstraint?.constant = self.minimumArtTrailingConstraint + ((-self.minimumArtTrailingConstraint - maxConstraint) * percentage)
        }

        self.view.layoutIfNeeded()
        
        self.playPauseSmallView?.alpha = max(1.0 - percentage * 4.0, 0.0)
        self.nextTrackSmallView?.alpha = max(1.0 - percentage * 4.0, 0.0)
        self.titleSmallLabel?.alpha = max(1.0 - percentage * 4.0, 0.0)
        self.handleView?.alpha = max(percentage * 2.0 - 1.0, 0.0)
        if self._nowPlaying {
            self.backgroundImageView?.alpha = percentage
        }
        self.view.backgroundColor = UIColor(white: 1.0, alpha: percentage)
        self.albumArtImageView?.layer.cornerRadius = 3.0 * percentage + 5.0

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
    
    func shuffle(enabled: Bool) {
        if enabled {
            UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseInOut, animations: {
                self.shuffleView?.backgroundColor = Util.uiDarkColor
                self.shuffleLabel?.textColor = Util.uiLightColor
                self.shuffleImage?.image = #imageLiteral(resourceName: "shuffle").invertColors()
            }, completion: nil)
        } else {
            UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseInOut, animations: {
                self.shuffleView?.backgroundColor = Util.uiLightColor
                self.shuffleLabel?.textColor = Util.uiDarkColor
                self.shuffleImage?.image = #imageLiteral(resourceName: "shuffle")
            }, completion: nil)
        }
    }
    
    func `repeat`(enabled: Bool, one: Bool) {
        if enabled {
            UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseInOut, animations: {
                self.repeatView?.backgroundColor = Util.uiDarkColor
                self.repeatLabel?.textColor = Util.uiLightColor
                if one {
                    self.repeatImage?.image = #imageLiteral(resourceName: "repeat_1").invertColors()
                } else {
                    self.repeatImage?.image = #imageLiteral(resourceName: "repeat").invertColors()
                }
            }, completion: nil)
        } else {
            UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseInOut, animations: {
                self.repeatView?.backgroundColor = Util.uiLightColor
                self.repeatLabel?.textColor = Util.uiDarkColor
                self.repeatImage?.image = #imageLiteral(resourceName: "repeat")
            }, completion: nil)
        }
    }
    
    func like(favorite: Bool, dislike: Bool) {
        if favorite {
            self.thumbsDownButton?.isSelected = false
            self.thumbsUpButton?.isSelected = true
        } else if dislike {
            self.thumbsDownButton?.isSelected = true
            self.thumbsUpButton?.isSelected = false
        } else {
            self.thumbsDownButton?.isSelected = false
            self.thumbsUpButton?.isSelected = false
        }
    }

    @IBAction func mediaButtonTouchUpInside(sender: UIButton) {
        if sender.tag == 0 {
            self.delegate?.playPauseTrack()
        } else if sender.tag == 1 || sender.tag == 3 {
            if !self.isSeeking {
                self.delegate?.nextTrack()
            }
            self.seekTimer?.invalidate()
            if self.isSeeking {
                self.isSeeking = false
                self.nowPlaying = self.shouldResume
                self.delegate?.seekForward(begin: false)
            }
        } else if sender.tag == 2 {
            self.delegate?.playPauseTrack()
        } else if sender.tag == 4 {
            if !self.isSeeking {
                self.delegate?.previousTrack()
            }
            self.seekTimer?.invalidate()
            if self.isSeeking {
                self.isSeeking = false
                self.nowPlaying = self.shouldResume
                self.delegate?.seekBackward(begin: false)
            }
        } else if sender.tag == 5 {
            self.delegate?.favorite()
        } else if sender.tag == 6 {
            self.delegate?.dislike()
        }
        UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseInOut, animations: {
            sender.transform = CGAffineTransform.identity
            sender.superview?.backgroundColor = UIColor(white: 0.9, alpha: 0.0)
        }, completion: nil)
    }
    
    @IBAction func mediaButtonTouchDown(sender: UIButton) {
        UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseInOut, animations: {
            sender.transform = CGAffineTransform.identity.scaledBy(x: 0.8, y: 0.8)
            sender.superview?.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        }, completion: nil)
        if sender.tag == 1 || sender.tag == 3 {
            self.shouldResume = self._nowPlaying
            self.seekTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { (timer) in
                self.isSeeking = true
                self.nowPlaying = false
                self.delegate?.seekForward(begin: true)
            })
        } else if sender.tag == 4 {
            self.shouldResume = self._nowPlaying
            self.seekTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { (timer) in
                self.isSeeking = true
                self.nowPlaying = false
                self.delegate?.seekBackward(begin: true)
            })
        }
    }
    
    @IBAction func mediaButtonTouchDragExit(sender: UIButton) {
        UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseInOut, animations: {
            sender.transform = CGAffineTransform.identity
            sender.superview?.backgroundColor = UIColor(white: 0.9, alpha: 0.0)
        }, completion: nil)
        if sender.tag == 1 || sender.tag == 3 {
            self.seekTimer?.invalidate()
            if self.isSeeking {
                self.isSeeking = false
                self.nowPlaying = self.shouldResume
                self.delegate?.seekForward(begin: false)
            }
        } else if sender.tag == 4 {
            self.seekTimer?.invalidate()
            if self.isSeeking {
                self.isSeeking = false
                self.nowPlaying = self.shouldResume
                self.delegate?.seekBackward(begin: false)
            }
        }
    }
    
    @IBAction func scrubBarTouchDown(sender: UISlider) {
        let fillColor = self._currentTheme == .light ? UIColor.darkGray : UIColor.white
        self.scrubBarSlider?.setThumbImage(UIImage.circle(diameter: 31.0, fillColor: fillColor), for: .normal)
        self.scrubBarBottomConstraint?.constant = self.scrubBarBottomFocused
        self.currentTimeTopConstraint?.constant = -12.0
        self.timeRemainingTopConstraint?.constant = -12.0
        self.view.layoutIfNeeded()
        if !self._nowPlaying {
            self.albumArtTopConstraint?.constant = self.artPlayingConstraints
        } else {
            if self.view.frame.width == 320.0 {
                self.albumArtLeadingConstraint?.constant  =  self.scrubPlayingConstraints + 10.0
                self.albumArtTrailingConstraint?.constant = -(self.scrubPlayingConstraints + 10.0)
            } else {
                self.albumArtLeadingConstraint?.constant  =  self.scrubPlayingConstraints
                self.albumArtTrailingConstraint?.constant = -self.scrubPlayingConstraints
            }
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
        let fillColor = self._currentTheme == .light ? UIColor.darkGray : UIColor.white
        self.scrubBarSlider?.setThumbImage(UIImage.circle(diameter: 6.0, fillColor: fillColor, offset: CGPoint(x: 0.5, y: 0.5)), for: .normal)
        self.scrubBarBottomConstraint?.constant = self.scrubBarBottomDefault
        let device = UIDevice.current.userInterfaceIdiom
        if device != .pad {
            self.currentTimeTopConstraint?.constant = 0.0
            self.timeRemainingTopConstraint?.constant = 0.0
            if sender.value < 0.11 {
                self.currentTimeTopConstraint?.constant = 15.0
            } else if sender.value > 0.87 {
                self.timeRemainingTopConstraint?.constant = 15.0
            }
            self.view.layoutIfNeeded()
        }
        if !self._nowPlaying {
            if self.view.frame.width == 320.0 {
                self.albumArtTopConstraint?.constant = self.artPlayingConstraints
            } else {
                self.albumArtTopConstraint?.constant = self.maximumArtConstraints
            }
        } else {
            if self.view.frame.width == 320.0 {
                self.albumArtLeadingConstraint?.constant  =  self.artPlayingConstraints + 20.0
                self.albumArtTrailingConstraint?.constant = -(self.artPlayingConstraints + 20.0)
            } else {
                self.albumArtLeadingConstraint?.constant  =  self.artPlayingConstraints
                self.albumArtTrailingConstraint?.constant = -self.artPlayingConstraints
            }
        }
        if device == .pad {
            self.currentTimeTopConstraint?.constant = -12.0
            self.timeRemainingTopConstraint?.constant = -12.0
        } else {
            self.currentTimeTopConstraint?.constant = 0.0
            self.timeRemainingTopConstraint?.constant = 0.0
        }
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
    
    @IBAction func nowPlayingTapped(sender: UITapGestureRecognizer) {
        self.delegate?.tapped()
    }
    
    @IBAction func shuffleTapped(sender: UITapGestureRecognizer) {
        self.delegate?.shuffleToggled()
    }
    
    @IBAction func repeatTapped(sender: UITapGestureRecognizer) {
        self.delegate?.repeatToggled()
    }
}
