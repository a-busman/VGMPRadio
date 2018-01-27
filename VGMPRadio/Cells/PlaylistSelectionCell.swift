//
//  PlaylistSelectionCell.swift
//  VGMPRadio
//
//  Created by Alex Busman on 1/13/18.
//  Copyright © 2018 Alex Busman. All rights reserved.
//

import UIKit

class PlaylistSelectionCell: UICollectionViewCell {
    enum RightConstraints: CGFloat {
        case newHidden = 5.0
        case newShown  = 47.0
    }

    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var newView: UIView?
    @IBOutlet weak var rightConstraint: NSLayoutConstraint?
        
    private var _newIsHidden = false
    
    let selectionAnimationTime: TimeInterval = 0.15
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.contentView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    var newIsHidden: Bool {
        set(newValue) {
            self._newIsHidden = newValue
            if newValue {
                self.rightConstraint?.constant = RightConstraints.newHidden.rawValue
                self.setNeedsLayout()
                self.layoutIfNeeded()
                self.newView?.isHidden = true
            } else {
                self.rightConstraint?.constant = RightConstraints.newShown.rawValue
                self.setNeedsLayout()
                self.layoutIfNeeded()
                self.newView?.isHidden = false
            }
        }
        get {
            return self._newIsHidden
        }
    }
    
    func selectCell(animated: Bool, theme: Theme) {
        if animated {
            UIView.animate(withDuration: self.selectionAnimationTime, animations: {
                self.backgroundColor = .white
                self.layer.borderColor = UIColor.black.cgColor
                self.layer.borderWidth = 1.0
                self.titleLabel?.textColor = Util.uiColor
                })
        } else {
            self.backgroundColor = .white
            self.titleLabel?.textColor = Util.uiColor
            self.layer.borderColor = UIColor.black.cgColor
            self.layer.borderWidth = 1.0
        }
    }
    
    func deselectCell(animated: Bool, theme: Theme) {
        if animated {
            UIView.animate(withDuration: self.selectionAnimationTime, animations: {
                if theme == .dark {
                    self.backgroundColor = Util.uiColor
                    self.layer.borderColor = Util.uiColor.cgColor
                } else {
                    self.backgroundColor = .lightGray
                    self.layer.borderColor = UIColor.lightGray.cgColor
                }
                self.titleLabel?.textColor = .white
                self.layer.borderWidth = 0.0
            })
        } else {
            if theme == .dark {
                self.backgroundColor = Util.uiColor
                self.layer.borderColor = Util.uiColor.cgColor
            } else {
                self.backgroundColor = .lightGray
                self.layer.borderColor = UIColor.lightGray.cgColor
            }
            self.titleLabel?.textColor = .white
        }
    }
}
