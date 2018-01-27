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
    func songSelected(playlist: Playlist, songIndex: Int, playlistIndex: Int)
}

class SongListViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var songActivityIndicator: UIActivityIndicatorView?
    
    private var playlistCollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout())
    private var playlistVEView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private var playlistActivityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .white)
    private var playlists: [Playlist] = []
    private var selectedPlaylistIndex: Int = 0
    private var currentlyPlayingSong: Int = -1
    private var currentlyPlayingPlaylist: Int = -1
    private let logoView = UIImageView(image: #imageLiteral(resourceName: "vgmp_logo"))
    private let refreshControl = UIRefreshControl()

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
            } else {
                self.tableView?.separatorColor = .white
                self.songActivityIndicator?.activityIndicatorViewStyle = .whiteLarge
                self.playlistActivityIndicator.activityIndicatorViewStyle = .white
                self.navigationController?.navigationBar.barStyle = .black
                self.playlistVEView.effect = UIBlurEffect(style: .dark)
                self.tableView?.backgroundColor = .darkGray
                self.tableView?.indicatorStyle = .white
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
        }
        VGMPRadio.getPlaylists {
            results in
            self.playlistActivityIndicator.stopAnimating()
            if let error = results.error {
                NSLog("Error getting playlists: \(error.localizedDescription)")
                return
            }
            if let playlists = results.value {
                self.playlists = playlists
                self.playlistCollectionView.reloadData()
                if (self.playlists[currentPlaylist].songs?.count ?? 0) == 0 {
                    VGMPRadio.getSongs(playlist: playlists[currentPlaylist], index: currentPlaylist, withCompletion: self.songsCompletionHandler)
                }
            }
        }
        self.setupTableView()
        self.setupPlaylistSelection()
        self.setupUI()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewDidLayoutSubviews() {
        if self._firstLoad {
            self.tableView?.refreshControl = self.refreshControl
            if self._currentTheme == .light {
                self.tableView?.separatorColor = .lightGray
                self.tableView?.backgroundColor = .white
                self.playlistVEView.effect = UIBlurEffect(style: .extraLight)
                self.songActivityIndicator?.color = .gray
                self.tableView?.indicatorStyle = .black
            } else {
                self.tableView?.separatorColor = .white
                self.playlistVEView.effect = UIBlurEffect(style: .dark)
                self.tableView?.backgroundColor = .darkGray
                self.tableView?.indicatorStyle = .white
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
        self.tableView?.tableFooterView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 0.5, height: 0.5))
    }
    
    @objc func handleRefresh(control: UIRefreshControl) {
        VGMPRadio.getSongs(playlist: self.playlists[self.selectedPlaylistIndex], index: self.selectedPlaylistIndex, withCompletion: self.songsCompletionHandler)
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
    
    func stop(song: Int, playlist: Int) {
        if playlist == self.selectedPlaylistIndex {
            if let cell = self.tableView?.cellForRow(at: IndexPath(row: Int(song), section: 0)) as? SongTableViewCell {
                cell.stop()
            }
        }
    }
    
    func play(song: Int, playlist: Int) {
        if playlist == self.selectedPlaylistIndex {
            if let cell = self.tableView?.cellForRow(at: IndexPath(row: Int(song), section: 0)) as? SongTableViewCell {
                cell.play()
            }
        }
    }
    
    func pause(song: Int, playlist: Int) {
        if playlist == self.selectedPlaylistIndex {
            if let cell = self.tableView?.cellForRow(at: IndexPath(row: Int(song), section: 0)) as? SongTableViewCell {
                NSLog("pause from func")
                cell.pause()
            }
        }
    }
}

extension SongListViewController: UITableViewDelegate, UITableViewDataSource {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let height = navigationController?.navigationBar.frame.height else { return }
        self.moveAndResizeImage(for: height)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.stop(song: self.currentlyPlayingSong, playlist: self.currentlyPlayingPlaylist)
        tableView.deselectRow(at: indexPath, animated: true)
        if let cell = tableView.cellForRow(at: indexPath) as? SongTableViewCell {
            cell.play()
        }
        self.isPlaying = true
        self.currentlyPlayingSong = indexPath.row
        self.currentlyPlayingPlaylist = self.selectedPlaylistIndex
        self.delegate?.songSelected(playlist: self.playlists[self.selectedPlaylistIndex], songIndex: indexPath.row, playlistIndex: self.selectedPlaylistIndex)
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return self.playlistVEView
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.selectedPlaylistIndex >= 0 && self.selectedPlaylistIndex < self.playlists.count {
            return self.playlists[self.selectedPlaylistIndex].songs?.count ?? 0
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40.0
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: self.songTableReuseIdentifier) as? SongTableViewCell,
              let song = playlists[self.selectedPlaylistIndex].songs?[indexPath.row] as? Song else {
            return UITableViewCell()
        }
        cell.titleLabel?.text = song.title
        cell.artistLabel?.text = song.game
        cell.albumArtImage?.kf.cancelDownloadTask()
        cell.albumArtImage?.kf.setImage(with: song.albumArtUrl, placeholder: #imageLiteral(resourceName: "music_note"), options: [.transition(.fade(0.5))] , progressBlock: nil, completionHandler: nil)
        if self.currentlyPlayingPlaylist == self.selectedPlaylistIndex && self.currentlyPlayingSong == indexPath.row {
            if self.isPlaying {
                cell.play()
            } else if self.isStopped {
                cell.stop()
            } else {
                cell.pause()
                NSLog("Pause from cell")
            }
        }
        cell.theme = self._currentTheme
        if self._currentTheme == .dark {
            cell.titleLabel?.textColor = .white
            cell.artistLabel?.textColor = .white
        } else {
            cell.titleLabel?.textColor = .black
            cell.artistLabel?.textColor = .black
        }
        return cell
    }
}

extension SongListViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == self.selectedPlaylistIndex {
            return
        }
        
        if self.playlists[indexPath.item].hasNew {
            self.playlists[indexPath.item].hasNew = false
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
        if (self.playlists[indexPath.item].songs?.count ?? 0) == 0 {
            self.songActivityIndicator?.startAnimating()
            VGMPRadio.getSongs(playlist: self.playlists[self.selectedPlaylistIndex], index: self.selectedPlaylistIndex, withCompletion: self.songsCompletionHandler)
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
        cell.newIsHidden = !self.playlists[indexPath.item].hasNew
        
        if self.selectedPlaylistIndex == indexPath.item {
            cell.selectCell(animated: false, theme: self._currentTheme)
        } else {
            cell.deselectCell(animated: false, theme: self._currentTheme)
        }
        return cell
    }
    
    func songsCompletionHandler(result: Result<[Song]>, index: Int) {
        self.songActivityIndicator?.stopAnimating()
        self.refreshControl.endRefreshing()
        if let error = result.error {
            NSLog("Error getting songs: \(error.localizedDescription)")
            return
        }
        if let songs = result.value {
            self.playlists[index].songs = NSOrderedSet(array: songs)
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
}
