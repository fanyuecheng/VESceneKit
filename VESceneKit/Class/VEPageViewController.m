//
//  VEPageViewController.m
//  VESceneKit
//
//  Created by real on 2022/7/12.
//  Edited by Fancy on 2023/6/27.
//  Copyright © 2022 ByteDance. All rights reserved.
//

#import "VEPageViewController.h"
#import <objc/message.h>

NSUInteger const VEPageMaxCount = NSUIntegerMax;

@interface UIViewController (VEPageViewControllerItem)

@property (nonatomic, assign) NSUInteger veIndex;

@property (nonatomic, assign) BOOL veTransitioning;

@end

@implementation UIViewController(VEPageViewControllerItem)

- (void)setVeIndex:(NSUInteger)veIndex {
    objc_setAssociatedObject(self, @selector(veIndex), @(veIndex), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)veIndex {
    return [objc_getAssociatedObject(self, _cmd) unsignedIntegerValue];
}

- (void)setVeTransitioning:(BOOL)veTransitioning {
    objc_setAssociatedObject(self, @selector(veTransitioning), @(veTransitioning), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)veTransitioning {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

@end

static NSString *VEPageViewControllerExceptionKey = @"VEPageViewControllerExceptionKey";

@interface VEPageViewController () <UIScrollViewDelegate>

{
    struct {
        unsigned hasDidScrollChangeDirection : 1;
        unsigned hasWillDisplayItem : 1;
        unsigned hasDidEndDisplayItem : 1;
    } _delegateHas;
    
    struct {
        unsigned hasPageForItemAtIndex : 1;
        unsigned hasNumberOfItemInPageViewController : 1;
        unsigned hasIsVerticalPageScrollInPageViewController : 1;
    } _dataSourceHas;
}

@property (nonatomic, assign) NSInteger itemCount;

@property (nonatomic, assign) BOOL isVerticalScroll;

@property (nonatomic, assign) BOOL needReloadData;

@property (nonatomic, assign) BOOL shouldChangeToNextPage;

@property (nonatomic, assign) VEPageItemMoveDirection currentDirection;

@property (nonatomic, strong) UIScrollView *scrollView;

@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIViewController<VEPageItem> *> *activeViewControllers;

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<UIViewController<VEPageItem> *> *> *cacheViewControllers;

@property (nonatomic, strong) UIViewController<VEPageItem> *currentViewController;

@end

@implementation VEPageViewController


#pragma mark UIViewController

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.activeViewControllers = [NSMutableDictionary dictionary];
    self.cacheViewControllers = [NSMutableDictionary dictionary];
    self.currentIndex = VEPageMaxCount;
    self.needReloadData = YES;
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods {
    return NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.scrollView];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    self.scrollView.frame = self.view.bounds;
    [self _reloadDataIfNeeded];
    [self _layoutChildViewControllers];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.currentViewController) {
        [self.currentViewController beginAppearanceTransition:NO animated:YES];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.currentViewController) {
        [self.currentViewController endAppearanceTransition];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.currentViewController) {
        [self.currentViewController beginAppearanceTransition:YES animated:YES];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.currentViewController) {
        [self.currentViewController endAppearanceTransition];
    }
}

#pragma mark - Private Methods
- (CGFloat)_viewWidth {
    return CGRectGetWidth(self.view.frame);
}

- (CGFloat)_viewHeight {
    return CGRectGetHeight(self.view.frame);
}

- (void)_layoutChildViewControllers {
    CGFloat viewWidth = self._viewWidth;
    CGFloat viewHeight = self._viewHeight;
    [self.activeViewControllers enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, UIViewController<VEPageItem> *obj, BOOL *stop) {
        NSUInteger veIdx = key.unsignedIntegerValue;
        if (self.isVerticalScroll) {
            obj.view.frame = CGRectMake(0, veIdx * viewHeight, viewWidth, viewHeight);
        } else {
            obj.view.frame = CGRectMake(veIdx * viewWidth, 0, viewWidth, viewHeight);
        }
    }];
    if (self.isVerticalScroll) {
        self.scrollView.contentSize = CGSizeMake(0, viewHeight * self.itemCount);
    } else {
        self.scrollView.contentSize = CGSizeMake(viewWidth * self.itemCount, 0);
    }
}

- (void)_reloadDataIfNeeded {
    if (self.needReloadData) {
        [self reloadData];
    }
}

