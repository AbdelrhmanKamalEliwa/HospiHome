//
//  VideoChatViewController.swift
//  HospiHome
//
//  Created by Seif Elmenabawy on 5/5/20.
//  Copyright © 2020 Elser_10. All rights reserved.
//

import UIKit
import TwilioVideo

class VideoChatViewController: UIViewController {
    
    @IBOutlet var waitingLabel: UILabel!
    
    // MARK:- UI Element Outlets and handles
    
    // `VideoView` created from a storyboard
    @IBOutlet weak var previewView: VideoView!
    
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var roomLine: UIView!
    @IBOutlet weak var roomLabel: UILabel!
    @IBOutlet weak var micButton: UIButton!
    
    var accessToken = "TWILIO_ACCESS_TOKEN"
       
       // Configure remote URL to fetch token from
       var tokenUrl = "http://localhost:8000/token.php"
       
       // Video SDK components
       var room: Room?
       var camera: CameraSource?
       var localVideoTrack: LocalVideoTrack?
       var localAudioTrack: LocalAudioTrack?
       var remoteParticipant: RemoteParticipant?
       var remoteView: VideoView?
       var reservation: Reservation?
       var cameraAllowed = true
       var microphoneAllowed = true
    
    deinit {
        // We are done with camera
        if let camera = self.camera {
            camera.stopCapture()
            self.camera = nil
        }
    }
    
