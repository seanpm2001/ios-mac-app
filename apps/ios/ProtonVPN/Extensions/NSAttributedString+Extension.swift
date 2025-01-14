//
//  NSAttributedString+Extension.swift
//  ProtonVPN - Created on 01.07.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import UIKit
import vpncore

extension NSAttributedString {
    
    static func concatenate(_ strings: NSAttributedString...) -> NSAttributedString {
        let mutableAttributedString = NSMutableAttributedString()
        strings.forEach { mutableAttributedString.append($0) }
        return mutableAttributedString
    }

    static func imageAttachment(named name: String, size: CGSize? = nil) -> NSAttributedString? {
        guard let image = UIImage(named: name.lowercased()) else {
            log.debug("Could not obtain image named for text attachment", category: .app)
            return nil
        }
        return imageAttachment(image: image, size: size)
    }
    
    static func imageAttachment(image: UIImage, baselineOffset: Int? = nil, size: CGSize? = nil) -> NSAttributedString {
        let attachment = NSTextAttachment()
        if let size = size {
            attachment.bounds = CGRect(origin: .zero, size: size)
        }

        attachment.image = image
        let string = NSMutableAttributedString(attachment: attachment)
        if let baselineOffset = baselineOffset {
            // swiftlint:disable:next legacy_constructor
            string.addAttribute(NSAttributedString.Key.baselineOffset, value: baselineOffset, range: NSMakeRange(0, string.length))
        }
        return string
    }
}
