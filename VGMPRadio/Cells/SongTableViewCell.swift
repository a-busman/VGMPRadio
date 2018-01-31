//
//  SongTableViewCell.swift
//  VGMPRadio
//
//  Created by Alex Busman on 1/17/18.
//  Copyright © 2018 Alex Busman. All rights reserved.
//

import UIKit

class SongTableViewCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel:     UILabel?
    @IBOutlet weak var artistLabel:    UILabel?
    @IBOutlet weak var albumArtImage:  UIImageView?
    @IBOutlet weak var controlOverlay: UIView?
    @IBOutlet weak var favoritesImage: UIImageView?
    
    var firstBar:  CAShapeLayer?
    var secondBar: CAShapeLayer?
    var thirdBar:  CAShapeLayer?
    var fourthBar: CAShapeLayer?
    
    var firstBase:  CAShapeLayer?
    var secondBase: CAShapeLayer?
    var thirdBase:  CAShapeLayer?
    var fourthBase: CAShapeLayer?
    
    var theme: Theme = .dark
    
    var disliked: Bool = false

    override func awakeFromNib() {
        super.awakeFromNib()
        self.stop()
        self.separatorInset = UIEdgeInsets(top: 0.0, left: 44.0, bottom: 0.0, right: 0.0)
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        if highlighted {
            UIView.animate(withDuration: 0.1, animations: {
                if self.theme == .dark {
                    self.titleLabel?.textColor = UIColor(white: 1.0, alpha: 0.5)
                    self.artistLabel?.textColor = UIColor(white: 1.0, alpha: 0.5)
                } else {
                    self.titleLabel?.textColor = UIColor(white: 0.0, alpha: 0.5)
                    self.artistLabel?.textColor = UIColor(white: 0.0, alpha: 0.5)
                }
                
            })
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                if !self.disliked {
                    if self.theme == .dark {
                        self.titleLabel?.textColor = UIColor(white: 1.0, alpha: 1.0)
                        self.artistLabel?.textColor = UIColor(white: 1.0, alpha: 1.0)
                    } else {
                        self.titleLabel?.textColor = UIColor(white: 0.0, alpha: 1.0)
                        self.artistLabel?.textColor = UIColor(white: 0.0, alpha: 1.0)
                    }
                } else {
                    self.titleLabel?.textColor = UIColor(white: 0.5, alpha: 1.0)
                    self.artistLabel?.textColor = UIColor(white: 0.5, alpha: 1.0)
                }
            })
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    override func prepareForReuse() {
        self.stop()
        self.favoritesImage?.image = nil
        self.disliked = false
    }
    
    func stop() {
        self.controlOverlay?.isHidden = true
    }
    
    func play() {
        self.controlOverlay?.isHidden = false
        self.generateShapes(withAnimation: true)
    }
    
    func pause() {
        self.generateShapes(withAnimation: false)
        self.firstBar?.removeAllAnimations()
        self.secondBar?.removeAllAnimations()
        self.thirdBar?.removeAllAnimations()
        self.fourthBar?.removeAllAnimations()
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.5)
        self.firstBar?.strokeEnd = 0.1
        self.secondBar?.strokeEnd = 0.1
        self.thirdBar?.strokeEnd = 0.1
        self.fourthBar?.strokeEnd = 0.1
        CATransaction.commit()
        self.controlOverlay?.isHidden = false
    }
    
    func setFavorite() {
        self.favoritesImage?.image = #imageLiteral(resourceName: "favorite")
    }
    
    func setDisliked() {
        self.disliked = true
        self.titleLabel?.textColor = .gray
        self.artistLabel?.textColor = .gray
    }
    
    func generateShapes(withAnimation animation: Bool) {
        guard let size = self.controlOverlay?.frame.size else {
            return
        }
        let rand1: CGFloat = CGFloat(drand48())
        let rand2: CGFloat = CGFloat(drand48())
        let rand3: CGFloat = CGFloat(drand48())
        let rand4: CGFloat = CGFloat(drand48())
        
        self.firstBar?.removeFromSuperlayer()
        self.secondBar?.removeFromSuperlayer()
        self.thirdBar?.removeFromSuperlayer()
        self.fourthBar?.removeFromSuperlayer()
        self.firstBar?.removeAllAnimations()
        self.secondBar?.removeAllAnimations()
        self.thirdBar?.removeAllAnimations()
        self.fourthBar?.removeAllAnimations()
        
        let path1 = UIBezierPath()
        let path2 = UIBezierPath()
        let path3 = UIBezierPath()
        let path4 = UIBezierPath()
        
        path1.move(to: CGPoint(x: 8.0, y: size.height - 8.0))
        path1.addLine(to: CGPoint(x: 8.0, y: 8.0))
        
        path2.move(to: CGPoint(x: 14.0, y: size.height - 8.0))
        path2.addLine(to: CGPoint(x: 14.0, y: 8.0))
        
        path3.move(to: CGPoint(x: 20.0, y: size.height - 8.0))
        path3.addLine(to: CGPoint(x: 20.0, y: 8.0))
        
        path4.move(to: CGPoint(x: 26.0, y: size.height - 8.0))
        path4.addLine(to: CGPoint(x: 26.0, y: 8.0))
        
        self.firstBar = CAShapeLayer()
        self.firstBar?.fillColor = UIColor.white.cgColor
        self.firstBar?.strokeColor = UIColor.white.cgColor
        self.firstBar?.lineWidth = 3.0
        self.firstBar?.path = path1.cgPath
        
        self.secondBar = CAShapeLayer()
        self.secondBar?.fillColor = UIColor.white.cgColor
        self.secondBar?.strokeColor = UIColor.white.cgColor
        self.secondBar?.lineWidth = 3.0
        self.secondBar?.path = path2.cgPath
        
        self.thirdBar = CAShapeLayer()
        self.thirdBar?.fillColor = UIColor.white.cgColor
        self.thirdBar?.strokeColor = UIColor.white.cgColor
        self.thirdBar?.lineWidth = 3.0
        self.thirdBar?.path = path3.cgPath
        
        self.fourthBar = CAShapeLayer()
        self.fourthBar?.fillColor = UIColor.white.cgColor
        self.fourthBar?.strokeColor = UIColor.white.cgColor
        self.fourthBar?.lineWidth = 3.0
        self.fourthBar?.path = path4.cgPath
        
        self.controlOverlay?.layer.addSublayer(self.firstBar!)
        self.controlOverlay?.layer.addSublayer(self.secondBar!)
        self.controlOverlay?.layer.addSublayer(self.thirdBar!)
        self.controlOverlay?.layer.addSublayer(self.fourthBar!)
        if animation {
            let animation1 = CABasicAnimation(keyPath: "strokeEnd")
            animation1.fromValue = 0.1
            animation1.toValue = rand1 * 0.8 + 0.2
            animation1.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
            animation1.duration = (Double(rand1) * 0.3) + 0.3
            animation1.repeatCount = .infinity
            animation1.autoreverses = true
            
            let animation2 = CABasicAnimation(keyPath: "strokeEnd")
            animation2.fromValue = 0.1
            animation2.toValue = rand2 * 0.8 + 0.2
            animation2.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
            animation2.duration = (Double(rand2) * 0.3) + 0.3
            animation2.repeatCount = .infinity
            animation2.autoreverses = true
            
            let animation3 = CABasicAnimation(keyPath: "strokeEnd")
            animation3.fromValue = 0.1
            animation3.toValue = rand3 * 0.8 + 0.2
            animation3.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
            animation3.duration = (Double(rand3) * 0.3) + 0.3
            animation3.repeatCount = .infinity
            animation3.autoreverses = true
            
            let animation4 = CABasicAnimation(keyPath: "strokeEnd")
            animation4.fromValue = 0.1
            animation4.toValue = rand4 * 0.8 + 0.2
            animation4.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
            animation4.duration = (Double(rand4) * 0.3) + 0.3
            animation4.repeatCount = .infinity
            animation4.autoreverses = true
            
            self.firstBar?.add(animation1, forKey: "firstBarAnimation")
            self.secondBar?.add(animation2, forKey: "secondBarAnimation")
            self.thirdBar?.add(animation3, forKey: "thirdBarAnimation")
            self.fourthBar?.add(animation4, forKey: "fourthBarAnimation")
        }
    }
}
