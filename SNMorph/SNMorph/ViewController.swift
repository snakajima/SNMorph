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
            if let image = sender as? UIImage {
                vc.grid = SNMorphGrid(image: image, slice: (x: 32, y: 24), border: 0, limit:1024)
            } else {
                vc.grid = SNMorphGrid(image: UIImage(named: "IMG_5417.JPG")!, slice:(x:8,y:6), border: 2, limit:1024)
            }
        }
    }

    @IBAction func importPhoto(sender:UIBarButtonItem) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = UIImagePickerControllerSourceType.photoLibrary
        picker.modalPresentationStyle = .popover
        picker.popoverPresentationController?.barButtonItem = sender
        self.present(picker, animated: true, completion: nil)
    }
    
}

extension ViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        self.dismiss(animated: true, completion: nil)
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            NSLog("AssetGroup picker: no no image")
            return
        }
        performSegue(withIdentifier: "editor", sender: image)
    }
}

