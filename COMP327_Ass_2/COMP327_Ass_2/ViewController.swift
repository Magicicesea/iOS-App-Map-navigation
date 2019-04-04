//
//  ViewController.swift
//  COMP327_Ass_2
//
//  Created by Jianfei Wang on 08/12/2016.
//  Copyright © 2016 Jianfei Wang. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    //accept results from former view
    var place = MapViewController.resultPlaces[currentPlace]
    //used to lock thread 
    var flag:Bool = true

    @IBOutlet weak var UIimage: UIImageView!
    
    @IBOutlet weak var adressLabel: UILabel!
    
    @IBOutlet weak var phoneLabel: UILabel!
    
    @IBOutlet weak var webLabel: UILabel!
    
    @IBOutlet weak var nameLabel: UILabel!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //set text for each label
    override func viewDidAppear(_ animated: Bool) {
        //get palce_id from former request
        self.requestJSON(url: URL(string:"https://maps.googleapis.com/maps/api/place/details/json?placeid=\(place.place_id)&key=\(APIKEY)")! )
            //lock
            while( flag ){

            }
        //reset flag
        flag = true
        //specific place
        place = MapViewController.resultPlaces[currentPlace]
        //name is basic attribute for place instance
        nameLabel.text = place.name
        
        //set other possible attributes
        if place.phone != nil{
            phoneLabel.text = place.phone!
        }
        if place.address != nil{
            adressLabel.text  = place.address!
        }
        if place.web != nil{
            webLabel.text = place.web!
        }
        if place.photo_url != nil{
            
            //photo is url format
            if let url = NSURL.init(string: "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=\(place.photo_url!)&key=\(APIKEY)"){
                //if return data from server
                if let data = NSData.init(contentsOf: url as URL){
                    //set image
                    UIimage.image = UIImage(data: data as Data)
            }
        }
        }
        

        
    }

    //this function is same as former one, just change the url and attribute part
    func requestJSON(url:URL){

        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if error != nil {
                fatalError("Can not connect to server")
            } else {
                if let urlContent = data {
                    do {
                        let  jsonData=try JSONSerialization.jsonObject(with: urlContent, options: JSONSerialization.ReadingOptions.mutableContainers) as AnyObject
                        let jsonDictionary = jsonData as? NSDictionary
                        
                        //these attributes could be nil
                        MapViewController.resultPlaces[currentPlace].phone = (jsonDictionary?["result"] as? NSDictionary)?["formatted_phone_number"] as? String
                        MapViewController.resultPlaces[currentPlace].web = (jsonDictionary?["result"] as? NSDictionary)?["website"] as? String
                        //unlock
                        self.flag = false
                        
                    } catch {
                        fatalError("JSON processing failed")
                    }
                    
                }
            }
        }
        task.resume()
    }
    
}
