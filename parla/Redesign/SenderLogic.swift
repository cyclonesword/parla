//
//  SSender.swift
//  Seneca
//
//  Created by Domenico Gabriele Aiello on 18/01/17.
//  Copyright © 2017 Domenico Aiello. All rights reserved.
//

import Foundation
import UIKit

public class PSender : Equatable {

    public var id: Int
    public var name: String
    public var avatar: PAvatar?
    public var type: SenderType
    
    init(senderId: Int, senderName: String, avatar: PAvatar?, type: SenderType) {
        self.id = senderId
        self.name = senderName
        self.avatar = avatar
        self.type = type
    }
    
    public static func == (lhs: PSender, rhs: PSender) -> Bool {
        return lhs.id == rhs.id
    }
    
}

public class PAvatar {
    var image: UIImage
    
    init(withImage image: UIImage) {
        self.image = image
    }
}