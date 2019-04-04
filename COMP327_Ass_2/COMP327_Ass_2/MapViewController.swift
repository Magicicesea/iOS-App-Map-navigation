//
//  MapViewController.swift
//  COMP327_Ass_2
//
//  Created by Jianfei Wang on 08/12/2016.
//  Copyright © 2016 Jianfei Wang. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

//used to give specific object in storage space
var currentPlace = -1
//some JSON request key
let APIKEY:String = "AIzaSyAdp2qdjsL6sn1_kgqm3oIaPCxMxNZMfYM"
//RADIUS shuold be set within 50000
let RADIUS:String = "30000"
//space to store results temporally in case lost after returning from other view
var tempDataStorage = Array<Place>()
//ashton building
let Ashton = "53.406566,-2.966531"

//custom place to store info about specific place
struct Place{
    //attributes needed to be initialized
    let name:String
    let lat:Double
    let lng:Double
    let place_id:String
    //additional attributes
    var photo_url:String? = nil
    var address:String? = nil
    var phone:String? = nil
    var web:String? = nil
    
    //initialize function
    init? (unname:String, unlat:Double, unlng:Double, unplace_id:String){
        name=unname
        lat=unlat
        lng=unlng
        place_id=unplace_id
    }

}

//map view class will be the focus of this project
class MapViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MKMapViewDelegate,CLLocationManagerDelegate,UITextFieldDelegate,UISearchBarDelegate {
    
    //custom button class
    class MyButton : UIButton {
        //the specific annotaion of this button object
        var annotation: MKAnnotation? = nil
    }
    
    //store results returned by Goole Map service
    static var resultPlaces:[Place] = []
    var filterResult:[Place] = []
    //used for show state of application
    var postcodeFlag:Bool = false
    var filterFlag:Bool = false
    var searchFlag:Bool = false
    //variable store userinput for functions calling
    var userInput:String?
    
    //UI object reference
    @IBOutlet weak var map: MKMapView!
    
    @IBOutlet weak var table: UITableView!
    
    @IBOutlet weak var locateSelfButton: UIButton!
    
    @IBOutlet weak var filterButton: UIButton!
    
    @IBOutlet weak var searchButton: UIButton!

    @IBOutlet weak var filterBar: UISearchBar!

    @IBOutlet weak var searchBar: UITextField!
    
    @IBOutlet weak var postcodeButton: UIButton!
    
    //cllocationmanager task object
    let locationManager=CLLocationManager()
    //coordinate of current location
    var locValue:CLLocationCoordinate2D?
    //indicate user request locating himself
    var needCenter:Bool=false
    //a String like "53.406566,-2.966531" used in url request
    var location:String?
    //flag used for thread safety, but after that task query is used.
    var flag:Bool = true
    //serial task query
    var queue = DispatchQueue(label:"temp")
    //semaphore to lock thread
    var sema = DispatchSemaphore(value: 1)
    
    //function to locate current position of user. While location is changing, function will be called
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        //update the location
        locValue = manager.location!.coordinate
        
        //if user have no location then return in case any exception caused by nil
        if locValue == nil {
            return
        }
        
        //update location variable
        location = String((locValue?.latitude)! as Double)+","+String((locValue?.longitude)! as Double)
        
