// lib/screen/videos_screen.dart
import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:gallery_memo/widget/photo_grid_item.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gallery_memo/screen/photo_view_screen.dart';

class VideosScreen extends StatefulWidget {
  final bool isSelectMode;
  final Set<String> selectedPhotoIds;
  final void Function(String photoId) onPhotoTap;
  final void Function(String photoId) onPhotoLongPress;

  const VideosScreen({
    super.key,
    required this.isSelectMode,
    required this.selectedPhotoIds,
    required this.onPhotoTap,
    required this.onPhotoLongPress,
  });

  @override
  VideosScreenState createState() => VideosScreenState();
}

class VideosScreenState extends State<VideosScreen>
    with AutomaticKeepAliveClientMixin<VideosScreen> {
  bool _isLoading = true;
  List<Photo> _videos = [];
  final Map<String, ImageProvider> _thumbnailCache = {};
  static const int _pageSize = 30;
  int _currentPage = 0;
  bool _hasMoreVideos = true;
  final ScrollController _scrollController = ScrollController();
  final Set<String> _errorVideoIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _thumbnailCache.clear();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreVideos();
    }
  }

  Future<void> _loadVideos() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
      );

      if (albums.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _videos = [];
            _hasMoreVideos = false;
          });
        }
        return;
      }

      final List<AssetEntity> videoAssets = await albums[0].getAssetListPaged(
        page: 0,
        size: _pageSize,
      );

      final List<Photo> newVideos = [];
      for (final asset in videoAssets) {
        final file = await asset.file;
        if (file != null) {
          final photo = Photo(
            id: asset.id,
            path: file.path,
            date: asset.createDateTime,
            asset: asset,
            isVideo: true,
          );
          newVideos.add(photo);
        }
      }

      if (mounted) {
        setState(() {
          _videos = newVideos;
          _currentPage = 1;
          _isLoading = false;
          _hasMoreVideos = videoAssets.length == _pageSize;
        });
      }
    } catch (e) {
      debugPrint('비디오 로드 중 오류 발생: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _videos = [];
        });
      }
    }
  }

  Future<void> _loadMoreVideos() async {
    if (!_hasMoreVideos || _isLoading) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
      );

      if (albums.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasMoreVideos = false;
          });
        }
        return;
      }

      final List<AssetEntity> videoAssets = await albums[0].getAssetListPaged(
        page: _currentPage,
        size: _pageSize,
      );

      if (videoAssets.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasMoreVideos = false;
          });
        }
        return;
      }

      final List<Photo> newVideos = [];
      for (final asset in videoAssets) {
        final file = await asset.file;
        if (file != null) {
          final photo = Photo(
            id: asset.id,
            path: file.path,
            date: asset.createDateTime,
            asset: asset,
            isVideo: true,
          );
          newVideos.add(photo);
        }
      }

      if (mounted) {
        setState(() {
          _videos.addAll(newVideos);
          _currentPage++;
          _isLoading = false;
          _hasMoreVideos = videoAssets.length == _pageSize;
        });
      }
    } catch (e) {
      debugPrint('추가 비디오 로드 중 오류 발생: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<ImageProvider> _getVideoThumbnail(Photo photo) async {
    if (_thumbnailCache.containsKey(photo.id)) {
      return _thumbnailCache[photo.id]!;
    }

    if (photo.asset != null) {
      try {
        final thumbnail = await photo.asset!.thumbnailDataWithSize(
          const ThumbnailSize(200, 200),
          quality: 80,
        );
        if (thumbnail != null) {
          final imageProvider = MemoryImage(thumbnail);
          _thumbnailCache[photo.id] = imageProvider;
          return imageProvider;
        }
      } catch (e) {
        debugPrint('썸네일 생성 중 오류 발생: $e');
      }
    }

    return const AssetImage('assets/logo/logo.png');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading && _videos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final displayVideos =
        _videos.where((v) => !_errorVideoIds.contains(v.id)).toList();

    if (displayVideos.isEmpty) {
      return const Center(
        child: Text('동영상이 없습니다', style: TextStyle(fontSize: 16)),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: displayVideos.length + (_hasMoreVideos && _isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == displayVideos.length) {
          return const Center(child: CircularProgressIndicator());
        }

        final video = displayVideos[index];
        return PhotoGridItem(
          photo: video,
          imageProvider: const AssetImage(
            'assets/logo/logo.png',
          ), // Placeholder, will be replaced by thumbnail
          onTap: () => widget.onPhotoTap(video.id),
          onLongPress: () => widget.onPhotoLongPress(video.id),
          isSelectable: widget.isSelectMode,
          isSelected: widget.selectedPhotoIds.contains(video.id),
          onError: (videoId) {
            if (mounted) {
              setState(() {
                _errorVideoIds.add(videoId);
              });
            }
          },
          key: ValueKey(video.id),
        );
      },
    );
  }
}
