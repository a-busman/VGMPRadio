//
//  SongListViewController.swift
//  VGMPRadio
//
//  Created by Alex Busman on 1/13/18.
//  Copyright © 2018 Alex Busman. All rights reserved.
//

import UIKit
import Alamofire
import CoreData

protocol SongListViewControllerDelegate {
    func songSelected(playlist: Playlist, songIndex: Int, playlistIndex: Int, play: Bool)
    func shuffleTapped(playlist: Playlist, playlistIndex: Int)
    
}

class SongListViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var songActivityIndicator: UIActivityIndicatorView?
    @IBOutlet weak var addToPlaylistLabel: UILabel?
    
    private var playlistCollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout())
    private var playlistVEView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private var playlistActivityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .white)
    private var playlists: [Playlist] = []
    private var filteredSongs: [Song] = []
    private var selectedPlaylistIndex: Int = 0
    private var currentlyPlayingSong: Int = -1
    private var currentlyPlayingPlaylist: Int = -1
    private let logoView = UIImageView(image: #imageLiteral(resourceName: "vgmp_logo"))
    private let refreshControl = UIRefreshControl()
    private let searchController = UISearchController(searchResultsController: nil)
    private struct Const {
        /// Image height/width for Large NavBar state
        static let ImageSizeForLargeState: CGFloat = 80
        /// Margin from right anchor of safe area to right anchor of Image
        static let ImageLeftMargin: CGFloat = 16
        /// Margin from bottom anchor of NavBar to bottom anchor of Image for Large NavBar state
        static let ImageBottomMarginForLargeState: CGFloat = 12
        /// Margin from bottom anchor of NavBar to bottom anchor of Image for Small NavBar state
        static let ImageBottomMarginForSmallState: CGFloat = 6
        /// Image height/width for Small NavBar state
        static let ImageSizeForSmallState: CGFloat = 36.5
        /// Height of NavBar for Small state. Usually it's just 44
        static let NavBarHeightSmallState: CGFloat = 44
        /// Height of NavBar for Large state. Usually it's just 96.5 but if you have a custom font for the title, please make sure to edit this value since it changes the height for Large state of NavBar
        static let NavBarHeightLargeState: CGFloat = 96.5
    }
    
    private var _currentTheme: Theme = .dark
    
    var theme: Theme {
        set(newValue) {
            self._currentTheme = newValue
            if newValue == .light {
                self.tableView?.separatorColor = .lightGray
                self.navigationController?.navigationBar.barStyle = .default
                self.songActivityIndicator?.color = .black
                self.playlistActivityIndicator.activityIndicatorViewStyle = .gray
                self.tableView?.backgroundColor = .white
                self.playlistVEView.effect = UIBlurEffect(style: .extraLight)
                self.tableView?.indicatorStyle = .black
                self.addToPlaylistLabel?.textColor = .darkGray
            } else {
                self.tableView?.separatorColor = .white
                self.songActivityIndicator?.activityIndicatorViewStyle = .whiteLarge
                self.playlistActivityIndicator.activityIndicatorViewStyle = .white
                self.navigationController?.navigationBar.barStyle = .black
                self.playlistVEView.effect = UIBlurEffect(style: .dark)
                self.tableView?.backgroundColor = .darkGray
                self.tableView?.indicatorStyle = .white
                self.addToPlaylistLabel?.textColor = .lightGray
            }
            self.tableView?.reloadData()
            self.playlistCollectionView.reloadData()
        }
        get {
            return self._currentTheme
        }
    }
    
    var delegate: SongListViewControllerDelegate?
    
    var isPlaying: Bool = false
    var isStopped: Bool = true
    
    private var _firstLoad: Bool = true
    
    let songTableReuseIdentifier = "song_cell"
    let playlistCollectionReuseIdentifier = "playlist_cell"

    override func viewDidLoad() {
        super.viewDidLoad()
        self.playlistActivityIndicator.hidesWhenStopped = true
        self.songActivityIndicator?.startAnimating()
        let currentPlaylist = self.selectedPlaylistIndex
        
        let managedContext = Util.getManagedContext()
        
        let fetchRequest = NSFetchRequest<Playlist>(entityName: "Playlist")
        
        do {
            let playlists = try managedContext?.fetch(fetchRequest) ?? []
            self.playlists = try playlists.sorted(by: VGMPRadio.playlistSort)
        } catch let error as NSError {
            NSLog("Could not fetch. \(error), \(error.userInfo)")
        }
        if self.playlists.count > 0 {
            self.playlistActivityIndicator.stopAnimating()
            self.songActivityIndicator?.stopAnimating()
            VGMPRadio.getSongs(playlist: self.playlists[0], index: 0, getNext: true, withCompletion: self.songsCompletionHandler)
        }
        VGMPRadio.getPlaylists {
            results in
            DispatchQueue.main.async {
                self.playlistActivityIndicator.stopAnimating()
            }
            if let error = results.error {
                NSLog("Error getting playlists: \(error.localizedDescription)")
                return
            }
            if let playlists = results.value {
                self.playlists = playlists
                DispatchQueue.main.sync {
                    self.playlistCollectionView.reloadData()
                    if (self.playlists[currentPlaylist].songs?.count ?? 0) == 0 {
                        VGMPRadio.getSongs(playlist: playlists[currentPlaylist], index: currentPlaylist, getNext: false, withCompletion: self.songsCompletionHandler)
                    }
                }
            }
        }
        self.setupTableView()
        self.setupPlaylistSelection()
        self.setupUI()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewDidLayoutSubviews() {
        if self._firstLoad {
            self.tableView?.refreshControl = self.refreshControl
            if self.playlists.count == 0 || (self.playlists[self.selectedPlaylistIndex].songs?.count ?? 0 == 0 && self.selectedPlaylistIndex == 0) {
                self.addToPlaylistLabel?.isHidden = false
            } else {
                self.addToPlaylistLabel?.isHidden = true
            }
            if self._currentTheme == .light {
                self.tableView?.separatorColor = .lightGray
                self.tableView?.backgroundColor = .white
                self.playlistVEView.effect = UIBlurEffect(style: .extraLight)
                self.songActivityIndicator?.color = .gray
                self.tableView?.indicatorStyle = .black
                self.addToPlaylistLabel?.textColor = .darkGray
            } else {
                self.tableView?.separatorColor = .white
                self.playlistVEView.effect = UIBlurEffect(style: .dark)
                self.tableView?.backgroundColor = .darkGray
                self.tableView?.indicatorStyle = .white
                self.addToPlaylistLabel?.textColor = .lightGray
            }
            self._firstLoad = false
            if self.playlists.count > 0 && (self.playlists[self.selectedPlaylistIndex].songs?.count ?? 0) > 0 {
                self.songActivityIndicator?.stopAnimating()
            }
        }
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    private func setupTableView() {
        self.refreshControl.addTarget(self, action: #selector(self.handleRefresh), for: UIControlEvents.valueChanged)
        self.tableView?.register(UINib(nibName: "SongTableViewCell", bundle: nil), forCellReuseIdentifier: self.songTableReuseIdentifier)
        self.tableView?.register(UINib(nibName: "PlayShuffleTableViewCell", bundle: nil), forCellReuseIdentifier: "play_shuffle_cell")
        self.tableView?.tableFooterView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 0.5, height: 0.5))
    }
    
    @objc func handleRefresh(control: UIRefreshControl) {
        VGMPRadio.getSongs(playlist: self.playlists[self.selectedPlaylistIndex], index: self.selectedPlaylistIndex, getNext: false, withCompletion: self.songsCompletionHandler)
    }
    
    private func setupPlaylistSelection() {
        if let layout = self.playlistCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = CGSize(width: 1, height: 30)
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 5.0
            layout.sectionInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
        }
        
        self.playlistCollectionView.register(UINib(nibName: "PlaylistSelectionCell", bundle: nil), forCellWithReuseIdentifier: self.playlistCollectionReuseIdentifier)
        self.playlistCollectionView.dataSource = self
        self.playlistCollectionView.delegate = self
        self.playlistCollectionView.backgroundColor = .clear
        self.playlistCollectionView.contentInset = UIEdgeInsets(top: 0.0, left: 5.0, bottom: 0.0, right: -20.0)
        self.playlistCollectionView.contentMode = .scaleToFill
        self.playlistCollectionView.showsHorizontalScrollIndicator = false
        self.playlistVEView.contentView.addSubview(self.playlistCollectionView)
        self.playlistVEView.contentView.addSubview(self.playlistActivityIndicator)
        self.playlistCollectionView.translatesAutoresizingMaskIntoConstraints = false
        self.playlistActivityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.playlistCollectionView.topAnchor.constraint(equalTo: self.playlistVEView.contentView.topAnchor,
                                                             constant: 0.0),
            self.playlistCollectionView.bottomAnchor.constraint(equalTo: self.playlistVEView.contentView.bottomAnchor,
                                                                constant: 0.0),
            self.playlistCollectionView.leadingAnchor.constraint(equalTo: self.playlistVEView.contentView.leadingAnchor,
                                                                 constant: 0.0),
            self.playlistCollectionView.trailingAnchor.constraint(equalTo: self.playlistVEView.contentView.trailingAnchor,
                                                                  constant: 0.0),
            self.playlistActivityIndicator.centerXAnchor.constraint(equalTo: self.playlistVEView.contentView.centerXAnchor,
                                                                    constant: 0.0),
            self.playlistActivityIndicator.centerYAnchor.constraint(equalTo: self.playlistVEView.contentView.centerYAnchor,
                                                                    constant: 0.0)
        ])
        if self.playlists.count == 0 {
            self.playlistActivityIndicator.startAnimating()
        }
    }
    
    private func setupUI() {
        // Initial setup for image for Large NavBar state since the the screen always has Large NavBar once it gets opened
        guard let navigationBar = self.navigationController?.navigationBar else { return }
        navigationBar.addSubview(self.logoView)
        self.logoView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.logoView.leftAnchor.constraint(equalTo: navigationBar.leftAnchor,
                                                constant: Const.ImageLeftMargin),
            self.logoView.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor,
                                                  constant: -Const.ImageBottomMarginForLargeState),
            self.logoView.heightAnchor.constraint(equalToConstant: Const.ImageSizeForLargeState),
            self.logoView.widthAnchor.constraint(equalTo: self.logoView.heightAnchor)
        ])
        
        self.searchController.searchResultsUpdater = self
        self.searchController.obscuresBackgroundDuringPresentation = false
        self.searchController.searchBar.placeholder = "Search Songs"
        self.navigationItem.searchController = self.searchController
        self.definesPresentationContext = true
    }
    
    private func moveAndResizeImage(for height: CGFloat) {
        let coeff: CGFloat = {
            let delta = height - Const.NavBarHeightSmallState
            let heightDifferenceBetweenStates = (Const.NavBarHeightLargeState - Const.NavBarHeightSmallState)
            return delta / heightDifferenceBetweenStates
        }()
        
        let factor = Const.ImageSizeForSmallState / Const.ImageSizeForLargeState
        let navWidth = ((self.navigationController?.navigationBar.frame.width ?? 0) / 2.0)
        
        let scale: CGFloat = {
            let sizeAddendumFactor = coeff * (1.0 - factor)
            return min(1.0, sizeAddendumFactor + factor)
        }()
        
        // Value of difference between icons for large and small states
        let sizeDiff = Const.ImageSizeForLargeState * (1.0 - factor) // 8.0
        
        let yTranslation: CGFloat = {
            /// This value = 14. It equals to difference of 12 and 6 (bottom margin for large and small states). Also it adds 8.0 (size difference when the image gets smaller size)
            let maxYTranslation = Const.ImageBottomMarginForLargeState - Const.ImageBottomMarginForSmallState + sizeDiff / 2
            return max(0, min(maxYTranslation, (maxYTranslation - coeff * (Const.ImageBottomMarginForSmallState + sizeDiff / 2))))
        }()
        
        let xTranslation = max(0, navWidth - Const.ImageLeftMargin - (coeff * (navWidth - Const.ImageLeftMargin - (sizeDiff / 2.0)) + (Const.ImageSizeForSmallState / 2.0)) - sizeDiff / 2)
        
        self.logoView.transform = CGAffineTransform.identity
            .translatedBy(x: xTranslation, y: yTranslation)
            .scaledBy(x: scale, y: scale)
    }

    func updatePlayStatus(isPlaying: Bool, isStopped: Bool) {
        self.isPlaying = isPlaying
        self.isStopped = isStopped
    }
    
    func updateCurrentlyPlayingSong(song: Int, playlist: Int) {
        self.stop(song: self.currentlyPlayingSong, playlist: self.currentlyPlayingPlaylist)
        self.currentlyPlayingSong = song
        self.currentlyPlayingPlaylist = playlist
        self.play(song: song, playlist: playlist)
    }
    
    func updateSelectedPlaylist(index: Int, songIndex: Int) {
        self.selectedPlaylistIndex = index
        self.currentlyPlayingPlaylist = index
        self.currentlyPlayingSong = songIndex
    }
    
    func stop(song: Int, playlist: Int) {
        if playlist < 0 || playlist >= self.playlists.count {
            return
        }
        let arrayToDisplay = self.isFiltering() ? self.filteredSongs : Array(self.playlists[playlist].songs!) as! [Song]
        var index = arrayToDisplay.index(where: { (item) -> Bool in
            item.audioId == song
        }) ?? 0
        if arrayToDisplay.count > 1 && !self.isFiltering() {
            index = index + 1
        }
        if playlist == self.selectedPlaylistIndex {
            if let cell = self.tableView?.cellForRow(at: IndexPath(row: index, section: 0)) as? SongTableViewCell {
                cell.stop()
            }
        }
    }
    
    func play(song: Int, playlist: Int) {
        if playlist == self.selectedPlaylistIndex {
            let arrayToDisplay = self.isFiltering() ? self.filteredSongs : Array(self.playlists[playlist].songs!) as! [Song]
            var index = arrayToDisplay.index(where: { (item) -> Bool in
                item.audioId == song
            }) ?? 0
            if arrayToDisplay.count > 1 && !self.isFiltering() {
                index = index + 1
            }
            if let cell = self.tableView?.cellForRow(at: IndexPath(row: index, section: 0)) as? SongTableViewCell {
                cell.play()
            }
        }
    }
    
    func pause(song: Int, playlist: Int) {
        let arrayToDisplay = self.isFiltering() ? self.filteredSongs : Array(self.playlists[playlist].songs!) as! [Song]
        var index = arrayToDisplay.index(where: { (item) -> Bool in
            item.audioId == song
        }) ?? 0
        if arrayToDisplay.count > 1 && !self.isFiltering() {
            index = index + 1
        }
        if playlist == self.selectedPlaylistIndex {
            if let cell = self.tableView?.cellForRow(at: IndexPath(row: index, section: 0)) as? SongTableViewCell {
                cell.pause()
            }
        }
    }
    
    func searchBarIsEmpty() -> Bool {
        // Returns true if the text is empty or nil
        return self.searchController.searchBar.text?.isEmpty ?? true
    }
    
    func filterContentForSearchText(_ searchText: String, scope: String = "All") {
        self.filteredSongs = self.playlists[self.selectedPlaylistIndex].songs?.filter({(song) -> Bool in
            return ((song as! Song).title?.lowercased().contains(searchText.lowercased()) ?? false) || ((song as! Song).game?.lowercased().contains(searchText.lowercased()) ?? false)
        }) as! [Song]
        self.tableView?.reloadData()
    }
    
    func isFiltering() -> Bool {
        return self.searchController.isActive && !self.searchBarIsEmpty()
    }
}

