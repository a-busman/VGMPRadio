//
//  Util.swift
//  VGMPRadio
//
//  Created by Alex Busman on 1/14/18.
//  Copyright © 2018 Alex Busman. All rights reserved.
//

import UIKit
import AVFoundation
import CoreData

enum Theme: Int {
    case light
    case dark
}

class Util {
    class var uiColor: UIColor {
        get {
            return UIColor(white: 0.0, alpha: 0.75)
        }
    }
    class func getManagedContext() -> NSManagedObjectContext? {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return nil
        }
        return appDelegate.persistentContainer.viewContext
    }
    
    class func deleteAllData(entity: String) -> NSPersistentStoreResult?? {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
        let request = NSBatchDeleteRequest(fetchRequest: fetch)
        let result = try? Util.getManagedContext()?.execute(request)
        return result
    }
}

extension UIImage {
    func image(with size:CGSize) -> UIImage?
    {
        var scaledImageRect = CGRect.zero;
        let originalSize = self.size
        let aspectWidth:CGFloat = size.width / originalSize.width;
        let aspectHeight:CGFloat = size.height / originalSize.height;
        let aspectRatio:CGFloat = max(aspectWidth, aspectHeight);
        
        scaledImageRect.size.width = originalSize.width * aspectRatio;
        scaledImageRect.size.height = originalSize.height * aspectRatio;
        scaledImageRect.origin.x = (size.width - scaledImageRect.size.width) / 2.0;
        scaledImageRect.origin.y = (size.height - scaledImageRect.size.height) / 2.0;
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0);
        
        self.draw(in: scaledImageRect);
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return scaledImage;
    }
    
    func setBrightness(with brightness: CGFloat) -> UIImage?
    {
        guard let aCGImage = self.cgImage,
              let brightnessFilter = CIFilter(name: "CIColorControls") else {
            return nil
        }
        
        let context = CIContext(options: nil)
        let aCIImage = CIImage(cgImage: aCGImage)
        brightnessFilter.setValue(aCIImage, forKey: "inputImage")
        brightnessFilter.setValue(brightness, forKey: "inputBrightness")
        if let outputImage = brightnessFilter.outputImage,
           let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgimg)
        } else {
            return nil
        }
    }
    
    func setSaturation(with saturation: CGFloat) -> UIImage?
    {
        guard let aCGImage = self.cgImage,
              let saturationFilter = CIFilter(name: "CIColorControls") else {
                return nil
        }
        
        let context = CIContext(options: nil)
        let aCIImage = CIImage(cgImage: aCGImage)
        saturationFilter.setValue(aCIImage, forKey: "inputImage")
        saturationFilter.setValue(saturation, forKey: "inputSaturation")
        if let outputImage = saturationFilter.outputImage,
            let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgimg)
        } else {
            return nil
        }
    }
    
    func invertColors() -> UIImage? {
        guard let filter = CIFilter(name: "CIColorInvert") else {
            return nil
        }
        filter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        if let outputImage = filter.outputImage {
            return UIImage(ciImage: outputImage)
        } else {
            return nil
        }
    }
    
    func flipHorizontal() -> UIImage? {
        if let cgImage = self.cgImage {
            return UIImage(cgImage: cgImage, scale: 1.0, orientation: .upMirrored)
        } else {
            return nil
        }
    }
    
    class func circle(diameter: CGFloat, fillColor: UIColor, strokeColor: UIColor? = nil, offset: CGPoint? = nil) -> UIImage {
        var x: CGFloat = 0.0
        var y: CGFloat = 0.0
        if let _offset = offset {
            x = _offset.x
            y = _offset.y
        }
        UIGraphicsBeginImageContextWithOptions(CGSize(width: diameter + x, height: diameter + y), false, 0)
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.saveGState()
        let rect = CGRect(x: x, y: y, width: diameter, height: diameter)
        ctx.setFillColor(fillColor.cgColor)
        ctx.fillEllipse(in: rect)
        if strokeColor != nil {
            ctx.setStrokeColor(strokeColor!.cgColor)
            ctx.setLineWidth(3.0)
            ctx.strokeEllipse(in: rect)
        }
        ctx.restoreGState()
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return img
    }
}

extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }
}
