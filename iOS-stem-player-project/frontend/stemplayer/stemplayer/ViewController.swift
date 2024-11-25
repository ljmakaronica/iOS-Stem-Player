import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    private var timeLeft: UILabel!
    private var timePassed: UILabel!
    private var scrubSlider: UISlider!
    
    private var audioQueue = DispatchQueue(label: "com.app.audioQueue")
    private var playerStartTime: TimeInterval = 0
    private var hostTime: TimeInterval = 0
    
    private var isScrubbing = false

    // Properties to receive from MenuViewController
    var passedWord: String = ""
    var passedWordTwo: String = ""
    var passedWordThree: String = ""
    var passedWordFour: String = ""
    var songFolderPath: String = ""
    
    var buttonAudioPlayerOne: AVAudioPlayer!
    var buttonAudioPlayerTwo: AVAudioPlayer!
    var buttonAudioPlayerThree: AVAudioPlayer!
    var buttonAudioPlayerFour: AVAudioPlayer!
    var isItPlaying = 0
    private var currentTime: TimeInterval = 0
    
    private var sliderVolumes: [Float] = [1.0, 1.0, 1.0, 1.0]
    private var tracksMutedByButton: [Bool] = [false, false, false, false]
    
    private var sliders: [UIView] = []
    private var buttons: [UIButton] = []
    private var sliderTracks: [UIView] = []
    private var indicators: [UIView] = []
    private var playButton: UIButton!
    private var devicePanel: UIView!
    private var backButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure audio session for better synchronization
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        
        view.backgroundColor = UIColor(red: 245/255, green: 245/255, blue: 220/255, alpha: 1.0)
        
        setupInterface()
        setupAudioPlayers()
        setupBackButton()
        setupScrubber()
        startTimer()
    }
    
    private func setupInterface() {
            devicePanel = UIView()
            
            // Calculate devicePanel size to fill screen above scrubber
            let scrubberHeight: CGFloat = 40
            let bottomPadding: CGFloat = view.bounds.height * 0.15 // Space for scrubber
            let topPadding: CGFloat = 100 // Space for back button and status bar
            
            let panelHeight = view.bounds.height - bottomPadding - topPadding
            let panelWidth = min(view.bounds.width * 0.95, 600) // Cap max width, use 95% of screen width
            
            devicePanel.frame = CGRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
            devicePanel.center = CGPoint(x: view.bounds.width / 2,
                                       y: topPadding + (panelHeight / 2))
            
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = devicePanel.bounds
            gradientLayer.colors = [
                UIColor(white: 0.95, alpha: 1.0).cgColor,
                UIColor(white: 0.90, alpha: 1.0).cgColor
            ]
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
            devicePanel.layer.addSublayer(gradientLayer)
            
            let rightBezel = UIView()
            rightBezel.frame = CGRect(x: devicePanel.bounds.width - 20,
                                    y: 0,
                                    width: 20,
                                    height: devicePanel.bounds.height)
            rightBezel.backgroundColor = UIColor(white: 0.85, alpha: 1.0)
            
            let triangleView = UIView()
            triangleView.frame = CGRect(x: 5, y: 10, width: 8, height: 8)
            let trianglePath = UIBezierPath()
            trianglePath.move(to: CGPoint(x: 0, y: 8))
            trianglePath.addLine(to: CGPoint(x: 8, y: 8))
            trianglePath.addLine(to: CGPoint(x: 4, y: 0))
            trianglePath.close()
            
            let triangleLayer = CAShapeLayer()
            triangleLayer.path = trianglePath.cgPath
            triangleLayer.fillColor = UIColor.red.cgColor
            triangleView.layer.addSublayer(triangleLayer)
            
            rightBezel.addSubview(triangleView)
            devicePanel.addSubview(rightBezel)
            
            view.addSubview(devicePanel)
            setupSliders(on: devicePanel)
        }
   

    private func setupScrubber() {
        let scrubberContainer = UIView()
        scrubberContainer.frame = CGRect(x: 20,
                                       y: view.bounds.height * 0.85,
                                       width: view.bounds.width - 40,
                                       height: 40)
        view.addSubview(scrubberContainer)
        
        timePassed = UILabel()
        timePassed.frame = CGRect(x: 0, y: 10, width: 45, height: 20)
        timePassed.font = .systemFont(ofSize: 12, weight: .medium)
        timePassed.textColor = UIColor(white: 0.3, alpha: 1.0)
        timePassed.text = "00:00"
        timePassed.textAlignment = .left
        scrubberContainer.addSubview(timePassed)
        
        timeLeft = UILabel()
        timeLeft.frame = CGRect(x: scrubberContainer.bounds.width - 45,
                               y: 10,
                               width: 45,
                               height: 20)
        timeLeft.font = .systemFont(ofSize: 12, weight: .medium)
        timeLeft.textColor = UIColor(white: 0.3, alpha: 1.0)
        timeLeft.text = "00:00"
        timeLeft.textAlignment = .right
        scrubberContainer.addSubview(timeLeft)
        
        scrubSlider = UISlider()
        scrubSlider.frame = CGRect(x: 55,
                                  y: 10,
                                  width: scrubberContainer.bounds.width - 110,
                                  height: 20)
        
        // Set initial slider values
        scrubSlider.minimumValue = 0
        scrubSlider.maximumValue = Float(buttonAudioPlayerOne?.duration ?? 0)
        scrubSlider.value = 0
        
        // Update to use the same red color
        let redColor = UIColor.red
        scrubSlider.minimumTrackTintColor = redColor
        scrubSlider.maximumTrackTintColor = UIColor(white: 0.85, alpha: 1.0)
        
        let thumbSize: CGFloat = 12
        let thumbView = UIView(frame: CGRect(x: 0, y: 0, width: thumbSize, height: thumbSize))
        thumbView.backgroundColor = .white
        thumbView.layer.cornerRadius = thumbSize/2
        
        thumbView.layer.shadowColor = UIColor.black.cgColor
        thumbView.layer.shadowOffset = CGSize(width: 0, height: 1)
        thumbView.layer.shadowOpacity = 0.2
        thumbView.layer.shadowRadius = 1
        
        let renderer = UIGraphicsImageRenderer(bounds: thumbView.bounds)
        let thumbImage = renderer.image { context in
            thumbView.layer.render(in: context.cgContext)
        }
        
        scrubSlider.setThumbImage(thumbImage, for: .normal)
        scrubSlider.setThumbImage(thumbImage, for: .highlighted)
        
        scrubSlider.addTarget(self, action: #selector(scrubberValueChanged(_:)), for: .valueChanged)
        scrubSlider.addTarget(self, action: #selector(scrubberTouchBegan(_:)), for: .touchDown)
        scrubSlider.addTarget(self, action: #selector(scrubberTouchEnded(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        scrubberContainer.addSubview(scrubSlider)
    }

    private func setupBackButton() {
        backButton = UIButton(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        backButton.center = CGPoint(x: 40, y: 70)
        
        backButton.backgroundColor = UIColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 1.0)
        backButton.layer.cornerRadius = 20
        
        backButton.layer.shadowColor = UIColor(red: 1.0, green: 0.9, blue: 0.8, alpha: 1.0).cgColor
        backButton.layer.shadowOpacity = 0.5
        backButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        backButton.layer.shadowRadius = 6
        
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let arrowImage = UIImage(systemName: "chevron.left", withConfiguration: symbolConfig)?
            .withTintColor(.black, renderingMode: .alwaysOriginal)
        backButton.setImage(arrowImage, for: .normal)
        
        backButton.addTarget(self, action: #selector(backButtonPressed), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(backButtonTouchDown), for: .touchDown)
        backButton.addTarget(self, action: #selector(backButtonTouchUp), for: [.touchUpOutside, .touchCancel])
        
        view.addSubview(backButton)
    }

    private func setupSliders(on devicePanel: UIView) {
        let sliderWidth: CGFloat = devicePanel.bounds.width * 0.07 // Width for the track
        let sliderHeight: CGFloat = devicePanel.bounds.height * 0.4 // Height for the track
        let spacing: CGFloat = devicePanel.bounds.width * 0.15
        let totalWidth = (sliderWidth * 4) + (spacing * 3)
        let startX = (devicePanel.bounds.width - totalWidth) / 2
        let startY = devicePanel.bounds.height * 0.12
        
        let verticalSpacing = devicePanel.bounds.height * 0.08

        for i in 0..<4 {
            let trackView = UIView()
            trackView.frame = CGRect(x: startX + CGFloat(i) * (sliderWidth + spacing),
                                   y: startY,
                                   width: sliderWidth,
                                   height: sliderHeight)
            
            // Create the track background (slot)
            let slotBg = UIView(frame: trackView.bounds)
            slotBg.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
            slotBg.layer.cornerRadius = sliderWidth / 2 // Make the track rounded
            slotBg.clipsToBounds = true // Ensure the track stays contained
            
            // Add inner shadow to track
            let innerShadow = CALayer()
            innerShadow.frame = slotBg.bounds
            innerShadow.backgroundColor = UIColor.black.cgColor
            innerShadow.opacity = 0.2
            innerShadow.cornerRadius = sliderWidth / 2 // Match the track corner radius
            slotBg.layer.addSublayer(innerShadow)
            
            trackView.addSubview(slotBg)
            
            // Create the circular handle
            let handleSize = sliderWidth - 2 // Slightly smaller than track width
            let handle = UIView(frame: CGRect(x: 0, y: 0,
                                            width: handleSize,
                                            height: handleSize))
            handle.center.x = trackView.bounds.width / 2
            handle.center.y = trackView.bounds.minY + (handleSize / 2)
            handle.layer.cornerRadius = handleSize / 2 // Make handle circular
            handle.backgroundColor = .white
            
            // Add subtle gradient to handle
            let handleGradient = CAGradientLayer()
            handleGradient.frame = handle.bounds
            handleGradient.cornerRadius = handleSize / 2 // Match handle corner radius
            handleGradient.colors = [
                UIColor(white: 1.0, alpha: 1.0).cgColor,
                UIColor(white: 0.95, alpha: 1.0).cgColor
            ]
            handle.layer.addSublayer(handleGradient)
            
            // Add shadow to handle
            handle.layer.shadowColor = UIColor.black.cgColor
            handle.layer.shadowOffset = CGSize(width: 0, height: 1)
            handle.layer.shadowOpacity = 0.2
            handle.layer.shadowRadius = 1
            
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleSliderPan(_:)))
            handle.addGestureRecognizer(panGesture)
            handle.isUserInteractionEnabled = true
            
            trackView.addSubview(handle)
            
            // Create indicator
            let indicator = UIView()
            indicator.frame = CGRect(x: trackView.frame.minX + (sliderWidth - 4) / 2,
                                   y: trackView.frame.maxY + verticalSpacing,
                                   width: 4,
                                   height: 4)
            indicator.layer.cornerRadius = 2
            indicator.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
            indicator.layer.shadowOpacity = 0
            
            
            
            // Create button
            let button = UIButton(type: .custom)
            button.frame = CGRect(x: trackView.frame.minX,
                                y: indicator.frame.maxY + verticalSpacing,
                                width: sliderWidth,
                                height: 70)
            button.backgroundColor = .white
            button.layer.cornerRadius = 1
            
            let buttonGradient = CAGradientLayer()
            buttonGradient.frame = button.bounds
            buttonGradient.colors = [
                UIColor(white: 1.0, alpha: 1.0).cgColor,
                UIColor(white: 0.95, alpha: 1.0).cgColor
            ]
            button.layer.addSublayer(buttonGradient)
            
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleButtonLongPress(_:)))
            button.addGestureRecognizer(longPress)
            button.addTarget(self, action: #selector(controlButtonTapped(_:)), for: .touchUpInside)
            button.tag = i
            
            devicePanel.addSubview(trackView)
            devicePanel.addSubview(indicator)
            devicePanel.addSubview(button)
            
            sliderTracks.append(trackView)
            sliders.append(handle)
            buttons.append(button)
            indicators.append(indicator)
        }
        setupPlayButton(lastButtonY: buttons.last?.frame.maxY ?? devicePanel.bounds.height * 0.7)
    }
    private func setupPlayButton(lastButtonY: CGFloat) {
           playButton = UIButton(type: .custom)
           let playButtonSize = devicePanel.bounds.width * 0.15 // 15% of panel width
           playButton.frame = CGRect(x: 0, y: 0, width: playButtonSize, height: playButtonSize)
           
           // Position play button with proper spacing
           let verticalSpacing = devicePanel.bounds.height * 0.08
           playButton.center = CGPoint(x: devicePanel.bounds.width / 2,
                                     y: lastButtonY + verticalSpacing + (playButtonSize / 2))
           
           playButton.backgroundColor = UIColor(white: 1.0, alpha: 1.0)
           playButton.layer.cornerRadius = 3
           playButton.layer.shadowColor = UIColor.black.cgColor
           playButton.layer.shadowOffset = CGSize(width: 0, height: 2)
           playButton.layer.shadowOpacity = 0.15
           playButton.layer.shadowRadius = 2
           
           playButton.addTarget(self, action: #selector(playButtonPressed), for: .touchUpInside)
           devicePanel.addSubview(playButton)
       }

    private func setupAudioPlayers()
    {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                
                func setupPlayer(with path: String) throws -> AVAudioPlayer? {
                    let url = URL(fileURLWithPath: path)
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    player.numberOfLoops = 0
                    return player
                }
                
                buttonAudioPlayerOne = try setupPlayer(with: passedWord)
                buttonAudioPlayerTwo = try setupPlayer(with: passedWordTwo)
                buttonAudioPlayerThree = try setupPlayer(with: passedWordThree)
                buttonAudioPlayerFour = try setupPlayer(with: passedWordFour)
                
                // Ensure all players are properly prepared
                [buttonAudioPlayerOne, buttonAudioPlayerTwo, buttonAudioPlayerThree, buttonAudioPlayerFour].forEach { player in
                    player?.prepareToPlay()
                }
                
            }
            catch
            {
                print("Error setting up audio players: \(error.localizedDescription)")
            }
        }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  !self.isScrubbing else { return }
            
            if let player = self.buttonAudioPlayerOne {
                // Update slider maximum value in case duration wasn't properly set initially
                self.scrubSlider.maximumValue = Float(player.duration)
                
                // Update slider value with current playback time
                self.scrubSlider.value = Float(player.currentTime)
                
                self.updateTimeDisplay()
                
                // Check if playback has finished
                if !player.isPlaying && self.isItPlaying == 1 {
                    DispatchQueue.main.async {
                        self.isItPlaying = 0
                        self.updatePlayButtonState()
                    }
                }
            }
        }
    }
                
    private func updateTimeDisplay() {
        guard let player = buttonAudioPlayerOne else { return }
        
        let duration = player.duration
        let currentTime = player.currentTime
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.timePassed?.text = self.formatTime(currentTime)
            self.timeLeft?.text = self.formatTime(duration - currentTime)
        }
    }

                private func formatTime(_ time: TimeInterval) -> String {
                    let minutes = Int(time) / 60
                    let seconds = Int(time) % 60
                    return String(format: "%02d:%02d", minutes, seconds)
                }
                
    private func updatePlayButtonState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Set color and size based on the isPlaying state
            let isPlaying = self.isItPlaying == 1
            
            // Use white color when paused, grayish color when playing
            self.playButton.backgroundColor = isPlaying ?
            UIColor(white: 0.97, alpha: 1.0) : // Grayish when playing
            UIColor(white: 1.00, alpha: 1.0)// Light Grayish when paused

            UIView.animate(withDuration: 0.2) {
                // Shrink when playing, return to normal size when paused
                self.playButton.transform = isPlaying ?
                    CGAffineTransform(scaleX: 0.95, y: 0.95) : // Shrink slightly when playing
                    CGAffineTransform.identity // Original size when paused
            }
        }
    }

                
                @objc private func scrubberValueChanged(_ sender: UISlider) {
                    let time = TimeInterval(sender.value)
                    timePassed.text = formatTime(time)
                    timeLeft.text = formatTime(buttonAudioPlayerOne?.duration ?? 0 - time)
                }
                
                @objc private func scrubberTouchBegan(_ sender: UISlider) {
                    isScrubbing = true
                }
                
    @objc private func scrubberTouchEnded(_ sender: UISlider) {
        isScrubbing = false
        let newTime = TimeInterval(sender.value)
        let wasPlaying = isItPlaying == 1  // Capture the state before any changes
        
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Store the new time position
            self.currentTime = newTime
            
            let players = [
                self.buttonAudioPlayerOne,
                self.buttonAudioPlayerTwo,
                self.buttonAudioPlayerThree,
                self.buttonAudioPlayerFour
            ].compactMap { $0 }
            
            // Always pause first to ensure clean state
            players.forEach { player in
                player.pause()
                player.currentTime = newTime
                player.prepareToPlay()
            }
            
            // If it was playing before scrubbing, resume playback
            if wasPlaying {
                // Ensure isItPlaying is set correctly before calling playSound
                DispatchQueue.main.async {
                    self.isItPlaying = 1
                    self.updatePlayButtonState()
                    self.playSound()
                }
            } else {
                // Update UI state if it was paused
                DispatchQueue.main.async {
                    self.isItPlaying = 0
                    self.updatePlayButtonState()
                }
            }
        }
    }
    @objc private func handleButtonLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let button = gesture.view as? UIButton else { return }
        let selectedIndex = button.tag
        
        if gesture.state == .began {
            // Mute and visually move all other sliders to the bottom with animation
            for (index, _) in buttons.enumerated() {
                if index != selectedIndex {
                    // Store the volume and set slider to 0 only if the track was not muted
                    if !tracksMutedByButton[index] {
                        setPlayerVolume(tag: index, volume: 0)
                        updateSliderPosition(forTrack: index, volume: 0.0, animated: true) // Move slider to bottom with animation
                    }
                    updateIndicatorAndButton(forTrack: index, forceDim: true)
                }
            }
        } else if gesture.state == .ended || gesture.state == .cancelled {
            // Restore previous volume and slider position for all other tracks with animation
            for (index, _) in buttons.enumerated() {
                if index != selectedIndex {
                    if tracksMutedByButton[index] {
                        // Keep muted track at volume 0
                        setPlayerVolume(tag: index, volume: 0)
                        updateSliderPosition(forTrack: index, volume: 0.0, animated: true) // Keep slider at bottom with animation
                    } else {
                        // Restore the volume and slider position for unmuted tracks
                        setPlayerVolume(tag: index, volume: sliderVolumes[index])
                        updateSliderPosition(forTrack: index, volume: sliderVolumes[index], animated: true) // Restore position with animation
                    }
                    updateIndicatorAndButton(forTrack: index)
                }
            }
        }
    }



    private func updateSliderPosition(forTrack index: Int, volume: Float, animated: Bool = false) {
        let trackView = sliderTracks[index]
        let handle = sliders[index]
        
        let minY = trackView.bounds.minY + (handle.bounds.height / 2) // Top position
        let maxY = trackView.bounds.maxY - (handle.bounds.height / 2) // Bottom position
        let range = maxY - minY
        
        let newY = maxY - CGFloat(volume) * range // Calculate position based on volume
        
        if animated {
            UIView.animate(withDuration: 0.3) {
                handle.center.y = newY
            }
        } else {
            handle.center.y = newY
        }
    }

    @objc private func handleSliderPan(_ gesture: UIPanGestureRecognizer) {
            guard let handle = gesture.view,
                  let trackView = handle.superview,
                  let index = sliderTracks.firstIndex(of: trackView) else { return }
            
            if tracksMutedByButton[index] { return }
            
            let translation = gesture.translation(in: trackView)
            let newY = handle.center.y + translation.y
            
            // Adjust these values to ensure full range of motion
            let minY = trackView.bounds.minY + (handle.bounds.height / 2)  // Top position
            let maxY = trackView.bounds.maxY - (handle.bounds.height / 2)  // Bottom position
            let boundedY = max(min(newY, maxY), minY)
            
            handle.center.y = boundedY
            gesture.setTranslation(.zero, in: trackView)
            
            // Calculate volume (inverted because slider goes top to bottom)
            let range = maxY - minY
            let volume = 1.0 - ((boundedY - minY) / range)
            let normalizedVolume = Float(max(min(volume, 1.0), 0.0))  // Ensure volume is between 0 and 1
            
            sliderVolumes[index] = normalizedVolume
            
            if !tracksMutedByButton[index] {
                setPlayerVolume(tag: index, volume: normalizedVolume)
            }
            
            updateIndicatorAndButton(forTrack: index)
        }
                
    @objc private func controlButtonTapped(_ button: UIButton) {
        let index = button.tag
        
        if sliderVolumes[index] == 0 { return }
        
        tracksMutedByButton[index] = !tracksMutedByButton[index]
        
        if tracksMutedByButton[index] {
            // Set slider to bottom visually by setting volume to 0
            setPlayerVolume(tag: index, volume: 0)
            updateSliderPosition(forTrack: index, volume: 0.0, animated: true) // Move slider to bottom with animation
        } else {
            // Restore previous volume from sliderVolumes
            setPlayerVolume(tag: index, volume: sliderVolumes[index])
            updateSliderPosition(forTrack: index, volume: sliderVolumes[index], animated: true) // Restore position with animation
        }
        
        updateIndicatorAndButton(forTrack: index)
    }


                
                @objc private func backButtonPressed() {
                    UIView.animate(withDuration: 0.2) {
                        self.backButton.transform = .identity
                    } completion: { _ in
                        self.navigationController?.popViewController(animated: true)
                    }
                }

                @objc private func backButtonTouchDown() {
                    UIView.animate(withDuration: 0.2) {
                        self.backButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                    }
                }

                @objc private func backButtonTouchUp() {
                    UIView.animate(withDuration: 0.2) {
                        self.backButton.transform = .identity
                    }
                }
                
    @objc private func playButtonPressed() {
        if isItPlaying == 1 {
            isItPlaying = 0
            pauseSound()
        } else {
            isItPlaying = 1
            playSound()
        }
        updatePlayButtonState() // Keep this for immediate UI feedback
    }
                
    private func playSound() {
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            let players = [
                self.buttonAudioPlayerOne,
                self.buttonAudioPlayerTwo,
                self.buttonAudioPlayerThree,
                self.buttonAudioPlayerFour
            ].compactMap { $0 }
            
            // Make sure all players are at the correct position
            players.forEach { player in
                player.currentTime = self.currentTime
                player.prepareToPlay()
            }
            
            // Set the start time for all players
            self.playerStartTime = players.first?.deviceCurrentTime ?? 0
            self.hostTime = CACurrentMediaTime()
            
            // Start all players together
            let startTime = self.playerStartTime + 0.01
            players.forEach { player in
                player.play(atTime: startTime)
            }
        }
    }

    private func pauseSound() {
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.currentTime = self.buttonAudioPlayerOne?.currentTime ?? 0
            
            // Pause all players simultaneously
            [
                self.buttonAudioPlayerOne,
                self.buttonAudioPlayerTwo,
                self.buttonAudioPlayerThree,
                self.buttonAudioPlayerFour
            ].compactMap { $0 }
            .forEach { player in
                player.pause()
            }
        }
    }
                
    private func updateIndicatorAndButton(forTrack index: Int, forceDim: Bool = false) {
        let isMuted = tracksMutedByButton[index] || sliderVolumes[index] == 0 || forceDim
        let indicator = indicators[index]
        let button = buttons[index]
        
        if isMuted {
            // Track is muted (light is on)
            indicator.backgroundColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.8)  // LED red
            indicator.layer.shadowOpacity = 0.8
            indicator.layer.shadowRadius = 5  // Add a glow effect
            indicator.layer.shadowColor = UIColor.red.cgColor  // Glow color
            indicator.layer.shadowOffset = CGSize(width: 0, height: 0)  // No offset for the glow
            
        } else {
            // Light is off (track is on)
            indicator.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
            indicator.layer.shadowOpacity = 0
        }
        
        // Update button appearance
        button.backgroundColor = isMuted ?
            UIColor(white: 0.95, alpha: 1.0) :
            UIColor(white: 1.0, alpha: 1.0)
    }

                
                private func setPlayerVolume(tag: Int, volume: Float) {
                    switch tag {
                    case 0: buttonAudioPlayerOne?.volume = volume
                    case 1: buttonAudioPlayerTwo?.volume = volume
                    case 2: buttonAudioPlayerThree?.volume = volume
                    case 3: buttonAudioPlayerFour?.volume = volume
                    default: break
                    }
                }
            }