extension SongListViewController: UITableViewDelegate, UITableViewDataSource {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let height = navigationController?.navigationBar.frame.height else { return }
        self.moveAndResizeImage(for: height)
    }
    
    func refreshPlaying() {
        if self.currentlyPlayingPlaylist == self.selectedPlaylistIndex {
            let arrayToDisplay = self.isFiltering() ? self.filteredSongs : Array(self.playlists[self.currentlyPlayingPlaylist].songs!) as! [Song]
            var index = arrayToDisplay.index(where: { (item) -> Bool in
                item.audioId == self.currentlyPlayingSong
            }) ?? 0
            if arrayToDisplay.count > 1 {
                index = index + 1
            }
            let cell = self.tableView?.cellForRow(at: IndexPath(row: index, section: 0)) as? SongTableViewCell
            if self.isPlaying {
                cell?.play()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let arrayToDisplay = self.isFiltering() ? self.filteredSongs : Array(self.playlists[self.selectedPlaylistIndex].songs!) as! [Song]
        let count = arrayToDisplay.count
        tableView.deselectRow(at: indexPath, animated: true)
        var index = indexPath.row
        if count > 1 && !self.isFiltering() {
            if indexPath.row == 0 {
                return
            }
            index = index - 1
        }
        let song = arrayToDisplay[index]
        self.stop(song: self.currentlyPlayingSong, playlist: self.currentlyPlayingPlaylist)
        if let cell = tableView.cellForRow(at: indexPath) as? SongTableViewCell {
            cell.play()
        }

        self.isPlaying = true
        self.currentlyPlayingSong = Int(song.audioId)
        self.currentlyPlayingPlaylist = self.selectedPlaylistIndex
        self.delegate?.songSelected(playlist: self.playlists[self.selectedPlaylistIndex], songIndex: Int(song.audioId), playlistIndex: self.selectedPlaylistIndex, play: true)
        if self.isFiltering() {
            self.searchController.isActive = false
            let index = (Array(self.playlists[self.selectedPlaylistIndex].songs!) as! [Song]).index(where: { (item) -> Bool in
                item.audioId == self.currentlyPlayingSong
            }) ?? 0
            if (self.playlists[self.selectedPlaylistIndex].songs?.count ?? 0) > 1 {
                self.tableView?.scrollToRow(at: IndexPath(row: index + 1, section: 0), at: .middle, animated: true)
            }
        }
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return self.playlistVEView
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.selectedPlaylistIndex >= 0 && self.selectedPlaylistIndex < self.playlists.count {
            let arrayToDisplay = self.isFiltering() ? self.filteredSongs : Array(self.playlists[self.selectedPlaylistIndex].songs!) as! [Song]
            let count = arrayToDisplay.count
            if count > 1 && !self.isFiltering() {
                self.addToPlaylistLabel?.isHidden = true
                return count + 1
            } else if count == 1 || self.isFiltering() {
                self.addToPlaylistLabel?.isHidden = true
                return count
            } else {
                if self.playlists[self.selectedPlaylistIndex].isFavorites {
                    self.addToPlaylistLabel?.isHidden = false
                } else {
                    self.addToPlaylistLabel?.isHidden = true
                }
                return count
            }
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40.0
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let arrayToDisplay = self.isFiltering() ? self.filteredSongs : Array(self.playlists[self.selectedPlaylistIndex].songs!) as! [Song]
        if indexPath.row > 0 || arrayToDisplay.count <= 1 || self.isFiltering() {
            return 44.0
        } else {
            return 70.0
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 && playlists[self.selectedPlaylistIndex].songs?.count ?? 0 > 1 && !self.isFiltering() {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "play_shuffle_cell") as? PlayShuffleTableViewCell else {
                return UITableViewCell()
            }
            cell.delegate = self
            return cell
        }
        let arrayToDisplay = self.isFiltering() ? self.filteredSongs : Array(self.playlists[self.selectedPlaylistIndex].songs!) as! [Song]
        var index = indexPath.row
        if arrayToDisplay.count > 1 && !self.isFiltering() {
            index = index - 1
        }
        guard let cell = tableView.dequeueReusableCell(withIdentifier: self.songTableReuseIdentifier) as? SongTableViewCell else {
            return UITableViewCell()
        }
        let song = arrayToDisplay[index]
        cell.titleLabel?.text = song.title
        cell.artistLabel?.text = song.game
        cell.albumArtImage?.kf.cancelDownloadTask()
        cell.albumArtImage?.kf.setImage(with: song.albumArtUrl, placeholder: #imageLiteral(resourceName: "music_note"), options: [.transition(.fade(0.5))] , progressBlock: nil, completionHandler: nil)
        if self.currentlyPlayingPlaylist == self.selectedPlaylistIndex && self.currentlyPlayingSong == Int(song.audioId) {
            if self.isPlaying {
                cell.play()
            } else if self.isStopped {
                cell.stop()
            } else {
                cell.pause()
            }
        }
        if song.favorite {
            cell.setFavorite()
        }
        cell.theme = self._currentTheme
        if self._currentTheme == .dark {
            cell.titleLabel?.textColor = .white
            cell.artistLabel?.textColor = .white
        } else {
            cell.titleLabel?.textColor = .black
            cell.artistLabel?.textColor = .black
        }
        if song.dislike {
            cell.setDisliked()
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        var likeAction = UITableViewRowAction(style: .default, title: NSLocalizedString("Like", comment: ""), handler: self.didFavorite)
        var dislikeAction = UITableViewRowAction(style: .destructive, title: NSLocalizedString("Dislike", comment: ""), handler: self.didDislike)
        likeAction.backgroundColor = .blue
        var index = indexPath.row
        if self.playlists[self.selectedPlaylistIndex].songs?.count ?? 0 > 1 && !self.isFiltering() {
            index = index - 1
        }
        if let songs = self.playlists[self.selectedPlaylistIndex].songs,
            let song = songs[index] as? Song {
            if song.favorite {
                likeAction = UITableViewRowAction(style: .default, title: NSLocalizedString("Unlike", comment: ""), handler: self.didFavorite)
                likeAction.backgroundColor = .blue
            } else if song.dislike {
                dislikeAction = UITableViewRowAction(style: .destructive, title: NSLocalizedString("Undislike", comment: ""), handler: self.didDislike)
            }
        }
        return [likeAction, dislikeAction]
    }
    
    func didFavorite(action: UITableViewRowAction, indexPath: IndexPath) {
        let arrayToDisplay = self.isFiltering() ? self.filteredSongs : Array(self.playlists[self.selectedPlaylistIndex].songs!) as! [Song]
        let playlist = self.playlists[self.selectedPlaylistIndex]
        var index = indexPath.row
        if arrayToDisplay.count > 1 && !self.isFiltering() {
            index = index - 1
        }
        let song = arrayToDisplay[index]
        song.favorite = !song.favorite
        song.dislike = false

        if playlist.isFavorites && !song.favorite {
            playlist.removeFromSongs(song)
            self.tableView?.reloadData()
        } else {
            self.tableView?.reloadRows(at: [indexPath], with: .automatic)
        }
        do {
            try Util.getManagedContext()?.save()
        } catch {
            fatalError("Failure to save context: \(error)")
        }
    }
    
    func didDislike(action: UITableViewRowAction, indexPath: IndexPath) {
        let arrayToDisplay = self.isFiltering() ? self.filteredSongs : Array(self.playlists[self.selectedPlaylistIndex].songs!) as! [Song]
        let playlist = self.playlists[self.selectedPlaylistIndex]
        var index = indexPath.row
        if arrayToDisplay.count > 1 && !self.isFiltering() {
            index = index - 1
        }
        let song = arrayToDisplay[index]
        song.dislike = !song.dislike
        song.favorite = false
        self.playlists[0].removeFromSongs(song)
        if playlist.isFavorites && !song.favorite {
            self.tableView?.reloadData()
        } else {
            self.tableView?.reloadRows(at: [indexPath], with: .automatic)
        }
        do {
            try Util.getManagedContext()?.save()
        } catch {
            fatalError("Failure to save context: \(error)")
        }
    }
}

extension SongListViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == self.selectedPlaylistIndex {
            return
        }
        let playlist = self.playlists[indexPath.item]
        if playlist.hasNew {
            playlist.hasNew = false
        }
        
        guard let cell = collectionView.cellForItem(at: indexPath) as? PlaylistSelectionCell else {
            return
        }
        if cell.newIsHidden == false {
            cell.newIsHidden = true
            collectionView.collectionViewLayout.invalidateLayout()
        }
        
        if let cellToDeselect = collectionView.cellForItem(at: IndexPath(item: self.selectedPlaylistIndex, section: 0)) as? PlaylistSelectionCell {
            cellToDeselect.deselectCell(animated: true, theme: self._currentTheme)
        }
        
        cell.selectCell(animated: true, theme: self._currentTheme)
        self.selectedPlaylistIndex = indexPath.item
        self.tableView?.reloadData()
        if (playlist.songs?.count ?? 0) == 0 {
            self.songActivityIndicator?.startAnimating()
            VGMPRadio.getSongs(playlist: playlist, index: self.selectedPlaylistIndex, getNext: false, withCompletion: self.songsCompletionHandler)
        }
        if (playlist.isFavorites) {
            VGMPRadio.getSongs(playlist: playlist, index: self.selectedPlaylistIndex, getNext: false, withCompletion: self.songsCompletionHandler)
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.playlists.count
    }
        
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: self.playlistCollectionReuseIdentifier, for: indexPath) as? PlaylistSelectionCell else {
            return UICollectionViewCell()
        }
        cell.titleLabel?.text = self.playlists[indexPath.item].title
        cell.newIsHidden = !(self.playlists[indexPath.item].hasNew && !self.playlists[indexPath.item].isFavorites)
        
        if self.selectedPlaylistIndex == indexPath.item {
            cell.selectCell(animated: false, theme: self._currentTheme)
        } else {
            cell.deselectCell(animated: false, theme: self._currentTheme)
        }
        return cell
    }
    
    func songsCompletionHandler(result: Result<[Song]>, index: Int, switchQueue: Bool, getNext: Bool) {
        if switchQueue {
            DispatchQueue.main.async {
                self.songActivityIndicator?.stopAnimating()
                self.refreshControl.endRefreshing()
            }
        } else {
            self.songActivityIndicator?.stopAnimating()
            self.refreshControl.endRefreshing()
        }
        if let error = result.error {
            NSLog("Error getting songs: \(error.localizedDescription)")
            return
        }
        if let songs = result.value {
            if (self.playlists[index].songs?.count ?? 0) != 0 && songs.count > (self.playlists[index].songs?.count ?? 0) {
                self.playlists[index].hasNew = true
                if switchQueue {
                    DispatchQueue.main.async {
                        self.playlistCollectionView.collectionViewLayout.invalidateLayout()
                    }
                } else {
                    self.playlistCollectionView.collectionViewLayout.invalidateLayout()
                }
            }
            self.playlists[index].songs = NSOrderedSet(array: songs)
            if switchQueue {
                DispatchQueue.main.sync {
                    do {
                        try Util.getManagedContext()?.save()
                    } catch {
                        fatalError("Failure to save context: \(error)")
                    }
                    if index == self.selectedPlaylistIndex {
                        self.tableView?.reloadData()
                    }
                }
            } else {
                do {
                    try Util.getManagedContext()?.save()
                } catch {
                    fatalError("Failure to save context: \(error)")
                }
                if index == self.selectedPlaylistIndex {
                    self.tableView?.reloadData()
                }
            }
        }
        if getNext {
            if index < self.playlists.count - 2 {
                VGMPRadio.getSongs(playlist: self.playlists[index + 1], index: index + 1, getNext: true, withCompletion: self.songsCompletionHandler)
            } else {
                VGMPRadio.getSongs(playlist: self.playlists[index + 1], index: index + 1, getNext: false, withCompletion: self.songsCompletionHandler)
            }
        }
    }
}

extension SongListViewController: PlaylistShuffleTableViewCellDelegate {
    func playTapped() {
        self.stop(song: self.currentlyPlayingSong, playlist: self.currentlyPlayingPlaylist)
        self.isPlaying = true
        self.currentlyPlayingPlaylist = self.selectedPlaylistIndex
        self.delegate?.songSelected(playlist: playlists[self.selectedPlaylistIndex], songIndex: 0, playlistIndex: self.selectedPlaylistIndex, play: true)
    }
    
    func shuffleTapped() {
        self.stop(song: self.currentlyPlayingSong, playlist: self.currentlyPlayingPlaylist)
        self.isPlaying = true
        self.currentlyPlayingPlaylist = self.selectedPlaylistIndex
        self.delegate?.shuffleTapped(playlist: playlists[self.selectedPlaylistIndex], playlistIndex: self.selectedPlaylistIndex)
    }
}

extension SongListViewController: UISearchResultsUpdating {
    // MARK: - UISearchResultsUpdating Delegate
    func updateSearchResults(for searchController: UISearchController) {
        self.filterContentForSearchText(searchController.searchBar.text!)
    }
}
