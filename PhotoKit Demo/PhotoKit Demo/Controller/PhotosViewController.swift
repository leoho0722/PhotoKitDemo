//
//  PhotosViewController.swift
//  PhotoKit Demo
//
//  Created by Leo Ho on 2022/4/18.
//

import UIKit
import Photos
import PhotosUI

class PhotosViewController: UIViewController {

    @IBOutlet weak var photosCollectionView: UICollectionView!
    @IBOutlet weak var photosCollectionViewFlowLayout: UICollectionViewFlowLayout!
    
    // Photos 變數宣告
    var allPhotos: PHFetchResult<PHAsset>!
    let allPhotosOptions = PHFetchOptions() // 創建 PHFetchOptions 實例
    let photoCacheImageManager = PHCachingImageManager() // 創建 PHCachingImageManager 實例
    var thumbnailSize: CGSize! // 縮圖大小
    
    // 每行、每列的個數
    var numOfRow: Int = 3
    var numOfColumn: Int = 3
    
    var itemIndexPath: IndexPath = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Photo Wall"
        
        setUpCollectionView() // 設定 CollectionView
                
        setupNavigationBarButtonItems() // 設定 NavigationBarButtonItem
        
        requirePhotosAccess() // 處理照片權限
        
        processPhotos() // 處理預設的照片顯示
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let scale = UIScreen.main.scale
        let cellSize = photosCollectionViewFlowLayout.itemSize
        thumbnailSize = CGSize(width: cellSize.width * scale, height: cellSize.height * scale)
    }
    
    // MARK: - 設定 CollectionView
    
    func setUpCollectionView() {
        photosCollectionView.register(UINib(nibName: "PhotosCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: PhotosCollectionViewCell.identifier)
        photosCollectionView.delegate = self
        photosCollectionView.dataSource = self
        photosCollectionViewFlowLayout.estimatedItemSize = .zero // 設定 Cell 的大小由 itemSize 計算
    }
    
    // MARK: - 設定 NavigationBarButtonItem
    
    func setupNavigationBarButtonItems() {
        setUpNavigationLeftBarButtonItems()
        setUpNavigationRightBarButtonItems()
    }
    
    func setUpNavigationLeftBarButtonItems() {
        let reloadItem = UIBarButtonItem(image: UIImage(systemName: "arrow.counterclockwise"), style: .plain, target: self, action: #selector(reloadItemClicked))
        
        self.navigationItem.leftBarButtonItems = [reloadItem]
    }
    
    @objc func reloadItemClicked() {
        print("將照片牆重設回預設")
        let defaultPredicate = "self.mediaType==1 OR self.mediaType==2 OR self.mediaSubtypes==8 OR self.isFavorite==true OR self.isFavorite==false"
        allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        allPhotosOptions.predicate = NSPredicate(format: defaultPredicate)
        allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)
        photosCollectionView.reloadData()
    }
    
    func setUpNavigationRightBarButtonItems() {
        let filterMenu = UIMenu(children: [
            UIAction(title: "Favorites", image: UIImage(systemName: "heart.fill"), handler: { [self] action in
                allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                allPhotosOptions.predicate = NSPredicate(format: "self.isFavorite==true")
                allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)
                photosCollectionView.reloadData()
            }),
            UIAction(title: "Not Favorited", image: UIImage(systemName: "heart"), handler: { [self] action in
                allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                allPhotosOptions.predicate = NSPredicate(format: "self.isFavorite==false")
                allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)
                photosCollectionView.reloadData()
            }),
            UIAction(title: "Photos", image: UIImage(systemName: "photo"), handler: { [self] action in
                allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                allPhotosOptions.predicate = NSPredicate(format: "self.mediaType==1")
                allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)
                photosCollectionView.reloadData()
            }),
            UIAction(title: "Live Photos", image: UIImage(systemName: "livephoto"), handler: { [self] action in
                allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                allPhotosOptions.predicate = NSPredicate(format: "self.mediaSubtypes==8")
                allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)
                photosCollectionView.reloadData()
            }),
            UIAction(title: "Videos", image: UIImage(systemName: "video"), handler: { [self] action in
                allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                allPhotosOptions.predicate = NSPredicate(format: "self.mediaType==2")
                allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)
                photosCollectionView.reloadData()
            })
        ])
        
        let filterItem = UIBarButtonItem.addPullDownButtonMenu(title: "", image: UIImage(systemName: "line.horizontal.3.decrease.circle.fill"), size: CGSize(width: 30, height: 30), menu: filterMenu)
        
        self.navigationItem.rightBarButtonItems = [filterItem]
    }
    
    // MARK: - 處理照片權限
    
    func requirePhotosAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            if (status == .authorized) {
                print("App can access User's Photos")
            } else {
                print("App can't access User's Photos")
            }
        }
    }
    
    // MARK: - 處理預設的照片顯示
    
    func processPhotos() {
        allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)
        PHPhotoLibrary.shared().register(self) // 註冊相簿變化的觀察
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self) // 移除相簿變化的觀察
    }

}