- (void)_clearData {
    for (UIViewController<VEPageItem> *vc in self.activeViewControllers.allValues) {
        [self _removeChildViewControllerFromDataSource:vc];
    }
    self.currentDirection = VEPageItemMoveDirectionUnknown;
    self.itemCount = 0;
    self.currentIndex = VEPageMaxCount;
}

- (UIViewController<VEPageItem> *)_addChildViewControllerFromDataSourceIndex:(NSUInteger)index {
    UIViewController<VEPageItem> *viewController = self.activeViewControllers[@(index)];
    if (viewController.veTransitioning) {
        viewController.veTransitioning = NO;
        [viewController endAppearanceTransition];
    }
    if (viewController) return viewController;
    viewController = [self.dataSource pageViewController:self pageForItemAtIndex:index];
    if (!viewController) {
        [NSException raise:VEPageViewControllerExceptionKey format:@"VEPageViewController(%p) pageViewController:pageForItemAtIndex: must return a no nil instance", self];
    }

    [self addChildViewController:viewController];
    if (self.isVerticalScroll) {
        viewController.view.frame = CGRectMake(0, index * self._viewHeight, self._viewWidth, self._viewHeight);
    } else {
        viewController.view.frame = CGRectMake(index * self._viewWidth, 0, self._viewWidth, self._viewHeight);
    }
    [self.scrollView addSubview:viewController.view];
    [viewController didMoveToParentViewController:self];
    viewController.veIndex = index;
    self.activeViewControllers[@(index)] = viewController;
    if ([viewController respondsToSelector:@selector(itemDidLoad)]) {
        [viewController itemDidLoad];
    }
    return viewController;
}

- (void)_removeChildViewControllerFromDataSource:(UIViewController<VEPageItem> *)removedViewController {
    [removedViewController willMoveToParentViewController:nil];
    [removedViewController.view removeFromSuperview];
    [removedViewController removeFromParentViewController];
    [self.activeViewControllers removeObjectForKey:@(removedViewController.veIndex)];
    removedViewController.veIndex = VEPageMaxCount;
    if ([removedViewController respondsToSelector:@selector(reuseIdentifier)] && removedViewController.reuseIdentifier.length) {
        NSMutableArray<UIViewController<VEPageItem> *>*reuseViewControllers = [self.cacheViewControllers objectForKey:removedViewController.reuseIdentifier];
        if (!reuseViewControllers) {
            reuseViewControllers = [[NSMutableArray<UIViewController<VEPageItem> *> alloc] init];
            [self.cacheViewControllers setObject:reuseViewControllers forKey:removedViewController.reuseIdentifier];
        }
        if (![reuseViewControllers containsObject:removedViewController]) {
            [reuseViewControllers addObject:removedViewController];
        }
    }
}

- (UIViewController<VEPageItem> *)_childViewControllerAtIndex:(NSUInteger)index {
    return self.activeViewControllers[@(index)];
}

- (void)_shouldChangeToNextPage {
    UIViewController<VEPageItem> *lastViewController = self.currentViewController;
    CGFloat page;
    if (self.isVerticalScroll) {
        page = self.scrollView.contentOffset.y / self._viewHeight + 0.5;
    } else {
        page = self.scrollView.contentOffset.x / self._viewWidth + 0.5;
    }
    if (self.currentDirection == VEPageItemMoveDirectionUnknown) {
        self.shouldChangeToNextPage = NO;
        return;
    } else if (self.currentIndex == 0 && self.currentDirection == VEPageItemMoveDirectionPrevious) {
        self.shouldChangeToNextPage = NO;
        self.currentDirection = VEPageItemMoveDirectionUnknown;
        return;
    } else if (self.currentIndex == (self.itemCount - 1) && self.currentDirection == VEPageItemMoveDirectionNext) {
        self.shouldChangeToNextPage = NO;
        self.currentDirection = VEPageItemMoveDirectionUnknown;
        return;
    } else {
        [self _setCurrentIndex:(NSInteger)page autoAdjustOffset:NO];
    }
    if (_delegateHas.hasDidEndDisplayItem) {
        [self.delegate pageViewController:self didDisplayItem:lastViewController];
    }
    [lastViewController endAppearanceTransition];
    lastViewController.veTransitioning = NO;
    if (self.currentViewController.veTransitioning) {
        [self.currentViewController endAppearanceTransition];
    }
    self.scrollView.panGestureRecognizer.enabled = YES;
    self.currentViewController.veTransitioning = NO;
    self.currentDirection = VEPageItemMoveDirectionUnknown;
    self.shouldChangeToNextPage = NO;
}

