//
//  ParlaViewController.swift
//  parla
//
//  Created by Domenico Gabriele Aiello on 09/05/2019.
//  Copyright © 2019 com.cyclonesword. All rights reserved.
//

import UIKit
import CoreLocation

/**
 
 Implement this protocol to provide the messages to be added to the ParlaView view and to set the main sender of the view.
 
*/
public protocol ParlaViewDataSource {
//    var sender: PSender! { get set }
//    var attachedViewController: UIViewController! { get set }
    
    func messageForCell(at indexPath: IndexPath, collectionView: UICollectionView) -> PMessage
    func numberOfMessagesIn(collectionView: UICollectionView) -> Int
    func outgoingSender() -> POutgoingSender
}

/**
    An optional delegate that, if set in the initializer, will notify the user of various operations performed.
    - Tag: parlaViewDelegate
 */
@objc public protocol ParlaViewDelegate  {
    
    // General delegate functions
    func didTapMessageBubble(at indexPath: IndexPath, message: PMessage, collectionView: UICollectionView)
    func didPressSendButton(withMessage message: PMessage, textField: UITextField, collectionView: UICollectionView)
    func didPressAccessoryButton(button: UIView, collectionView: UICollectionView)
    // ==========
    
    // === Optional functions ======= //
    
    // Accessory button delegate functions
    
    @objc optional func didLongTouchMessage(at indexPath: IndexPath, message: PMessage, collectionView: UICollectionView)
    @objc optional func didStartPickingImage(collectionView: UICollectionView)
    @objc optional func didFinishPickingImage(with image:UIImage?, collectionView: UICollectionView)
    
    @objc optional func didStartPickingVideo(with: URL?, collectionView: UICollectionView)
    @objc optional func didFinishPickingVideo(with: URL?, collectionView: UICollectionView)
    
    @objc optional func didFinishBuildingCurrentLocationMessage(with coordinates: CLLocationCoordinate2D, with message: PMapMessage)
    @objc optional func didStartBuildingCurrentLocationMessage(with coordinates: CLLocationCoordinate2D, with message: PMapMessage)
    
    @objc optional func didStartRecordingVoiceMessage(atUrl url: URL)
    @objc optional func didEndRecordingVoiceMessage(atUrl url: URL)
    // ==========
    
}

/**
    The central view to be added in your storyboard views where you want to display the chat UI.
    **This view must belong to a UIViewController class hierarchy or a runtime error will occur.**
*/
@IBDesignable
open class ParlaView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITextFieldDelegate, AccessoryActionChooserDelegate, CLLocationManagerDelegate, UIMicrophoneViewDelegate, VoiceRecorderDelegate  {

    public var dataSource: ParlaViewDataSource!
    public var delegate: ParlaViewDelegate?
    private let config = Parla.config
    
    private var viewController: UIViewController!
    
    public func refreshCollection(animated: Bool) {
        self.collectionView.reloadData()
        self.collectionView.scrollToBottom(animated: animated)
    }
    
    var inputToolbarContainer: ParlaInputToolbar?
    var collectionView: UICollectionView!
   // var textFieldContainer: UIView!
    var textField: UITextField!
    var accessoryButton: UIView!
    var microphoneButton: UIMicrophoneView!
    var bottomConstraints: [NSLayoutConstraint] = []
    var sendButton: UIView!
    
    private var keyboardDefaultBottomConstraintMargin = CGFloat(-45)
    private var keyboardStarterBottomMargin = CGFloat(20)
    
    private var recorder: VoiceRecorder?
    private var locationManager: CLLocationManager?
    
    @IBInspectable public var bottomMargin: CGFloat = 0
    @IBInspectable public var topMargin: CGFloat = 0
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.recorder = DefaultVoiceRecorder()
        self.recorder?.delegate = self
        bottomMargin = keyboardDefaultBottomConstraintMargin
        topMargin = keyboardStarterBottomMargin
    }
    
    ///  ********* ========== Collection View Methods ========== **************  ///
    public final func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let message = dataSource.messageForCell(at: indexPath, collectionView: collectionView)
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: message.cellIdentifier, for: indexPath) as! AbstractMessageCell
        
        cell.viewController = self
        cell.indexPath = indexPath
        cell.content = message
        
        cell.initialize()
        
