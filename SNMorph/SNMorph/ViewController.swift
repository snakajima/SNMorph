//
//  ViewController.swift
//  SNMorph
//
//  Created by satoshi on 10/1/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? SNMorphEditController {
            vc.grid = SNMorphGrid(image: UIImage(named: "IMG_5417.JPG")!, slice:(x:8,y:8), border: 2)
        }
    }

}