- (void)_reloadDataWithAppearanceTransition:(BOOL)appearanceTransition {
    self.needReloadData = YES;
    NSUInteger preIndex = self.currentIndex;
    [self _clearData];
    if (_dataSourceHas.hasIsVerticalPageScrollInPageViewController) {
        self.isVerticalScroll = [self.dataSource shouldScrollVertically:self];
    }
    if (_dataSourceHas.hasNumberOfItemInPageViewController) {
        self.itemCount = [self.dataSource numberOfItemInPageViewController:self];
        if (self.isVerticalScroll) {
            [self.scrollView setContentSize:CGSizeMake(0, self._viewHeight * self.itemCount)];
        } else {
            [self.scrollView setContentSize:CGSizeMake(self._viewWidth * self.itemCount, 0)];
        }
    }
    if (_dataSourceHas.hasPageForItemAtIndex) {
        if (preIndex >= _itemCount || preIndex == VEPageMaxCount) {
            [self _setCurrentIndex:0 autoAdjustOffset:appearanceTransition];
        } else {
            [self _setCurrentIndex:preIndex autoAdjustOffset:appearanceTransition];
        }
    }
    self.needReloadData = NO;
}

- (void)_setCurrentIndex:(NSUInteger)currentIndex
        autoAdjustOffset:(BOOL)autoAdjustOffset {
    if (_currentIndex == currentIndex) return;
    if (_itemCount == 0) {
        _currentIndex = currentIndex;
        return;
    }
    if (currentIndex > self.itemCount - 1) {
        [NSException raise:VEPageViewControllerExceptionKey format:@"VEPageViewController(%p) currentIndex out of bounds %lu", self, (unsigned long)currentIndex];
    }

    // Build the set of indices that should remain active: current ± 1
    NSMutableSet<NSNumber *> *requiredIndices = [NSMutableSet setWithCapacity:3];
    [requiredIndices addObject:@(currentIndex)];
    if (currentIndex > 0) {
        [requiredIndices addObject:@(currentIndex - 1)];
    }
    if (currentIndex < self.itemCount - 1) {
        [requiredIndices addObject:@(currentIndex + 1)];
    }

    // Remove VCs whose index is no longer in the window
    for (NSNumber *key in self.activeViewControllers.allKeys) {
        if (![requiredIndices containsObject:key]) {
            [self _removeChildViewControllerFromDataSource:self.activeViewControllers[key]];
        }
    }

    // Add VCs that are now in window but not yet loaded
    for (NSNumber *key in requiredIndices) {
        [self _addChildViewControllerFromDataSourceIndex:key.unsignedIntegerValue];
    }

    UIViewController *lastViewController = self.currentViewController;
    _currentIndex = currentIndex;
    self.currentViewController = self.activeViewControllers[@(currentIndex)];
    if (autoAdjustOffset) {
        if (self.isVerticalScroll) {
            self.scrollView.contentOffset = CGPointMake(0, currentIndex * self._viewHeight);
        } else {
            self.scrollView.contentOffset = CGPointMake(currentIndex * self._viewWidth, 0);
        }
        if (self.view.window) {
            [lastViewController beginAppearanceTransition:NO animated:YES];
            [lastViewController endAppearanceTransition];
            [self.currentViewController beginAppearanceTransition:YES animated:YES];
            [self.currentViewController endAppearanceTransition];
        }
    }
}

- (void)_scrollViewDidStopScroll {
    if (self.shouldChangeToNextPage) {
        [self _shouldChangeToNextPage];
    } else if (self.currentDirection != VEPageItemMoveDirectionUnknown) {
        // Partial swipe snapped back without completing a page transition — clean up
        for (UIViewController<VEPageItem> *vc in self.activeViewControllers.allValues) {
            if (vc.veTransitioning) {
                [vc endAppearanceTransition];
                vc.veTransitioning = NO;
            }
        }
        self.currentDirection = VEPageItemMoveDirectionUnknown;
    }
}

#pragma mark - Public Methods
 
- (UIViewController<VEPageItem> *)dequeueItemForReuseIdentifier:(NSString *)reuseIdentifier {
    NSMutableArray<UIViewController<VEPageItem> *> *cacheKeyViewControllers = [self.cacheViewControllers objectForKey:reuseIdentifier];
    if (!cacheKeyViewControllers) return nil;
    UIViewController<VEPageItem> *viewController = [cacheKeyViewControllers firstObject];
    if (!viewController) return nil;
    [cacheKeyViewControllers removeObjectAtIndex:0];
    if ([viewController respondsToSelector:@selector(prepareForReuse)]) {
        [viewController prepareForReuse];
    }
    return viewController;
}