//        if indexPath.row > 0 {
//            let precedingMsg = self.dataSource.messageForCell(at: IndexPath(row: indexPath.row-1, section: 1), collectionView: collectionView)
//            if message.sender.id == precedingMsg.sender.id {
//                cell.cellBottomLabelHeightConstraint.constant = 0
//            }
//        }
//
        
        
        return cell
    }
    
    public final func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return self.dataSource
            .messageForCell(at: indexPath, collectionView: collectionView)
            .displaySize(frameWidth: collectionView.frame.width)
    }
    
    public final func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public final func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.numberOfMessagesIn(collectionView: collectionView)
    }
    
    public final func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return Parla.config.cell.sectionInsets.left
    }
    
    public final func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return Parla.config.cell.sectionInsets
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("Selected item at index path: \(indexPath)")
    }
    /// ************** =========================== ****************** ///
    

    ///  ********* ========== UI Gesture Recognizers ========== **************  ///
    @objc private func onSendButtonPressed(_ sender: UITapGestureRecognizer) {
        if !textField.text!.isEmpty {
            let sm = PTextMessageImpl(id: self.dataSource.numberOfMessagesIn(collectionView: collectionView)+1,
                                      sender: self.dataSource.outgoingSender(),
                                      text: textField.text!,
                                      date: Date())
            
            self.delegate?.didPressSendButton(withMessage: sm, textField: self.textField, collectionView: self.collectionView)
            toggleSendButton()
        }
    }
    
    @objc private func onAccessoryButtonPressed(_ sender: UITapGestureRecognizer) {
        self.delegate?.didPressAccessoryButton(button: self.accessoryButton, collectionView: collectionView)
        
        if !config.accessoryButton.preventDefault {
            config.accessoryActionChooser?.show()
        }
    }
    
    open override func awakeFromNib() {
        self.viewController = self.parentViewController
        if viewController == nil {
            assertionFailure("The ParlaView view must belong to a UIViewController. This is a fatal error and the application must be terminated.")
        }
        Parla.config.containerViewController = self.viewController
    }
    
    /// ************** =========================== ****************** ///
    
    
    
    
    ///  ********* ========== Delegate Methods ========== **************  ///
    
    public func didChooseAccessoryAction(with action: AccessoryAction?, ofType type: AccessoryActionType) {
        print("Accessory action selected: == >> \(type) << ==")
        
        // Do additional setup here before invoking the function.
        
        action?()
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        return true
    }
    
    public func didStartMicrophoneTouch() {
        
        if let r = recorder, !r.isRecording {
            let fname = "voice_\(config.sender.name)_\(Date().timeIntervalSince1970).m4a"
            self.recorder?.audioUrl = URL.documentsDirectory.appendingPathComponent(fname)
            print(fname)
        }

        do {
            if self.recorder?.hasRecordingPermission ?? false {
                try self.recorder?.toggle()
            } else {
                try self.recorder?.requestRecordingPermission()
            }
        } catch {
            print("An error occurred recording voice message: \(error)")
        }
    }
    
    public func didEndMicrophoneTouch(withDuration duration: TimeInterval) {
        print("Total duration of microphone touch: \(duration)")
        do {
            try self.recorder?.toggle()
        } catch {
            print("An error occurred end recording voice message: \(error)")
        }
    }
    
    /// ************** =========================== ****************** ///

    private func chooseImageFrom(source: MediaPickerSource)  {
        self.delegate?.didStartPickingImage?(collectionView: self.collectionView)
        
        self.config.mediaPicker?.pickImage(source: source) {
            self.delegate?.didFinishPickingImage?(with: $0, collectionView: self.collectionView)
        }
    }
    
    private func chooseVideoFrom(source: MediaPickerSource)  {
   //     self.parlaDelegate?.didStartPickingImage(collectionView: self.collectionView)
        
        self.config.mediaPicker?.pickVideo(source: source) {
            self.delegate?.didFinishPickingVideo?(with: $0, collectionView: self.collectionView)
        }
    }
    
    private func sendPosition() {
        if self.locationManager == nil {
            locationManager = CLLocationManager()
            locationManager!.requestWhenInUseAuthorization()
            locationManager!.delegate = self;
            locationManager!.distanceFilter = kCLDistanceFilterNone;
            locationManager!.desiredAccuracy = kCLLocationAccuracyBest;
        }
        locationManager!.startUpdatingLocation()
        alreadyCalled = false

    }
    
    private var alreadyCalled = false
    public final func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        if !alreadyCalled, let coords = locations.last?.coordinate {
            print("locationManager locations: \(locations)")
            
            locationManager?.stopUpdatingLocation()
            alreadyCalled = true
            let mapMsg = PMapMessageImpl(id: 10, sender: config.sender, coordinates: coords)
            
            self.delegate?.didStartBuildingCurrentLocationMessage?(with: coords, with: mapMsg)
            
            mapMsg.startAsynch {
                self.delegate?.didFinishBuildingCurrentLocationMessage?(with: coords, with: mapMsg)
            }
            
        }
    }
    
    /**
     
     Prepares the view for the message rendering.
     Must be called after the customizations on Parla.config and possibly
     before the messages are added.
     Anyway you can call the refreshCollection method to update the data.
     
     - Parameter dataSource: The source of data (the messages) to be added to the view.
     - Parameter delegate: An optional, but reccomanded, delegate that will be notified when the user performs certain operations.
        Please see the [ParlaViewDelegate](x-source-tag://parlaViewDelegate) protocol for a complete list of notified operations.
     
     */
    open func initialize(dataSource: ParlaViewDataSource, delegate: ParlaViewDelegate?) {

        self.dataSource = dataSource
        self.delegate = delegate
        
        Parla.config.sender = dataSource.outgoingSender()
        
//        let model = Utils.getModelNumber()
//
//        if model.0 < 10 {
//            keyboardDefaultBottomConstraintMargin = 0
//            keyboardStarterBottomMargin = 0
//        } else if model.0 > 10 && (model.1 < 5 && model.1 != 3) {
//            keyboardDefaultBottomConstraintMargin = 0
//            keyboardStarterBottomMargin = 0
//        }
        
  //      print("\(model) == c: \(keyboardDefaultBottomConstraintMargin)")
    //    print("Currently running on iPhone model \(UIDevice.current.modelName)")
        
        config.accessoryActionChooser?.delegate = self
        
        config.accessoryActionChooser?.accessoryActions = [
            .chooseVideoFromGallery :  {  self.chooseVideoFrom(source: .photoLibrary) },
            .chooseImageFromGallery : {  self.chooseImageFrom(source: .photoLibrary) },
            .pickImageFromCamera :  {  self.chooseImageFrom(source: .camera) },
            .pickVideoFromCamera :  {  self.chooseVideoFrom(source: .camera) },
            .sendPosition : { self.sendPosition() }
        ]
        
        let b = Bundle.main
        
      //  let url = Bundle(for: ParlaView.self).url(forResource: "ParlaKit", withExtension: "bundle")
       // let b = Bundle(url: url!)
      
        
        //  let b = Bundle(identifier: "org.cocoapods.ParlaKit")

        
        collectionView = UICollectionView(frame: frame, collectionViewLayout: UICollectionViewFlowLayout())
        collectionView.backgroundColor = UIColor.white
        let nib = UINib(nibName: "ParlaInputToolbar", bundle: b)
        let mainView = nib.instantiate(withOwner: nil, options: nil).first as? UIView
        
        inputToolbarContainer = mainView?.subviews[0] as? ParlaInputToolbar
        microphoneButton = mainView?.subviews[1] as? UIMicrophoneView
        
        self.addSubview(collectionView)
        self.addSubview(inputToolbarContainer!)
        self.addSubview(microphoneButton)
        
        self.bottomConstraints.append(NSLayoutConstraint(item: inputToolbarContainer, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: 0))
        
        self.bottomConstraints.append(NSLayoutConstraint(item: microphoneButton, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: 0))
        
        self.addConstraints([
            NSLayoutConstraint(item: collectionView, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: collectionView, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: collectionView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: inputToolbarContainer, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: microphoneButton, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: inputToolbarContainer, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: inputToolbarContainer, attribute: .top, relatedBy: .equal, toItem: collectionView, attribute: .bottom, multiplier: 1, constant: 0)
            ])
        self.addConstraints(bottomConstraints)

        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        self.textField = self.inputToolbarContainer?.textField
        self.sendButton = self.inputToolbarContainer?.sendButton
        self.accessoryButton = self.inputToolbarContainer?.accessoryButton
        
        textField.delegate = self
        microphoneButton.delegate = self
        sendButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onSendButtonPressed(_:))))
        accessoryButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onAccessoryButtonPressed(_:))))

        collectionView.register(UINib(nibName: incomingTextMessageXibName, bundle: b), forCellWithReuseIdentifier: incomingTextMessageReuseIdentifier)
        collectionView.register(UINib(nibName: outgoingTextMessageXibName, bundle: b), forCellWithReuseIdentifier: outgoingTextMessageReuseIdentifier)
        collectionView.register(UINib(nibName: incomingImageMessageXibName, bundle: b), forCellWithReuseIdentifier: incomingImageMessageReuseIdentifier)
        collectionView.register(UINib(nibName: outgoingImageMessageXibName, bundle: b), forCellWithReuseIdentifier: outgoingImageMessageReuseIdentifier)
        collectionView.register(UINib(nibName: incomingVideoMessageXibName, bundle: b), forCellWithReuseIdentifier: incomingVideoMessageReuseIdentifier)
        collectionView.register(UINib(nibName: outgoingVideoMessageXibName, bundle: b), forCellWithReuseIdentifier: outgoingVideoMessageReuseIdentifier)
        collectionView.register(UINib(nibName: incomingVoiceMessageXibName, bundle: b), forCellWithReuseIdentifier: incomingVoiceMessageReuseIdenfitier)
        collectionView.register(UINib(nibName: "VoiceMessageCellIncoming", bundle: b), forCellWithReuseIdentifier: voiceMessageIncomingReuseIdentifier)
        collectionView.register(UINib(nibName: "VoiceMessageCellOutgoing", bundle: b), forCellWithReuseIdentifier: voiceMessageOutgoingReuseIdentifier)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        textField.addTarget(self, action: #selector(textFieldEditingChanged(_:)), for: UIControl.Event.editingChanged)
    }
    
    @objc func textFieldEditingChanged(_ sender: Any) {
        toggleSendButton()
    }
    
    private func toggleSendButton() {
        if textField.text?.count == 0 {
            self.sendButton.hide()
            self.microphoneButton.show()
            
        } else {
            self.sendButton.show()
            self.microphoneButton.hide()
        }
    }
    
    public func voiceRecorderDidStartRecording(at url: URL, voiceRecorder: VoiceRecorder) {
        self.delegate?.didStartRecordingVoiceMessage?(atUrl: url)
    }
    
    public func voiceRecorderDidEndRecording(at url: URL, voiceRecorder: VoiceRecorder) {
        self.delegate?.didEndRecordingVoiceMessage?(atUrl: url)
    }

    @objc public final func keyboardWillShow(_ notification: NSNotification) {
        // print(notification.userInfo)
        // We need the  keyboard height
        let keyboardSize:CGSize = (notification.userInfo![UIResponder.keyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue.size
        print("keyboard size: \(keyboardSize)")
        
        bottomConstraints.forEach { $0.constant -= keyboardSize.height }
        self.collectionView.scrollToBottom(animated: true)
    }
    
    @objc public final func keyboardWillHide(_ notification: NSNotification) {
       // let keyboardSize:CGSize = (notification.userInfo![UIResponder.keyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue.size
    
        bottomConstraints.forEach { $0.constant = 0 }
    }
    

    //    override open func viewWillAppear(_ animated: Bool) {
    //        super.viewWillAppear(true)
    //
    //       // UIApplication.shared.isStatusBarHidden = false
    //    }
    
}