    func checkForCameraPermissions(){
        if AVCaptureDevice.authorizationStatus(for: .video) ==  .authorized {
            //already authorized
        } else {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                if granted {
                    //access allowed
                } else {
                    self.cameraAllowed = false
                    self.alertError(withMessage: "The app cannot access your camera, you can allow it in your device settings")
                }
            })
        }
    }
    
    func checkForMicPermissions(){
        if AVCaptureDevice.authorizationStatus(for: .audio) ==  .authorized {
            //already authorized
        } else {
            AVCaptureDevice.requestAccess(for: .audio, completionHandler: { (granted: Bool) in
                if granted {
                    //access allowed
                } else {
                    self.microphoneAllowed = false
                    self.alertError(withMessage: "The app cannot access your microphone, you can allow it in your device settings")
                }
            })
        }
    }
    
    // MARK:- UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        checkForMicPermissions()
        checkForCameraPermissions()
        
        if !cameraAllowed && !microphoneAllowed{
            connectButton.isEnabled = false
        }
        //self.waitingLabel.isHidden = true
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat="dd/MM/yyyy HH:mm"
        let timeString = dateFormatter.string(from:  Date(timeIntervalSince1970: TimeInterval(exactly: Double(reservation!.time)!)!))
        
        self.waitingLabel.text = timeString
        
        //self.title = "QuickStart"
        self.messageLabel.adjustsFontSizeToFitWidth = true;
        self.messageLabel.minimumScaleFactor = 0.75;
        
        if PlatformUtils.isSimulator {
            self.previewView.removeFromSuperview()
        } else {
            // Preview our local camera track in the local video preview view.
            self.startPreview()
        }
        
        // Disconnect and mic button will be displayed when the Client is connected to a Room.
        self.disconnectButton.isHidden = true
        //self.waitingLabel.isHidden = true
        self.micButton.isHidden = true
        
        //        let tap = UITapGestureRecognizer(target: self, action: #selector(VideoChatViewController.dismissKeyboard))
        //        self.view.addGestureRecognizer(tap)
    }
    
    //    override var prefersHomeIndicatorAutoHidden: Bool {
    //        return self.room != nil
    //    }
    
    func setupRemoteVideoView() {
        // Creating `VideoView` programmatically
        self.remoteView = VideoView(frame: CGRect.zero, delegate: self)
        
        self.view.insertSubview(self.remoteView!, at: 0)
        
        // `VideoView` supports scaleToFill, scaleAspectFill and scaleAspectFit
        // scaleAspectFit is the default mode when you create `VideoView` programmatically.
        self.remoteView!.contentMode = .scaleAspectFit;
        
        let centerX = NSLayoutConstraint(item: self.remoteView!,
                                         attribute: NSLayoutConstraint.Attribute.centerX,
                                         relatedBy: NSLayoutConstraint.Relation.equal,
                                         toItem: self.view,
                                         attribute: NSLayoutConstraint.Attribute.centerX,
                                         multiplier: 1,
                                         constant: 0);
        self.view.addConstraint(centerX)
        let centerY = NSLayoutConstraint(item: self.remoteView!,
                                         attribute: NSLayoutConstraint.Attribute.centerY,
                                         relatedBy: NSLayoutConstraint.Relation.equal,
                                         toItem: self.view,
                                         attribute: NSLayoutConstraint.Attribute.centerY,
                                         multiplier: 1,
                                         constant: 0);
        self.view.addConstraint(centerY)
        let width = NSLayoutConstraint(item: self.remoteView!,
                                       attribute: NSLayoutConstraint.Attribute.width,
                                       relatedBy: NSLayoutConstraint.Relation.equal,
                                       toItem: self.view,
                                       attribute: NSLayoutConstraint.Attribute.width,
                                       multiplier: 1,
                                       constant: 0);
        self.view.addConstraint(width)
        let height = NSLayoutConstraint(item: self.remoteView!,
                                        attribute: NSLayoutConstraint.Attribute.height,
                                        relatedBy: NSLayoutConstraint.Relation.equal,
                                        toItem: self.view,
                                        attribute: NSLayoutConstraint.Attribute.height,
                                        multiplier: 1,
                                        constant: 0);
        self.view.addConstraint(height)
    }
    
    // MARK:- IBActions
    @IBAction func connectButtonTapped(sender: AnyObject) {
        var waitingFor = "doctor"
        if profile?.accountType == AccountType.Doctor{
            waitingFor = "patient"
        }
        
        self.waitingLabel.text = "waiting for the " + waitingFor + " to join"
        
        let parameters = ["reservationid": reservation!.id]
        API().httpPOSTRequest(endpoint: .videoToken, postData: parameters) { (data, error) in
            guard let data = data else{ self.navigationController?.popViewController(animated: true);return;}
            let tokenResponse = try? JSONDecoder().decode(VideoTokenResponse.self, from: data)
            DispatchQueue.main.async{
                if let response = tokenResponse{
                    if response.success{
                        self.accessToken = response.videotoken!
                        self.connectToRoom()
                    }
                    else{
                        self.navigationController?.popViewController(animated: true);
                    }
                }
            }
            
        }
    }
    
    func alertError(withMessage: String){
        
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Video Chat Error", message: withMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true) {
            }
        }
        
    }
    
    func connectToRoom(){
        self.prepareLocalMedia()
        let connectOptions = ConnectOptions(token: accessToken) { (builder) in
            builder.audioTracks = self.localAudioTrack != nil ? [self.localAudioTrack!] : [LocalAudioTrack]()
            builder.videoTracks = self.localVideoTrack != nil ? [self.localVideoTrack!] : [LocalVideoTrack]()
            builder.roomName = "reservation"+self.reservation!.id
        }
        room = TwilioVideoSDK.connect(options: connectOptions, delegate: self)
        
        print("Attempting to connect to room")
        
        self.showRoomUI(inRoom: true)
    }
    @IBAction func disconnect(sender: AnyObject) {
        self.room!.disconnect()
        print("Attempting to disconnect from room \(room!.name)")
    }
    
    @IBAction func toggleMic(sender: AnyObject) {
        if (self.localAudioTrack != nil) {
            self.localAudioTrack?.isEnabled = !(self.localAudioTrack?.isEnabled)!
            
            // Update the button title
            if (self.localAudioTrack?.isEnabled == true) {
                self.micButton.setTitle("Mute", for: .normal)
            } else {
                self.micButton.setTitle("Unmute", for: .normal)
            }
        }
    }
    
    // MARK:- Private
    func startPreview() {
        if PlatformUtils.isSimulator {
            return
        }
        
        let frontCamera = CameraSource.captureDevice(position: .front)
        let backCamera = CameraSource.captureDevice(position: .back)
        
        if (frontCamera != nil || backCamera != nil) {
            
            let options = CameraSourceOptions { (builder) in
                // To support building with Xcode 10.x.
                #if XCODE_1100
                if #available(iOS 13.0, *) {
                    // Track UIWindowScene events for the key window's scene.
                    // The example app disables multi-window support in the .plist (see UIApplicationSceneManifestKey).
                    builder.orientationTracker = UserInterfaceTracker(scene: UIApplication.shared.keyWindow!.windowScene!)
                }
                #endif
            }
            // Preview our local camera track in the local video preview view.
            camera = CameraSource(options: options, delegate: self)
            localVideoTrack = LocalVideoTrack(source: camera!, enabled: true, name: "Camera")
            
            // Add renderer to video track for local preview
            localVideoTrack!.addRenderer(self.previewView)
            print("Video track created")
            
            if (frontCamera != nil && backCamera != nil) {
                // We will flip camera on tap.
                let tap = UITapGestureRecognizer(target: self, action: #selector(VideoChatViewController.flipCamera))
                self.previewView.addGestureRecognizer(tap)
            }
            
            camera!.startCapture(device: frontCamera != nil ? frontCamera! : backCamera!) { (captureDevice, videoFormat, error) in
                if let error = error {
                    print("Capture failed with error.\ncode = \((error as NSError).code) error = \(error.localizedDescription)")
                } else {
                    self.previewView.shouldMirror = (captureDevice.position == .front)
                }
            }
        }
        else {
            print("No front or back capture device found!")
        }
    }
    
    @objc func flipCamera() {
        var newDevice: AVCaptureDevice?
        
        if let camera = self.camera, let captureDevice = camera.device {
            if captureDevice.position == .front {
                newDevice = CameraSource.captureDevice(position: .back)
            } else {
                newDevice = CameraSource.captureDevice(position: .front)
            }
            
            if let newDevice = newDevice {
                camera.selectCaptureDevice(newDevice) { (captureDevice, videoFormat, error) in
                    if let error = error {
                        print("Error selecting capture device.\ncode = \((error as NSError).code) error = \(error.localizedDescription)")
                    } else {
                        self.previewView.shouldMirror = (captureDevice.position == .front)
                    }
                }
            }
        }
    }
    
    func prepareLocalMedia() {
        
        // We will share local audio and video when we connect to the Room.
        
        // Create an audio track.
        if (localAudioTrack == nil) {
            localAudioTrack = LocalAudioTrack(options: nil, enabled: true, name: "Microphone")
            
            if (localAudioTrack == nil) {
                print("Failed to create audio track")
            }
        }
        
        // Create a video track which captures from the camera.
        if (localVideoTrack == nil) {
            self.startPreview()
        }
    }
    
    // Update our UI based upon if we are in a Room or not
    func showRoomUI(inRoom: Bool) {
        self.connectButton.isHidden = inRoom
        self.waitingLabel.isHidden = !inRoom
        self.roomLine.isHidden = inRoom
        self.micButton.isHidden = !inRoom
        self.disconnectButton.isHidden = !inRoom
        self.navigationController?.setNavigationBarHidden(inRoom, animated: true)
        UIApplication.shared.isIdleTimerDisabled = inRoom
        
        // Show / hide the automatic home indicator on modern iPhones.
        self.setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    func renderRemoteParticipant(participant : RemoteParticipant) -> Bool {
        // This example renders the first subscribed RemoteVideoTrack from the RemoteParticipant.
        let videoPublications = participant.remoteVideoTracks
        for publication in videoPublications {
            if let subscribedVideoTrack = publication.remoteTrack,
                publication.isTrackSubscribed {
                setupRemoteVideoView()
                subscribedVideoTrack.addRenderer(self.remoteView!)
                self.remoteParticipant = participant
                return true
            }
        }
        return false
    }
    
    func renderRemoteParticipants(participants : Array<RemoteParticipant>) {
        for participant in participants {
            // Find the first renderable track.
            if participant.remoteVideoTracks.count > 0,
                renderRemoteParticipant(participant: participant) {
                break
            }
        }
    }
    
    func cleanupRemoteParticipant() {
        if self.remoteParticipant != nil {
            self.remoteView?.removeFromSuperview()
            self.remoteView = nil
            self.remoteParticipant = nil
        }
    }
}

