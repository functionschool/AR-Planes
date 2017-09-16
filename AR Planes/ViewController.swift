//
//  ViewController.swift
//  AR Planes
//
//  Created by Cal Stephens on 9/16/17.
//  Copyright © 2017 Hack the North. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import CoreLocation
import Starscream
import ModelIO
import SceneKit.ModelIO

class ViewController: UIViewController, ARSCNViewDelegate {

    var socket = WebSocket(url: URL(string: "ws://34.232.80.41/")!)
    
    @IBOutlet var sceneView: ARSCNView!
    fileprivate let locationManager = CLLocationManager()
    
    var mostRecentUserLocation: CLLocation? {
        didSet {
            sendLocation()
        }
    }
    
    var nearbyFlights: [Flight] = [] {
        didSet {
            guard let userLocation = mostRecentUserLocation else {
                return
            }
            
            let newNodes = nearbyFlights.map { flight -> SCNNode in
                let planeNode = nodeForPlane(color: .red)
                planeNode.position = Flight.mock.sceneKitCoordinate(relativeTo: userLocation)
                return planeNode
            }
            
            sceneView.scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
            newNodes.forEach { sceneView.scene.rootNode.addChildNode($0) }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        
        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.antialiasingMode = .multisampling2X
        
        // Connect to web socket
        socket.delegate = self
        socket.connect()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        sceneView.session.run(configuration)
        
        setUpLocationManager()
        
        /*let greenPlane = nodeForPlane(color: .green)
        greenPlane.position = SCNVector3.init(500, 500, 500)
        sceneView.scene.rootNode.addChildNode(greenPlane)
        
        let bluePlane = nodeForPlane(color: .green)
        bluePlane.position = SCNVector3.init(0, 400, 0)
        sceneView.scene.rootNode.addChildNode(bluePlane)
        
        let planeNode = nodeForPlane(color: .red)
        let hardcodedLocation = CLLocation(latitude: 43.4729, longitude: -80.5402)
        planeNode.position = Flight.mock.sceneKitCoordinate(relativeTo: hardcodedLocation)
        sceneView.scene.rootNode.addChildNode(planeNode)*/
    }
    
    func nodeForPlane(color: UIColor = .white) -> SCNNode {
        let planeAssetUrl = Bundle.main.url(forResource: "777", withExtension: "obj")!
        let planeAsset = MDLAsset(url: planeAssetUrl)
        let planeNode = SCNNode(mdlObject: planeAsset.object(at: 0))
        
        let planeMaterial = SCNMaterial()
        planeMaterial.diffuse.contents = color
        planeNode.geometry?.materials = [planeMaterial]
        
        return planeNode
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    // MARK: - ARSCNViewDelegate
    
    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
     let node = SCNNode()
     
     return node
     }
     */
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }

}

// MARK: - CLLocationManagerDelegate

extension ViewController: CLLocationManagerDelegate {
    
    func setUpLocationManager() {
        // Initialize
        locationManager.delegate = self
        
        // Highest accuracy
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Request location when app is in use
        locationManager.requestWhenInUseAuthorization()
        
        // Update location if authorized
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
    }
    
    // Called every time location changes
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        mostRecentUserLocation = locations[0] as CLLocation
    }
    
    // Called if location manager fails to update
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("\(error)")
    }
}

// MARK: - WebSocketDelegate

extension ViewController: WebSocketDelegate {
    
    func websocketDidConnect(socket: WebSocket) {
        sendLocation()
    }
    
    func sendLocation() {
        guard let location = mostRecentUserLocation else {
            return
        }
        
        socket.write(string: "\(location.coordinate.latitude),\(location.coordinate.longitude)")
    }
    
    func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        print("disconnected")
    }
    
    func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        guard let flightData = text.toJSON() as? [[String: Any]] else {
            return
        }
        
        nearbyFlights = flightData.map { flight in
            let icao = flight["icao"] as? String ?? "--"
            let call = flight["call"] as? String ?? "Unknown"
            let lat = flight["lat"] as? Double ?? 0
            let lng = flight["lng"] as? Double ?? 0
            let alt = flight["alt"] as? Double ?? 0
            let hdg = flight["hdg"] as? Double ?? 0
            let _ = flight["gvel"]
            let _ = flight["vvel"]
            
            let airplane = Flight(
                ICAO: icao,
                callsign: call,
                longitude: lat,
                latitude: lng,
                altitude: alt,
                heading: hdg)
            
            return airplane
        }
    }
    
    func websocketDidReceiveData(socket: WebSocket, data: Data) {
        print("data")
    }
}

extension String {
    func toJSON() -> Any? {
        guard let data = self.data(using: .utf8, allowLossyConversion: false) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
    }
}