- (void)reloadData {
    [self _reloadDataWithAppearanceTransition:YES];
}

- (void)reloadPreData {
    if (_currentIndex > 0) {
        if (self.isVerticalScroll) {
            [self.scrollView setContentOffset:CGPointMake(0, (self.currentIndex - 1) * self._viewHeight) animated:YES];
        } else {
            [self.scrollView setContentOffset:CGPointMake((self.currentIndex - 1) * self._viewWidth, 0) animated:YES];
        }
    }
}

- (void)reloadNextData {
    if (_currentIndex < self.itemCount - 1) {
        if (self.isVerticalScroll) {
            [self.scrollView setContentOffset:CGPointMake(0, (self.currentIndex + 1) * self._viewHeight) animated:YES];
        } else {
            [self.scrollView setContentOffset:CGPointMake((self.currentIndex + 1) * self._viewWidth, 0) animated:YES];
        }
    }
}

- (void)reloadDataWithPageIndex:(NSInteger)index animated:(BOOL)animated {
    if (index >= 0 && index < self.itemCount) {
        if (self.isVerticalScroll) {
            [self.scrollView setContentOffset:CGPointMake(0, index * self._viewHeight) animated:animated];
        } else {
            [self.scrollView setContentOffset:CGPointMake(index * self._viewWidth, 0) animated:animated];
        }
    }
}

- (void)invalidateLayout {
    [self _reloadDataWithAppearanceTransition:NO];
}
  
- (void)reloadContentSize {
    if (_dataSourceHas.hasNumberOfItemInPageViewController) {
        NSInteger preItemCount = self.itemCount;
        self.itemCount = [_dataSource numberOfItemInPageViewController:self];
        BOOL resetContentOffset = preItemCount > self.itemCount;
        if (!self.isVerticalScroll) {
            [self.scrollView setContentSize:CGSizeMake(self._viewWidth * self.itemCount, 0)];
            if (resetContentOffset && self.itemCount > 0 && self.scrollView.contentOffset.x > self.scrollView.contentSize.width - self._viewWidth) {
                self.scrollView.contentOffset = CGPointMake(self._viewWidth * (self.itemCount - 1), 0);
            }
        } else {
            [self.scrollView setContentSize:CGSizeMake(0, self._viewHeight * self.itemCount)];
            if (resetContentOffset && self.itemCount > 0 && self.scrollView.contentOffset.y > self.scrollView.contentSize.height - self._viewHeight) {
                self.scrollView.contentOffset = CGPointMake(0, self._viewHeight * (self.itemCount - 1));
            }
        }
    }
}

#pragma mark - Variable Setter & Getter
- (UIScrollView *)scrollView {
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.backgroundColor = UIColor.blackColor;
        _scrollView.delegate = self;
        _scrollView.scrollsToTop = NO;
        _scrollView.pagingEnabled = YES;
        _scrollView.directionalLockEnabled = YES;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    return _scrollView;
}

- (void)setDelegate:(id<VEPageDelegate>)delegate {
    _delegate = delegate;
    _delegateHas.hasWillDisplayItem = [_delegate respondsToSelector:@selector(pageViewController:willDisplayItem:)];
    _delegateHas.hasDidEndDisplayItem = [_delegate respondsToSelector:@selector(pageViewController:didDisplayItem:)];
    _delegateHas.hasDidScrollChangeDirection = [_delegate respondsToSelector:@selector(pageViewController:didScrollChangeDirection:offsetProgress:)];
}

- (void)setDataSource:(id<VEPageDataSource>)dataSource {
    _dataSource = dataSource;
    _dataSourceHas.hasPageForItemAtIndex = [_dataSource respondsToSelector:@selector(pageViewController:pageForItemAtIndex:)];
    _dataSourceHas.hasNumberOfItemInPageViewController = [_dataSource respondsToSelector:@selector(numberOfItemInPageViewController:)];
    _dataSourceHas.hasIsVerticalPageScrollInPageViewController = [_dataSource respondsToSelector:@selector(shouldScrollVertically:)];
    _needReloadData = YES;
}

