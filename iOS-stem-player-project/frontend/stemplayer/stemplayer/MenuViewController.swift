import UIKit
import AVFoundation

struct SongItem: Codable
{
    let title: String
    let stems: (one: String, two: String, three: String, four: String)
    let folderPath: String
    
    enum CodingKeys: String, CodingKey
    {
        case title, stems, folderPath
    }
    
    init(title: String, stems: (one: String, two: String, three: String, four: String), folderPath: String)
    {
        self.title = title
        self.stems = stems
        self.folderPath = folderPath
    }
    
    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        folderPath = try container.decode(String.self, forKey: .folderPath)
        
        let stemsDict = try container.decode([String: String].self, forKey: .stems)
        stems = (
            one: stemsDict["one"] ?? "",
            two: stemsDict["two"] ?? "",
            three: stemsDict["three"] ?? "",
            four: stemsDict["four"] ?? ""
        )
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(folderPath, forKey: .folderPath)
        
        let stemsDict = [
            "one": stems.one,
            "two": stems.two,
            "three": stems.three,
            "four": stems.four
        ]
        try container.encode(stemsDict, forKey: .stems)
    }
}

class MenuViewController: UIViewController, UITableViewDelegate, UITableViewDataSource
{

    // MARK: - Properties
    private var titleLabel: UILabel!
    private var youtubeURLTextField: UITextField!
    private var processButton: UIButton!
    private var loadingIndicator: UIActivityIndicatorView!
    private var statusLabel: UILabel!
    private var tableView: UITableView!
    private var songs: [SongItem] = []
    
    
    
    //IMPORTANT!!!! THIS IS WHERE YOU PICK HOW TO COMMUNICATE WITH THE BACKEND.
    //Leave it as local if you are testing using the iOS simulator.
    //input your computer's ip address if you are testing from your physical iOS device. Also comment out the local baseURL on line 76.
    
    
    //If you are using your physical iOS device, add your ip address here
    //private let baseURL = "YOURIPADDRESS:5001"
    
    //If you are using the iOS simulator, this will work
    private let baseURL = "http://localhost:5001"

    
    
    
    
    private let processingManager = BackgroundProcessingManager.shared
    private var processingTimer: Timer?
    
