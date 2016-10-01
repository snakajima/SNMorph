//
//  SNMorphEditController.swift
//  SNMorph
//
//  Created by satoshi on 10/1/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

class SNMorphEditController: UIViewController {
    public var grid:SNMorphGrid!
    
    @IBOutlet var viewMain:UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        viewMain.layer.contentsGravity = kCAGravityCenter
        viewMain.layer.contents = grid.cgImage
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