// MARK:- RoomDelegate
extension VideoChatViewController : RoomDelegate {
    func roomDidConnect(room: Room) {
        print("Connected to room \(room.name) as \(room.localParticipant?.identity ?? "")")
        
        // This example only renders 1 RemoteVideoTrack at a time. Listen for all events to decide which track to render.
        for remoteParticipant in room.remoteParticipants {
            remoteParticipant.delegate = self
        }
    }
    
    func roomDidDisconnect(room: Room, error: Error?) {
        print("Disconnected from room \(room.name), error = \(String(describing: error))")
        
        self.cleanupRemoteParticipant()
        self.room = nil
        
        self.showRoomUI(inRoom: false)
    }
    
    func roomDidFailToConnect(room: Room, error: Error) {
        print("Failed to connect to room with error = \(String(describing: error))")
        self.room = nil
        
        self.showRoomUI(inRoom: false)
    }
    
    func roomIsReconnecting(room: Room, error: Error) {
        print("Reconnecting to room \(room.name), error = \(String(describing: error))")
    }
    
    func roomDidReconnect(room: Room) {
        print("Reconnected to room \(room.name)")
    }
    
    func participantDidConnect(room: Room, participant: RemoteParticipant) {
        // Listen for events from all Participants to decide which RemoteVideoTrack to render.
        participant.delegate = self
        
        print("Participant \(participant.identity) connected with \(participant.remoteAudioTracks.count) audio and \(participant.remoteVideoTracks.count) video tracks")
    }
    
