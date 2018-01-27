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
    @IBOutlet weak var playPauseImage: UIImageView?
    @IBOutlet weak var albumArtImage:  UIImageView?
    @IBOutlet weak var controlOverlay: UIView?
    
    var theme: Theme = .dark

    override func awakeFromNib() {
        super.awakeFromNib()
        self.stop()
        self.separatorInset = UIEdgeInsets(top: 0.0, left: 44.0, bottom: 0.0, right: 0.0)
        // Initialization code
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
                if self.theme == .dark {
                    self.titleLabel?.textColor = UIColor(white: 1.0, alpha: 1.0)
                    self.artistLabel?.textColor = UIColor(white: 1.0, alpha: 1.0)
                } else {
                    self.titleLabel?.textColor = UIColor(white: 0.0, alpha: 1.0)
                    self.artistLabel?.textColor = UIColor(white: 0.0, alpha: 1.0)
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
    }
    
    func stop() {
        self.controlOverlay?.isHidden = true
        self.playPauseImage?.image = nil
    }
    
    func play() {
        self.playPauseImage?.image = #imageLiteral(resourceName: "play_table")
        self.controlOverlay?.isHidden = false
    }
    
    func pause() {
        self.playPauseImage?.image = #imageLiteral(resourceName: "pause_table")
        self.controlOverlay?.isHidden = false
    }
}
