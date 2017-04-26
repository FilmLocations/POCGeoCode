//
//  ViewController.swift
//  TestGeoCoding
//
//  Created by Niraj Pendal on 4/25/17.
//  Copyright © 2017 Niraj. All rights reserved.
//

import UIKit
import GoogleMaps

typealias DictionaryAnyObject = [String: AnyObject]

protocol GeoCodingDelegate {
    func geoCodingCompleted(movie: SFMovie)
}

class SFMovie {
    var locations : String?
    var title: String?
    var distributor: String?
    var lat: Double?
    var long: Double?
    
    var delegate: GeoCodingDelegate?
    let nilConstant = "nil"
    
    init(dictionary: DictionaryAnyObject) {
        if let locations = dictionary["locations"] as? String {
            self.locations = locations + ", San Fransisco, CA"
        }
        self.distributor = dictionary["distributor"] as? String
        self.title = dictionary["title"] as? String
        self.lat = dictionary["lat"] as? Double
        self.long = dictionary["long"] as? Double
    }
    
    var toJSON: [String: Any] {
        var lat: Double?
        var long: Double?
        
//        if self.lat == nil {
//            lat = nilConstant
//        } else {
//            lat = "\(self.lat!)"
//        }
//        
//        if self.long == nil {
//            long = nilConstant
//        } else {
//            long = "\(self.long!)"
//        }
        
        return ["locations": self.locations ?? nilConstant ,
                "tilte": self.title ?? nilConstant,
                "lat": self.lat ?? 0,
                "long": self.long ?? 0,
                "distributor": self.distributor ?? nilConstant]
        
        //return "{\"locations\":\"\(self.locations ?? nilConstant)\",\"tilte\":\"\(self.title ?? nilConstant)\", \"lat\":\"\(lat)\", \"long\":\"\(long)\",  \"distributor\":\"\(self.distributor ?? nilConstant)\"}"
    }
    
//    static func jsonArray(array : [SFMovie]) -> String
//    {
//        return "[" + array.map {$0.toJSON}.joined(separator: ",") + "]"
//    }
    
    func fetchCordinatesFromLocation(location: String, callback:  @escaping (_ lat: Double?, _ long: Double?)->()) {
        let urlString = "https://maps.googleapis.com/maps/api/geocode/json?address=\(location)&key=AIzaSyDkh00P83RkVTjmA98hUI2iACj368aTeGI"
        let escapedString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        
        let url = URL(string: escapedString!)!
        
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: OperationQueue.main)
        let task: URLSessionDataTask = session.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            if let error = error {
                //callBack(nil, error)
                callback(nil, nil)
                return
            } else if let data = data,
                let dataDictionary = try! JSONSerialization.jsonObject(with: data, options: []) as? DictionaryAnyObject {
                
                if let results = dataDictionary["results"] as? [DictionaryAnyObject] {
                    if let result = results.first {
                        
                        if let geometry = result["geometry"] as? DictionaryAnyObject {
                            if let locations = geometry["location"] as? DictionaryAnyObject {
                                let lat = locations["lat"] as?  Double
                                let long = locations["lng"] as?  Double
                                callback(lat, long)
                                return
                            }
                        }
                    } else {
                        callback(nil, nil)
                        return
                    }
                }
                
                print(dataDictionary)
                callback(nil, nil)
                return
            }
        }
        task.resume()
        
        
    }
    
}

class ViewController: UIViewController {
    var movieUserDefaultsKey = "MoviesKey"
    var currentIndex = 0
    var movies:[SFMovie] = [SFMovie]()
    
    func fetchNextGeoCoding(){
        
        if self.movies.count > currentIndex && currentIndex < 10 {
            let movie = self.movies[self.currentIndex]
            
            if let location = movie.locations {
                
                print("Fetch GeoLocation for location \(location)")
                
                //DispatchQueue.global(qos: .userInitiated).sync(execute: {
                movie.fetchCordinatesFromLocation(location: location, callback: { (lat: Double?, long:Double?) in
                    
                    movie.lat = lat
                    movie.long = long
                    
                    print(lat)
                    print(long)
                    
                    self.currentIndex += 1
                    
                    self.fetchNextGeoCoding()
                    
                })
            } else {
                self.currentIndex += 1
                self.fetchNextGeoCoding()
            }
            
        } else {
            
            self.geoCodingCompleted()
        }
        
        
    }
    
    func geoCodingCompleted() {
        print("geoCodingCompleted")
        
        let movieJSONArray = self.movies.map {$0.toJSON}
        
        //let tempArray = [self.movies[0].toJSON]
        
        let data = try! JSONSerialization.data(withJSONObject: movieJSONArray, options: .init(rawValue: 0))
        
        // Store into JSON NSUserDefaults
        UserDefaults.standard.setValue(data, forKey: movieUserDefaultsKey)
        displayDataOnMap()
        
    }
    
    func displayDataOnMap() {
        
        let filteredMovies = self.movies.filter { (movie: SFMovie) -> Bool in
            if movie.lat != nil, movie.long != nil{
                return true
            }
            return false
        }
        
        let firstLat = filteredMovies.first?.lat
        let firstLong = filteredMovies.first?.long
        
        let camera = GMSCameraPosition.camera(withLatitude: firstLat!, longitude: firstLong!, zoom: 15.0)
        let mapView = GMSMapView.map(withFrame: CGRect.zero, camera: camera)
        self.view = mapView
        
        for movie in self.movies {
            
            if movie.lat != nil, movie.long != nil {
                // Creates a marker in the center of the map.
                let marker = GMSMarker()
                marker.position = CLLocationCoordinate2D(latitude: movie.lat!, longitude: movie.long!)
                marker.title = movie.title
                //marker.snippet = movie.
                marker.map = mapView
                
            }
            
        }

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let data = UserDefaults.standard.value(forKey: movieUserDefaultsKey) as? Data {
            
            //if let data = userDefaultsString.data(using: .utf8) {
                
                if let dataDictionaryArray = try! JSONSerialization.jsonObject(with: data, options: []) as? [DictionaryAnyObject] {
                    var sfMovieArray = [SFMovie]()
                    
                    for movieDict in dataDictionaryArray {
                        sfMovieArray.append(SFMovie(dictionary: movieDict))
                    }
                    self.movies = sfMovieArray
                    displayDataOnMap()
              //  }
            }
        } else {
            
            fetchMoviesFromAPI(url: URL(string: "https://data.sfgov.org/resource/wwmu-gmzc.json")!) { (resposne: [SFMovie]?, error: Error?) in
                print("Result returned")
                
                if error != nil {
                    print(error!.localizedDescription)
                    return
                }
                
                guard let resposne = resposne else {
                    print("resopnse is nil")
                    return
                }
                
                self.movies = resposne
                
                self.fetchNextGeoCoding()
            }
            
        }
        
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    func fetchMoviesFromAPI(url:URL, callBack: @escaping ([SFMovie]?, Error?) -> ()) {
        
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: OperationQueue.main)
        let task: URLSessionDataTask = session.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            if let error = error {
                callBack(nil, error)
                print(error.localizedDescription)
            } else if let data = data,
                let dataDictionaryArray = try! JSONSerialization.jsonObject(with: data, options: []) as? [DictionaryAnyObject] {
                
                var sfMovieArray = [SFMovie]()
                
                for movieDict in dataDictionaryArray {
                    sfMovieArray.append(SFMovie(dictionary: movieDict))
                }
                
                //print(dataDictionary)
                callBack(sfMovieArray, nil)
            } else {
                // Return
                print("Un expected error occured")
                callBack(nil, nil)
            }
        }
        task.resume()
    }
    
    
}