    func participantDidDisconnect(room: Room, participant: RemoteParticipant) {
        print("Room \(room.name), Participant \(participant.identity) disconnected")
        
        // Nothing to do in this example. Subscription events are used to add/remove renderers.
    }
}

// MARK:- RemoteParticipantDelegate
extension VideoChatViewController : RemoteParticipantDelegate {
    
    func remoteParticipantDidPublishVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        // Remote Participant has offered to share the video Track.
        
        print("Participant \(participant.identity) published \(publication.trackName) video track")
    }
    
    func remoteParticipantDidUnpublishVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        // Remote Participant has stopped sharing the video Track.
        
        print("Participant \(participant.identity) unpublished \(publication.trackName) video track")
    }
    
    func remoteParticipantDidPublishAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        // Remote Participant has offered to share the audio Track.
        
        print("Participant \(participant.identity) published \(publication.trackName) audio track")
    }
    
    func remoteParticipantDidUnpublishAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        // Remote Participant has stopped sharing the audio Track.
        
        print("Participant \(participant.identity) unpublished \(publication.trackName) audio track")
    }
    
    func didSubscribeToVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        // The LocalParticipant is subscribed to the RemoteParticipant's video Track. Frames will begin to arrive now.
        
        print("Subscribed to \(publication.trackName) video track for Participant \(participant.identity)")
        
        if (self.remoteParticipant == nil) {
            _ = renderRemoteParticipant(participant: participant)
        }
    }
    
    func didUnsubscribeFromVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        // We are unsubscribed from the remote Participant's video Track. We will no longer receive the
        // remote Participant's video.
        
        print("Unsubscribed from \(publication.trackName) video track for Participant \(participant.identity)")
        
        if self.remoteParticipant == participant {
            cleanupRemoteParticipant()
            
            // Find another Participant video to render, if possible.
            if var remainingParticipants = room?.remoteParticipants,
                let index = remainingParticipants.firstIndex(of: participant) {
                remainingParticipants.remove(at: index)
                renderRemoteParticipants(participants: remainingParticipants)
            }
        }
    }
    
    func didSubscribeToAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {
        // We are subscribed to the remote Participant's audio Track. We will start receiving the
        // remote Participant's audio now.
        
        print("Subscribed to \(publication.trackName) audio track for Participant \(participant.identity)")
    }
    
    func didUnsubscribeFromAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {
        // We are unsubscribed from the remote Participant's audio Track. We will no longer receive the
        // remote Participant's audio.
        
        print("Unsubscribed from \(publication.trackName) audio track for Participant \(participant.identity)")
    }
    
    func remoteParticipantDidEnableVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        print("Participant \(participant.identity) enabled \(publication.trackName) video track")
    }
    
    func remoteParticipantDidDisableVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        print("Participant \(participant.identity) disabled \(publication.trackName) video track")
    }
    
    func remoteParticipantDidEnableAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        print("Participant \(participant.identity) enabled \(publication.trackName) audio track")
    }
    
    func remoteParticipantDidDisableAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        print("Participant \(participant.identity) disabled \(publication.trackName) audio track")
    }
    
    func didFailToSubscribeToAudioTrack(publication: RemoteAudioTrackPublication, error: Error, participant: RemoteParticipant) {
        print("FailedToSubscribe \(publication.trackName) audio track, error = \(String(describing: error))")
    }
    
    func didFailToSubscribeToVideoTrack(publication: RemoteVideoTrackPublication, error: Error, participant: RemoteParticipant) {
        print("FailedToSubscribe \(publication.trackName) video track, error = \(String(describing: error))")
    }
}

// MARK:- VideoViewDelegate
extension VideoChatViewController : VideoViewDelegate {
    func videoViewDimensionsDidChange(view: VideoView, dimensions: CMVideoDimensions) {
        self.view.setNeedsLayout()
    }
}

// MARK:- CameraSourceDelegate
extension VideoChatViewController : CameraSourceDelegate {
    func cameraSourceDidFail(source: CameraSource, error: Error) {
        print("Camera source failed with error: \(error.localizedDescription)")
    }
}