// MARK: - PHPhotoLibraryChangeObserver

extension PhotosViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let changes = changeInstance.changeDetails(for: allPhotos) else { return }
        DispatchQueue.main.async {
            self.allPhotos = changes.fetchResultAfterChanges
            if (changes.hasIncrementalChanges) {
                guard let collectionView = self.photosCollectionView else { fatalError() }

                collectionView.performBatchUpdates({
                    if let removed = changes.removedIndexes, removed.count > 0 {
                        collectionView.deleteItems(at: removed.map({ IndexPath(item: $0, section: 0) }))
                    }
                    if let inserted = changes.insertedIndexes, inserted.count > 0 {
                        collectionView.insertItems(at: inserted.map({ IndexPath(item: $0, section: 0) }))
                    }
                    if let changed = changes.changedIndexes, changed.count > 0 {
                        collectionView.reloadItems(at: changed.map({ IndexPath(item: $0, section: 0) }))
                    }
                    changes.enumerateMoves { fromIndex, toIndex in
                        collectionView.moveItem(at: IndexPath(item: fromIndex, section: 0),
                                                to: IndexPath(item: toIndex, section: 0))
                    }
                }, completion: nil)
            } else {
                self.photosCollectionView.reloadItems(at: [self.itemIndexPath])
            }
        }
    }
}

// MARK: - UICollectionViewDelegate、UICollectionViewDataSource

extension PhotosViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return allPhotos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let asset = allPhotos.object(at: indexPath.item)
        itemIndexPath = indexPath
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotosCollectionViewCell.identifier, for: indexPath) as? PhotosCollectionViewCell else {
            fatalError("Can't Load Photos CollectionView Cell!")
        }
        cell.representedAssetIdentifier = asset.localIdentifier
        photoCacheImageManager.requestImage(for: asset, targetSize: thumbnailSize, contentMode: .default, options: nil) { image, _ in
            if (cell.representedAssetIdentifier == asset.localIdentifier) {
                cell.smallImage = image
                cell.heartImage = asset.isFavorite ? "♥︎" : ""
                if (asset.mediaSubtypes == .photoLive) {
                    cell.sourceImage = UIImage(systemName: "livephoto")
                } else if (asset.mediaType == .image) {
                    cell.sourceImage = UIImage(systemName: "photo")
                } else if (asset.mediaType == .video) {
                    cell.sourceImage = UIImage(systemName: "video")
                }
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let nextVC = PhotosDetailViewController()
        nextVC.asset = allPhotos.object(at: indexPath.item)
        self.navigationController?.pushViewController(nextVC, animated: true)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension PhotosViewController: UICollectionViewDelegateFlowLayout {
    // Cell 的寬高
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        photosCollectionViewFlowLayout.itemSize = CGSize(width: 110, height: 110) // 設定 Cell 的大小
        return photosCollectionViewFlowLayout.itemSize
    }

    // Cell 的上下間距
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 2
    }

    // Cell 的左右間距
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 2
    }

    // Cell 與 CollectionView 的間距
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
    }
}