    private let fileManager = FileManager.default
    private var documentsPath: String
    {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    }
    // MARK: - Lifecycle Methods
    override func viewDidLoad()
    {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        view.backgroundColor = UIColor(red: 245/255, green: 245/255, blue: 220/255, alpha: 1.0)
        setupUI()
        loadSavedSongs()
        startProcessingCheck()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        setupKeyboardDismissal()
        statusLabel.text = ""
        youtubeURLTextField.text = ""
        youtubeURLTextField.isEnabled = true
        processButton.isEnabled = true
        loadingIndicator.stopAnimating()
        checkProcessingQueue()
    }
    private func setupKeyboardDismissal()
    {
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false  // Allow other touch events to work
        view.addGestureRecognizer(tapGesture)
    }
    @objc private func dismissKeyboard()
    {
        view.endEditing(true)
    }
    
    
    private func startProcessingCheck()
    {
        processingTimer?.invalidate()
        processingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkProcessingQueue()
        }
    }
    
    private func checkProcessingQueue()
    {
        let queue = processingManager.getProcessingQueue()
        
        // Clear "Processing in background..." if no songs are processing
        if queue.isEmpty || !queue.contains(where: { $0.status == .processing })
        {
            DispatchQueue.main.async
            {
                if self.statusLabel.text == "Processing in background..."
                {
                    self.statusLabel.text = ""
                }
            }
        }
        
        for item in queue where item.status == .processing
        {
            checkSongStatus(sessionId: item.sessionId)
        }
        
        DispatchQueue.main.async
        {
            self.tableView.reloadData()
        }
    }
    
    private func checkSongStatus(sessionId: String)
    {
        guard let url = URL(string: "\(baseURL)/status/\(sessionId)") else { return }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String else { return }
            
            DispatchQueue.main.async
            {
                switch status
                {
                    case "ready":
                    if let title = json["title"] as? String
                    {
                        self?.processingManager.updateItemStatus(sessionId: sessionId, status: .ready, title: title)
                    }
                    case "failed":
                    self?.processingManager.updateItemStatus(sessionId: sessionId, status: .failed)
                    default:
                        break
                }
                self?.tableView.reloadData()
            }
        }
        task.resume()
    }
    
    // MARK: - UI Setup
    private func setupUI()
    {
        // Title
        titleLabel = UILabel()
        titleLabel.text = "STEM PLAYER"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .black
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // YouTube URL Input
        youtubeURLTextField = UITextField()
        youtubeURLTextField.placeholder = "Paste YouTube URL"
        youtubeURLTextField.borderStyle = .roundedRect
        youtubeURLTextField.translatesAutoresizingMaskIntoConstraints = false
        youtubeURLTextField.backgroundColor = .white
        youtubeURLTextField.layer.cornerRadius = 8
        youtubeURLTextField.layer.borderWidth = 1
        youtubeURLTextField.layer.borderColor = UIColor.black.withAlphaComponent(0.1).cgColor
        youtubeURLTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
        youtubeURLTextField.leftViewMode = .always
        view.addSubview(youtubeURLTextField)
        
        // Process Button
        processButton = UIButton(type: .system)
        processButton.setTitle("PROCESS", for: .normal)
        processButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        processButton.backgroundColor = .black
        processButton.setTitleColor(.white, for: .normal)
        processButton.layer.cornerRadius = 8
        processButton.translatesAutoresizingMaskIntoConstraints = false
        processButton.addTarget(self, action: #selector(processButtonTapped), for: .touchUpInside)
        view.addSubview(processButton)
        
        // Loading Indicator
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        
        // Status Label
        statusLabel = UILabel()
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 16)
        statusLabel.textColor = .black
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // TableView
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SongCell")
        tableView.backgroundColor = .clear
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            youtubeURLTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 60),
            youtubeURLTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            youtubeURLTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            youtubeURLTextField.heightAnchor.constraint(equalToConstant: 50),
            
            processButton.topAnchor.constraint(equalTo: youtubeURLTextField.bottomAnchor, constant: 20),
            processButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            processButton.widthAnchor.constraint(equalToConstant: 200),
            processButton.heightAnchor.constraint(equalToConstant: 50),
            
            loadingIndicator.topAnchor.constraint(equalTo: processButton.bottomAnchor, constant: 20),
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            tableView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    // MARK: - Actions and Processing
    @objc private func processButtonTapped()
    {
        guard let youtubeURL = youtubeURLTextField.text, !youtubeURL.isEmpty else {
            statusLabel.text = "Please enter a YouTube URL"
            return
        }
        
        let sessionId = UUID().uuidString
        processingManager.addToProcessingQueue(youtubeUrl: youtubeURL, sessionId: sessionId)
        
        sendYouTubeLinkToBackend(youtubeURL, sessionId: sessionId)
        
        statusLabel.text = "Processing in background..."
        youtubeURLTextField.text = ""
        tableView.reloadData()
        
        let alert = UIAlertController(
            title: "Processing Started",
            message: "You can leave the app. We'll notify you when your song is ready!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func sendYouTubeLinkToBackend(_ youtubeURL: String, sessionId: String)
    {
        guard let url = URL(string: "\(baseURL)/convert") else {
            handleError("Invalid backend URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 2400 // 30 minutes
        
        let payload: [String: Any] = [
            "youtube_url": youtubeURL,
            "session_id": sessionId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.processingManager.updateItemStatus(sessionId: sessionId, status: .failed)
                    self?.handleError(error.localizedDescription)
                }
            }
        }
        task.resume()
    }
    
    private func downloadAndPlaySong(_ item: BackgroundProcessingManager.ProcessingItem)
    {
        loadingIndicator.startAnimating()
        statusLabel.text = "Downloading stems..."
        
        let stemTypes = ["vocals", "other", "drums", "bass"]
        let group = DispatchGroup()
        var stemPaths: [String: String] = [:]
        
        let sessionDir = (documentsPath as NSString).appendingPathComponent(item.sessionId)
        try? fileManager.createDirectory(atPath: sessionDir, withIntermediateDirectories: true)
        
        for stemType in stemTypes
        {
            group.enter()
            
            guard let url = URL(string: "\(baseURL)/download/\(item.sessionId)/\(stemType)") else {
                group.leave()
                continue
            }
            
            // Changed file extension from wav to mp3
            let destinationPath = (sessionDir as NSString).appendingPathComponent("\(stemType).mp3")
            
            URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
                defer { group.leave() }
                
                if let tempURL = tempURL
                {
                    try? self?.fileManager.removeItem(atPath: destinationPath)
                    try? self?.fileManager.moveItem(at: tempURL, to: URL(fileURLWithPath: destinationPath))
                    stemPaths[stemType] = destinationPath
                }
            }.resume()
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            let songItem = SongItem(
                title: item.title ?? "Untitled",
                stems: (
                    one: stemPaths["vocals"] ?? "",
                    two: stemPaths["other"] ?? "",
                    three: stemPaths["drums"] ?? "",
                    four: stemPaths["bass"] ?? ""
                ),
                folderPath: sessionDir
            )
            
            self.saveSong(songItem)
            self.processingManager.removeFromQueue(sessionId: item.sessionId)
            self.loadingIndicator.stopAnimating()
            
            // Clear status label only if no other songs are processing
            let remainingQueue = self.processingManager.getProcessingQueue()
            if remainingQueue.isEmpty || !remainingQueue.contains(where: { $0.status == .processing }) {
                self.statusLabel.text = ""
            }
            
            self.tableView.reloadData()
            self.navigateToStemPlayer(with: songItem)
            self.cleanupServerFiles(sessionId: item.sessionId)
        }
    }
    
    private func cleanupServerFiles(sessionId: String)
    {
        guard let url = URL(string: "\(baseURL)/cleanup/\(sessionId)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request).resume()
    }
    // MARK: - Helper Methods
    private func handleError(_ message: String)
    {
        loadingIndicator.stopAnimating()
        processButton.isEnabled = true
        youtubeURLTextField.isEnabled = true
        statusLabel.text = "Error: \(message)"
    }
    
    private func navigateToStemPlayer(with songItem: SongItem)
    {
        loadingIndicator.stopAnimating()
        statusLabel.text = ""
        
        let stemPlayerVC = ViewController()
        stemPlayerVC.passedWord = songItem.stems.one
        stemPlayerVC.passedWordTwo = songItem.stems.two
        stemPlayerVC.passedWordThree = songItem.stems.three
        stemPlayerVC.passedWordFour = songItem.stems.four
        stemPlayerVC.songFolderPath = songItem.folderPath
        
        navigationController?.pushViewController(stemPlayerVC, animated: true)
    }
    
    // MARK: - Song Storage Methods
    private func saveSong(_ song: SongItem)
    {
        songs.insert(song, at: 0)
        saveSongsToStorage()
        tableView.reloadData()
    }
    
    private func loadSavedSongs()
    {
        let songsPath = (documentsPath as NSString).appendingPathComponent("saved_songs.json")
        
        if let data = try? Data(contentsOf: URL(fileURLWithPath: songsPath)),
           let decodedSongs = try? JSONDecoder().decode([SongItem].self, from: data)
        {
            songs = decodedSongs
        }
    }
    
    private func saveSongsToStorage()
    {
        let songsPath = (documentsPath as NSString).appendingPathComponent("saved_songs.json")
        
        if let encodedData = try? JSONEncoder().encode(songs) {
            try? encodedData.write(to: URL(fileURLWithPath: songsPath))
        }
    }
    
    // MARK: - TableView DataSource & Delegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return songs.count + processingManager.getProcessingQueue().count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SongCell", for: indexPath)
        cell.backgroundColor = .clear
        
        let processingItems = processingManager.getProcessingQueue()
        
        if indexPath.row < processingItems.count
        {
            let item = processingItems[indexPath.row]
            cell.textLabel?.text = item.title ?? "Processing..."
            
            switch item.status
            {
                case .processing:
                    cell.detailTextLabel?.text = "Processing..."
                    cell.isUserInteractionEnabled = false
                    cell.textLabel?.textColor = .gray
                case .ready:
                    cell.detailTextLabel?.text = "Ready - Tap to download"
                    cell.isUserInteractionEnabled = true
                    cell.textLabel?.textColor = .black
                case .failed:
                    cell.detailTextLabel?.text = "Failed"
                    cell.isUserInteractionEnabled = false
                    cell.textLabel?.textColor = .red
            }
        }
        else
        {
            let songIndex = indexPath.row - processingItems.count
            let song = songs[songIndex]
            cell.textLabel?.text = song.title
            cell.detailTextLabel?.text = nil
            cell.isUserInteractionEnabled = true
            cell.textLabel?.textColor = .black
        }
        
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
            tableView.deselectRow(at: indexPath, animated: true)
            
            let processingItems = processingManager.getProcessingQueue()
            
            if indexPath.row < processingItems.count
            {
                let item = processingItems[indexPath.row]
                if item.status == .ready
                {
                    downloadAndPlaySong(item)
                }
            }
            else
            {
                let songIndex = indexPath.row - processingItems.count
                let song = songs[songIndex]
                
                // Verify files exist before navigating
                let stemFiles = [song.stems.one, song.stems.two, song.stems.three, song.stems.four]
                let missingFiles = stemFiles.filter { !FileManager.default.fileExists(atPath: $0) }
                
                if !missingFiles.isEmpty
                {
                    let alert = UIAlertController(
                        title: "Error Loading Song",
                        message: "Some audio files are missing. The song may need to be reprocessed.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                        // Remove corrupted song entry
                        self?.songs.remove(at: songIndex)
                        self?.saveSongsToStorage()
                        tableView.deleteRows(at: [IndexPath(row: indexPath.row, section: 0)], with: .fade)
                    })
                    present(alert, animated: true)
                    return
                }
                
                navigateToStemPlayer(with: song)
            }
    }
        
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath)
    {
            if editingStyle == .delete
            {
                let processingItems = processingManager.getProcessingQueue()
                
                if indexPath.row < processingItems.count
                {
                    let item = processingItems[indexPath.row]
                    processingManager.removeFromQueue(sessionId: item.sessionId)
                }
                else
                {
                    let songIndex = indexPath.row - processingItems.count
                    let songToDelete = songs[songIndex]
                    try? FileManager.default.removeItem(atPath: songToDelete.folderPath)
                    songs.remove(at: songIndex)
                    saveSongsToStorage()
                }
                
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
    }
        
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration?
    {
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete")
            { [weak self] (action, view, completionHandler) in
                guard let self = self else { return }
                
                let processingItems = self.processingManager.getProcessingQueue()
                
                if indexPath.row < processingItems.count
                {
                    let item = processingItems[indexPath.row]
                    self.processingManager.removeFromQueue(sessionId: item.sessionId)
                }
                else
                {
                    let songIndex = indexPath.row - processingItems.count
                    let songToDelete = self.songs[songIndex]
                    try? FileManager.default.removeItem(atPath: songToDelete.folderPath)
                    self.songs.remove(at: songIndex)
                    self.saveSongsToStorage()
                }
                
                tableView.deleteRows(at: [indexPath], with: .fade)
                completionHandler(true)
            }
            
            deleteAction.backgroundColor = .systemRed
            
            let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
            configuration.performsFirstActionWithFullSwipe = true
            return configuration
    }
}
