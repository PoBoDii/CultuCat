import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class ImageWidget extends StatelessWidget {
  final String imageString;
  final BoxFit fit;

  const ImageWidget({
    super.key,
    required this.imageString,
    this.fit = BoxFit.cover,
  });

  List<String> _getValidImagePaths() {
    return imageString.split(',')
        .where((path) => path.trim().isNotEmpty && path.trim() != '---')
        .map((path) => path.trim())
        .toList();
  }

  void _showImageGallery(BuildContext context, List<String> imagePaths) {
    if (imagePaths.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return ImageGalleryDialog(
          imagePaths: imagePaths,
          parentContext: context,
        );
      },
    );
  }

  // Method to check if the image exists and can be loaded
  Future<bool> _checkImageExists(String imageUrl) async {
    try {
      final response = await http.head(Uri.parse(imageUrl));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imagePaths = _getValidImagePaths();

    // If no valid network images, use local asset without click functionality
    if (imagePaths.isEmpty) {
      return Image.asset(
        'assets/images/test.jpg',
        fit: fit,
      );
    }

    // Determine the first image URL
    final firstImageUrl = imagePaths.first.startsWith('http')
        ? imagePaths.first
        : 'https://agenda.cultura.gencat.cat${imagePaths.first}';

    // Use a FutureBuilder to check if the image loads successfully
    return FutureBuilder<bool>(
      future: _checkImageExists(firstImageUrl),
      builder: (context, snapshot) {
        // If image exists, make it clickable
        if (snapshot.data == true) {
          return GestureDetector(
            onTap: () => _showImageGallery(context, imagePaths),
            child: Image.network(
              firstImageUrl,
              fit: fit,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(child: CircularProgressIndicator());
              },
            ),
          );
        }
        // Otherwise show the default image without click functionality
        else {
          return Image.asset(
            'assets/images/test.jpg',
            fit: fit,
          );
        }
      },
    );
  }
}

class ImageGalleryDialog extends StatefulWidget {
  final List<String> imagePaths;
  final BuildContext parentContext;

  const ImageGalleryDialog({
    super.key,
    required this.imagePaths,
    required this.parentContext
  });

  @override
  State<ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<ImageGalleryDialog> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatImageUrl(String path) {
    return path.startsWith('http')
        ? path
        : 'https://agenda.cultura.gencat.cat$path';
  }

  @override
  Widget build(BuildContext context) {
    // Get the size of the original image from the parent context
    final RenderBox? renderBox = widget.parentContext.findRenderObject() as RenderBox?;
    final Size? originalSize = renderBox?.size;

    return Dialog(
      insetPadding: EdgeInsets.all(10),
      child: SizedBox(
        width: originalSize?.width ?? double.infinity,
        height: originalSize?.height ?? double.infinity,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imagePaths.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return Center(
                  child: Image.network(
                    _formatImageUrl(widget.imagePaths[index]),
                    fit: BoxFit.contain,
                    width: originalSize?.width,
                    height: originalSize?.height,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return CircularProgressIndicator();
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          'Error loading image',
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            // Close button
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
            // Page indicator
            if (widget.imagePaths.length > 1)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.imagePaths.length,
                          (index) => Container(
                        width: 10,
                        height: 10,
                        margin: EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Colors.white
                              : Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}