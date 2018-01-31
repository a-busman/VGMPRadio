//
//  PlayShuffleTableViewCell.swift
//  VGMPRadio
//
//  Created by Alex Busman on 1/27/18.
//  Copyright © 2018 Alex Busman. All rights reserved.
//

import UIKit

protocol PlaylistShuffleTableViewCellDelegate {
    func playTapped()
    func shuffleTapped()
}

class PlayShuffleTableViewCell: UITableViewCell {
    @IBOutlet weak var playView: UIView?
    @IBOutlet weak var shuffleView: UIView?
    
    var delegate: PlaylistShuffleTableViewCellDelegate?
    override func awakeFromNib() {
        super.awakeFromNib()
        self.playView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.playTapped)))
        self.shuffleView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.shuffleTapped)))
        // Initialization code
    }
    
    @objc func playTapped(sender: UITapGestureRecognizer) {
        self.delegate?.playTapped()
    }
    
    @objc func shuffleTapped(sender: UITapGestureRecognizer) {
        self.delegate?.shuffleTapped()
    }
}
