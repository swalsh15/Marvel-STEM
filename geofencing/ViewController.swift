//
//  ViewController.swift
//  geofencing
//
//  Created by Stephanie Walsh on 9/7/17.
//  Copyright © 2017 Stephanie Walsh. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import AVFoundation
import UserNotifications

class ViewController: UIViewController, UITextFieldDelegate, UNUserNotificationCenterDelegate, AVAudioPlayerDelegate {
    @IBOutlet weak var userInput: UITextField!
    @IBOutlet weak var mapView: MKMapView!
    let locationManager = CLLocationManager()
    var audioPlayer = AVAudioPlayer()
    
    var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid


    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        
        userInput.delegate = self
        
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in }
       
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func addPin(_ sender: Any) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(userInput.text!) {
            placemarks, error in
            let placemark = placemarks?.first
            let lat = placemark?.location?.coordinate.latitude
            let lon = placemark?.location?.coordinate.longitude
            
            let pinLocation : CLLocationCoordinate2D = CLLocationCoordinate2DMake(lat!, lon!)
            let region = CLCircularRegion(center: pinLocation, radius: 200, identifier: "geofence")
            self.mapView.removeOverlays(self.mapView.overlays)
            self.locationManager.startMonitoring(for: region)
            let circle = MKCircle(center: pinLocation, radius: region.radius)
            self.mapView.add(circle)
            
            let pin = MKPointAnnotation()
            pin.coordinate = pinLocation
            self.mapView.removeAnnotations(self.mapView.annotations)
            self.mapView.addAnnotation(pin)
            
            self.userInput.text = ""
        }
        registerBackgroundTask()
        userInput.resignFirstResponder()
    }
  
    @IBAction func findMe(_ sender: Any) {
        let latitude:CLLocationDegrees = (locationManager.location?.coordinate.latitude)!
        let longitude:CLLocationDegrees = (locationManager.location?.coordinate.longitude)!
        let latDelta:CLLocationDegrees = 0.05
        let lonDelta:CLLocationDegrees = 0.05
        let span = MKCoordinateSpanMake(latDelta, lonDelta)
        let location = CLLocationCoordinate2DMake(latitude, longitude)
        let region = MKCoordinateRegionMake(location, span)
        mapView.setRegion(region, animated: true)
    }
    @IBAction func info(_ sender: Any) {
         let alert = UIAlertController(title: "Instructions", message: "Type in an address or press and hold the map to select a location to be alerted at.", preferredStyle: .alert)
        let dismissAlarm = UIAlertAction(title: "Dismiss", style: .default)
        alert.addAction(dismissAlarm)
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func addRegion(_ sender: Any) {
        guard let longPress = sender as? UILongPressGestureRecognizer else { return }
        let touchLocation = longPress.location(in: mapView)
        let coordinate = mapView.convert(touchLocation, toCoordinateFrom: mapView)
        let region = CLCircularRegion(center: coordinate, radius: 200, identifier: "geofence")
        mapView.removeOverlays(mapView.overlays)
        locationManager.startMonitoring(for: region)
        let circle = MKCircle(center: coordinate, radius: region.radius)
        mapView.add(circle)
        
        let pin = MKPointAnnotation()
        pin.coordinate = coordinate
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotation(pin)
        
        registerBackgroundTask()
        
    }
    
    //notifications and alerts
    func showAlert(){
        let alert = UIAlertController(title: "Destination Reached", message: "Wake Up!", preferredStyle: .alert)
        
        let dismissAlarm = UIAlertAction(title: "Stop Alarm", style: .default, handler: {action in
        self.audioPlayer.stop()
        AudioServicesRemoveSystemSoundCompletion(kSystemSoundID_Vibrate)
        })
        alert.addAction(dismissAlarm)
        
        present(alert, animated: true, completion: nil)
    }
    
    func showNotification(){
        let turnOff = UNNotificationAction(identifier: "turnOff", title: "Stop", options: UNNotificationActionOptions.foreground)
        let category = UNNotificationCategory(identifier: "myCategory", actions: [turnOff], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        
        
        let content = UNMutableNotificationContent()
        content.title = "Destination Reached"
        content.body = "Slide down to turn alarm off"
        content.categoryIdentifier = "myCategory"
        content.badge = 1
        
        let request = UNNotificationRequest(identifier: "notice", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "turnOff"{
            audioPlayer.stop()
        }
        completionHandler()
        AudioServicesRemoveSystemSoundCompletion(kSystemSoundID_Vibrate)
        endBackgroundTask()
    }

    
    //hides keyboard when return is pressed
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        textField.resignFirstResponder()
        return true
    }
    
    func playSound() {
        //vibrate phone first
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        //set vibrate callback
        AudioServicesAddSystemSoundCompletion(SystemSoundID(kSystemSoundID_Vibrate),nil,
                                              nil,
                                              { (_:SystemSoundID, _:UnsafeMutableRawPointer?) -> Void in
                                                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        },nil)
        
        do{
         let audioPath = Bundle.main.path(forResource: "alarm", ofType: ".mp3")
         try audioPlayer = AVAudioPlayer(contentsOf: URL(fileURLWithPath: audioPath!))
         }
         catch{
            print("error in path")
         }
        
        let session = AVAudioSession.sharedInstance()
        do{
            try session.setCategory(AVAudioSessionCategoryPlayback)
            //try session.setActive(true)
        }
        catch{
            print("error in session: \(error.localizedDescription)")
        }
        
        audioPlayer.prepareToPlay()
        audioPlayer.numberOfLoops = -1
        audioPlayer.play()
    }
    
    //background 
    func registerBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        assert(backgroundTask != UIBackgroundTaskInvalid)
        print("started background task")
    }
    
    func endBackgroundTask() {
        print("Background task ended.")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = UIBackgroundTaskInvalid
    }
}

extension ViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationManager.stopUpdatingLocation()
        mapView.showsUserLocation = true
    }
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        showAlert()
        showNotification()
        playSound()
        
    }
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        showAlert()
        showNotification()
        playSound()
        
    }
    
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let circleOverlay = overlay as? MKCircle else { return MKOverlayRenderer() }
        let circleRenderer = MKCircleRenderer(circle: circleOverlay)
        circleRenderer.strokeColor = .red
        circleRenderer.fillColor = .red
        circleRenderer.alpha = 0.5
        return circleRenderer
    }
}