        //set map region
        if needCenter{
            
            //user position as focus
            let span = MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            let region = MKCoordinateRegion(center: locValue!, span: span)
            self.map.setRegion(region, animated: true)
            
            //reset flag in case segment is called again
            needCenter=false
        }
        
    }
    
    //response to filter button
    @IBAction func filter(_ sender: UIButton) {
        
        
        if filterFlag{
            resetUI()
        }else{
            
        //set ui part
        filterBar.isHidden=false
        filterButton.isHidden=false
        
        searchBar.isHidden=true
        searchButton.isHidden=true
        
        postcodeButton.isHidden=true
            
        filterButton.backgroundColor=UIColor.blue
            
        
        }
        
        self.filterFlag = !self.filterFlag
        
    }
    
   //response to post code button
    @IBAction func searchPostcode(_ sender: UIButton) {
        
        if postcodeFlag{
            resetUI()
        }else{
            //set ui part
            filterBar.isHidden=true
            filterButton.isHidden=true
            
            searchBar.isHidden=false
            searchButton.isHidden=true
            
            postcodeButton.isHidden=false
            
            postcodeButton.backgroundColor = UIColor.blue
            
        }
        
        self.postcodeFlag = !self.postcodeFlag
        
        
        
    }
    
    //response to locate button
    @IBAction func locateSelf(_ sender: UIButton) {
        //indicate user want locate itself
        needCenter = true
    }
    //response to search button
    @IBAction func searchPlace(_ sender: UIButton) {
        
        if searchFlag{
            resetUI()
        }else{
        //set ui part
        filterBar.isHidden=true
        filterButton.isHidden=true
        
        searchBar.isHidden=false
        searchButton.isHidden=false
        
        postcodeButton.isHidden = true
            
        searchButton.backgroundColor = UIColor.blue
            
        }
        
        self.searchFlag = !self.searchFlag
        
    }

    //search place by post code
    func searchPost(){
        //creat geocoder object to reverse corresponding info
        let geocoder = CLGeocoder()
        
        //this task will use thread safety because this is depended by further function
        queue.async {
            //lock
            self.sema.wait()
            
            //set the priority as highest
            DispatchQueue.global(qos: .userInitiated).sync {
                
                //reverse the place
                geocoder.geocodeAddressString(self.searchBar.text!) { (placemarks, error) -> Void in
                    if let firstPlacemark = placemarks?[0] {
                        self.userInput = firstPlacemark.name
                        //unlock
                        self.sema.signal()
                    }
                }
            }
        }
    }
    
    //when user finished entering serach text
    @IBAction func searchEntered(_ sender: UITextField) {
        
        //remove all former results
        MapViewController.resultPlaces.removeAll()
        filterResult.removeAll()
        //both postcode searching pattern and context searching use same function
        if postcodeFlag{
            searchPost()}
        if searchFlag{
            userInput = searchBar.text
        }
        
        //thread safey cause results will be shown in table cells
        queue.async {
            //lock
            self.sema.wait()
            
            //if no location is simulated, in case loction is nil
            if self.location == nil {
                self.location = Ashton
            }
            
            //have url string format replace all space with '+'
            let urlstr = "https://maps.googleapis.com/maps/api/place/textsearch/json?query=\(self.userInput!)&key=\(APIKEY)&location=\(self.location!)&radius=\(RADIUS)".replacingOccurrences(of:" ", with: "+")
            //creat rul request
            let url = URL(string: urlstr)!
            let _ = self.requestJSON(url: url)
            
            //TO DO to present all 60 results returned by Google service
            //I want to develop this feature at first but founded it is not required and involves thread safety
            //so leave this part as further development, but there is no more time for developing this part.
            
//        let page_token = self.requestJSON(url: url)
//        while (page_token != ""){
//           
//           url = URL(string: "https://maps.googleapis.com/maps/api/place/textsearch/json?pagetoken=\(page_token)&key=\(APIKEY)")!
//            
//            page_token = requestJSON(url: url)
//            
//            print("here get\(page_token)")
//            print("here 2")
//        }
        
            //at first filter results will be filled by search results
            self.filterResult = MapViewController.resultPlaces
            
                //refresh table
                DispatchQueue.main.async{
                    self.table.reloadData()
                }
            //set annotions at map
            self.makeAnnotion()
            //unlock
            self.sema.signal()
            }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        searchBar.delegate=self
        table.delegate=self
        table.dataSource=self
        
        // Ask for Authorisation from the User.
        self.locationManager.requestAlwaysAuthorization()
        
        // For use in foreground
        self.locationManager.requestWhenInUseAuthorization()
        
        //enable cllocation manager
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        }
        
        //regist table
        self.table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        //focus on the ashton building
        let span = MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        locValue = CLLocationCoordinate2D.init(latitude: 53.406566, longitude:-2.966531)
        let region = MKCoordinateRegion(center: locValue!, span: span)
        self.map.setRegion(region, animated: true)
        //set map delegate
        map.delegate = self
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //function for cell counting
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
        
        return self.filterResult.count
    
    }
    
    //function for cell context
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell{
    
        let cell = UITableViewCell(style: UITableViewCellStyle.default, reuseIdentifier: "Cell")
        
        cell.textLabel?.text = self.filterResult[indexPath.row].name + "\t" + String(format:"%.2f", distanceBetweenPlace(place: self.filterResult[indexPath.row])) + "m"
        
        
        
        return cell
        
    }
    
    //return specific location of storage, update currentPlace
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        var index = 0
        //cause the cell shows filter result, the currentPlace has to be the position of search result
        //compare with each one in search results
        for result in MapViewController.resultPlaces{
            
            if result.name == filterResult[indexPath.row].name{
                currentPlace = index
            }
            
            index = index+1
        }
        //tansfer to another view
        performSegue(withIdentifier: "toDetailViewController", sender: nil)
    }
    
    //request JSON
    func requestJSON(url:URL) -> String {
        //for further development
        //page token return
        var page_token:String = ""
        
        //set url task
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            //if error happen
            if error != nil {
                
                fatalError("Can not connect to server")
            } else {
                //if server return data
                if let urlContent = data {
                    
                    do {
                        //read json as mutable container for further casting
                       let  jsonData=try JSONSerialization.jsonObject(with: urlContent, options: JSONSerialization.ReadingOptions.mutableContainers) as AnyObject
                        //save data as dictionary
                        let jsonDictionary = jsonData as? NSDictionary
                        //return page token for visit next page result
                        if(jsonDictionary?.value(forKey: "next_page_token") as? String != nil){
                            page_token = (jsonDictionary?.value(forKey: "next_page_token") as? String)!
                        }
                        //set results array
                        if let rawTempleArray = jsonDictionary?.value(forKey: "results") as? NSMutableArray{
                            
                            //for each result extrace palce info to create place instance
                            for temple in rawTempleArray{
                                //only name,latitude,longtitude and place_id exist at same time,
                                //instance will be created
                                if let templeName = (temple as? NSDictionary)?["name"] as? String{
                                    if let templeLat = (((temple as? NSMutableDictionary)?["geometry"] as? NSMutableDictionary)?["location"] as? NSMutableDictionary)?["lat"] as? Double{
                                        if let templeLng = (((temple as? NSMutableDictionary)?["geometry"] as? NSMutableDictionary)?["location"] as? NSMutableDictionary)?["lng"] as? Double{
                                            if let templePlace_id = (temple as? NSDictionary)?["place_id"] as? String{
                                                //initialize place instance
                                                if var templeItem = Place(unname: templeName,unlat: templeLat,unlng: templeLng,unplace_id: templePlace_id){
                                                    
                                                    //for additional info
                                                    templeItem.address = (temple as? NSDictionary)?["formatted_address"] as? String
                                                    templeItem.photo_url = (((temple as? NSDictionary)?["photos"] as? NSArray)?[0] as? NSDictionary)?["photo_reference"] as? String
                                                    //result instance will be added to list
                                                    MapViewController.resultPlaces.append(templeItem)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        //used to lock thread
                        self.flag = false
                    } catch {
                        fatalError("JSON processing failed")
                    }
                }
            }
        }
        
        //insert task into default queue
        task.resume()
        
        //lock flow
        while( flag ){
            
        }
        //reset flag
        flag = true
        
        //remove origianl results and put new results
        self.filterResult.removeAll()
        self.filterResult.append(contentsOf: MapViewController.resultPlaces)

        return page_token
    }
    
    //resign the keyboard
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return true
    }
    
    //reset UI as default
    func resetUI(){
        
        filterBar.isHidden=true
        filterButton.isHidden=false
        
        searchBar.isHidden=true
        searchButton.isHidden=false
        
        postcodeButton.isHidden = false
        
        filterButton.backgroundColor = nil
        searchButton.backgroundColor = nil
        
        postcodeButton.backgroundColor = nil
        
    }
    
    //filter the results
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {

        if searchText == "" {
 
            self.filterResult.append(contentsOf: MapViewController.resultPlaces)
 
        }
        else {
            self.filterResult = []
            for place in MapViewController.resultPlaces{
                
                if place.name.lowercased().contains(searchText.lowercased()){
                    self.filterResult.append(place)
                }
            }
        }
        DispatchQueue.main.async{
            self.table.reloadData()
        }
    }
    
    //resign keyboard
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        makeAnnotion()
     }
    
    //add annotion to map
    func makeAnnotion(){
        
        //remove current annotations
        self.map.removeAnnotations(self.map.annotations)
        
        for place in filterResult{
            
            //initialize annotaion instance
            let temp = MKPointAnnotation()
            temp.coordinate = CLLocationCoordinate2D.init(latitude: place.lat, longitude:place.lng)
            temp.title = place.name
            
            //set annotationview
            let annotationview = MKPinAnnotationView(annotation:temp, reuseIdentifier:temp.title)
            annotationview.isEnabled = true
            annotationview.canShowCallout = true
            
            //add info button to the view
            let btn = MyButton(type:.infoLight)
            //add listener event to this button
            btn.addTarget(self, action: #selector(self.showAnnotationDisclosure(_:)), for: .touchUpInside)

            annotationview.calloutOffset = CGPoint(x: -5, y:5)
            annotationview.rightCalloutAccessoryView = btn
        
            //add annotation to map
            self.map.addAnnotation(annotationview.annotation!)
        }
    }
    
    //return distance between user and place
    func distanceBetweenPlace(place:Place) -> Double{
        
        let place = CLLocation.init(latitude: place.lat, longitude: place.lng)
        let me = CLLocation.init(latitude: (locValue?.latitude)!, longitude:(locValue?.longitude)!)
        
        return place.distance(from: me)
        
    }
    
    //reload some data
    override func viewDidAppear(_ animated: Bool) {
        MapViewController.resultPlaces = tempDataStorage
        filterResult = tempDataStorage
        DispatchQueue.main.async{
            self.table.reloadData()
            self.makeAnnotion()
        }
    }
    
    //store results in gobal variable
    override func viewDidDisappear(_ animated: Bool) {
        tempDataStorage = MapViewController.resultPlaces
    }
    
    //function when annoation is added will be called
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        //set identifier for each annotation
        let identifier = "place"
        
        //in case user location is added annotaion
        if annotation.title! == "My Location"{
            return nil
        }
        //if this annotation view is seted
        if let annotationview = map.dequeueReusableAnnotationView(withIdentifier: identifier){

            annotationview.annotation = annotation
            return annotationview
        //if not seted
        }else{
            
            //initializ as former
            let annotationview = MKPinAnnotationView(annotation:annotation, reuseIdentifier:identifier)
            annotationview.isEnabled = true
            annotationview.canShowCallout = true
                    
            let btn = MyButton(type:.infoLight)
            btn.addTarget(self, action: #selector(self.showAnnotationDisclosure(_:)), for: .touchUpInside)
            btn.annotation = annotation
                    
            annotationview.calloutOffset = CGPoint(x: -5, y:5)
            annotationview.rightCalloutAccessoryView = btn
            return annotationview
        }
    }
    
    //function listen to the button
    func showAnnotationDisclosure(_ sender:MyButton){
        
        //set dest and user position
        let dest = MKPlacemark.init(coordinate: (sender.annotation?.coordinate)!)
        let me = MKPlacemark.init(coordinate: locValue!)
        
        let destitem = MKMapItem.init(placemark: dest)
        let personal = MKMapItem.init(placemark: me)
        
        //initialize request
        let request = MKDirectionsRequest()
        request.source = personal
        request.destination = destitem
        request.requestsAlternateRoutes = false
        request.transportType = .walking
        
        //start request
        let directions = MKDirections(request:request)
        //use [unowened self] to ensure route always exist
        directions.calculate{[unowned self] response,error in
            
        //only have response will continue
            guard let unwrappedResponse = response else {
                    print("no response")
                    print(error,"error:\(error)")
                    return
                }
        //remove former routes
        self.map.removeOverlays(self.map.overlays)
        //add route
        self.map.add(unwrappedResponse.routes[0].polyline)
        //set focus of map
        self.map.setVisibleMapRect(unwrappedResponse.routes[0].polyline.boundingMapRect, animated: true)}
    }
    
    //fucntion to set routes shown in map
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline{
            let polylineRener = MKPolylineRenderer(overlay: overlay)
            
            polylineRener.strokeColor = UIColor.blue
            polylineRener.lineWidth = 5
            return polylineRener
        }
        return MKPolylineRenderer()
    }
    
}