- (void)setCurrentIndex:(NSUInteger)currentIndex {
    [self _setCurrentIndex:currentIndex autoAdjustOffset:YES];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.needReloadData) return;
    if (self.isVerticalScroll && scrollView.contentOffset.x != 0) return;
    if (!self.isVerticalScroll && scrollView.contentOffset.y != 0) return;
    CGFloat offset = self.isVerticalScroll ? scrollView.contentOffset.y : scrollView.contentOffset.x;
    CGFloat pageSize = self.isVerticalScroll ? self._viewHeight : self._viewWidth;
    CGFloat offsetABS = offset - pageSize * self.currentIndex;
    CGFloat progress = fabs(offsetABS) / pageSize;
    if (offsetABS > 0 && self.currentDirection != VEPageItemMoveDirectionNext) {
        if (self.currentIndex == self.itemCount - 1) {
            return;
        }
        // Direction reversed Prev→Next: end the orphaned prev VC's appearance transition
        if (self.currentDirection == VEPageItemMoveDirectionPrevious) {
            UIViewController<VEPageItem> *prevVC = [self _childViewControllerAtIndex:self.currentIndex - 1];
            if (prevVC.veTransitioning) {
                [prevVC endAppearanceTransition];
                prevVC.veTransitioning = NO;
            }
        }
        self.currentDirection = VEPageItemMoveDirectionNext;
        if (!self.currentViewController.veTransitioning) {
            self.currentViewController.veTransitioning = YES;
            [self.currentViewController beginAppearanceTransition:NO animated:YES];
        }
        UIViewController<VEPageItem> *nextViewController = [self _childViewControllerAtIndex:self.currentIndex + 1];
        if (!nextViewController.veTransitioning) {
            nextViewController.veTransitioning = YES;
            [nextViewController beginAppearanceTransition:YES animated:YES];
        }
        if (_delegateHas.hasWillDisplayItem) {
            [self.delegate pageViewController:self willDisplayItem:nextViewController];
        }
    } else if (offsetABS < 0 && self.currentDirection != VEPageItemMoveDirectionPrevious) {
        if (self.currentIndex == 0) return;
        // Direction reversed Next→Prev: end the orphaned next VC's appearance transition
        if (self.currentDirection == VEPageItemMoveDirectionNext) {
            UIViewController<VEPageItem> *nextVC = [self _childViewControllerAtIndex:self.currentIndex + 1];
            if (nextVC.veTransitioning) {
                [nextVC endAppearanceTransition];
                nextVC.veTransitioning = NO;
            }
        }
        self.currentDirection = VEPageItemMoveDirectionPrevious;
        if (!self.currentViewController.veTransitioning) {
            self.currentViewController.veTransitioning = YES;
            [self.currentViewController beginAppearanceTransition:NO animated:YES];
        }
        UIViewController<VEPageItem> *preViewController = [self _childViewControllerAtIndex:self.currentIndex - 1];
        if (!preViewController.veTransitioning) {
            preViewController.veTransitioning = YES;
            [preViewController beginAppearanceTransition:YES animated:YES];
        }
        if (_delegateHas.hasWillDisplayItem) {
            [self.delegate pageViewController:self willDisplayItem:preViewController];
        }
    }
    if (_delegateHas.hasDidScrollChangeDirection) {
        [self.delegate pageViewController:self didScrollChangeDirection:self.currentDirection offsetProgress:(progress > 1) ? 1 : progress];
    }
    if (progress >= 1.0) {
        self.shouldChangeToNextPage = YES;
        if (progress > 1) {
            [self _shouldChangeToNextPage];
        }
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    CGPoint targetOffset = *targetContentOffset;
    CGFloat offset;
    CGFloat pageSize;
    if (self.isVerticalScroll) {
        offset = targetOffset.y;
        pageSize = self._viewHeight;
    } else {
        offset = targetOffset.x;
        pageSize = self._viewWidth;
    }
    NSUInteger idx = round(offset / pageSize);
    UIViewController<VEPageItem> *targetVC = [self _childViewControllerAtIndex:idx];
    if (targetVC != self.currentViewController) {
        if (targetVC.veTransitioning) { // fix unpair case
            scrollView.panGestureRecognizer.enabled = NO;
        }
        [targetVC endAppearanceTransition];
        targetVC.veTransitioning = NO;
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    self.currentDirection = VEPageItemMoveDirectionUnknown;
    [self.activeViewControllers enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, UIViewController<VEPageItem> *obj, BOOL *stop) {
        if (obj.veTransitioning) {
            obj.veTransitioning = NO;
            [obj endAppearanceTransition];
        }
    }];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        [self _scrollViewDidStopScroll];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self _scrollViewDidStopScroll];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self _scrollViewDidStopScroll];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [self.cacheViewControllers removeAllObjects];
}

@end
