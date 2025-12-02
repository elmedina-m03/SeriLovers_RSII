import 'package:flutter/material.dart';

/// A reusable horizontal scrollable list with pagination support
/// 
/// This widget provides:
/// - Full horizontal scrolling
/// - Automatic pagination when reaching the end
/// - Smooth scrolling physics
/// - Loading indicator at the end when loading more
class HorizontalPaginatedList<T> extends StatefulWidget {
  /// List of items to display
  final List<T> items;
  
  /// Builder function to create each item widget
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  
  /// Function to load more items when reaching the end
  final Future<void> Function()? onLoadMore;
  
  /// Whether more items are available to load
  final bool hasMore;
  
  /// Whether currently loading more items
  final bool isLoadingMore;
  
  /// Height of the list
  final double height;
  
  /// Padding for the list
  final EdgeInsets? padding;
  
  /// Spacing between items
  final double? spacing;
  
  /// Scroll controller (optional, for external control)
  final ScrollController? controller;
  
  /// Whether to show loading indicator at the end
  final bool showLoadingIndicator;

  const HorizontalPaginatedList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.onLoadMore,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.height = 200,
    this.padding,
    this.spacing,
    this.controller,
    this.showLoadingIndicator = true,
  });

  @override
  State<HorizontalPaginatedList<T>> createState() => _HorizontalPaginatedListState<T>();
}

class _HorizontalPaginatedListState<T> extends State<HorizontalPaginatedList<T>> {
  late ScrollController _scrollController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {
    if (_isLoading || !_scrollController.hasClients) return;
    
    // Check if we've scrolled to the end (with a threshold)
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      // Load more if available and callback is provided
      if (widget.hasMore && 
          widget.onLoadMore != null && 
          !widget.isLoadingMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || widget.isLoadingMore) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onLoadMore!();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('No items to display'),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity, // Ensure full width for proper scrolling
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Allow Row to expand beyond screen width
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...widget.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  right: widget.spacing ?? 8,
                ),
                child: widget.itemBuilder(context, item, index),
              );
            }).toList(),
            // Show loading indicator at the end
            if (widget.showLoadingIndicator && widget.hasMore)
              Padding(
                padding: EdgeInsets.only(
                  left: widget.spacing ?? 8,
                  right: 16,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

