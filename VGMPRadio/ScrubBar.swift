//
//  ScrubBar.swift
//  VGMPRadio
//
//  Created by Alex Busman on 1/26/18.
//  Copyright © 2018 Alex Busman. All rights reserved.
//

import UIKit

class ScrubBar: UISlider {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        var newBounds = super.trackRect(forBounds: bounds)
        newBounds.size.height = 3
        return newBounds
    }
}
