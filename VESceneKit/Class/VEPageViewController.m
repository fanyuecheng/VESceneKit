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

NSUInteger const VEPageMaxCount = NSIntegerMax;

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

@property (nonatomic, strong) NSMutableArray<UIViewController<VEPageItem> *> *viewControllers;

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
    self.viewControllers = [NSMutableArray array];
    self.cacheViewControllers = [NSMutableDictionary dictionary];
    [self.view addSubview:self.scrollView];
    self.currentIndex = VEPageMaxCount;
    self.needReloadData = YES;
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods {
    return NO;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    self.scrollView.frame = self.view.bounds;
    [self _reloadDataIfNeeded];
    [self _layoutChildViewControllers];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.currentViewController beginAppearanceTransition:NO animated:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.currentViewController endAppearanceTransition];
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
    [self.viewControllers enumerateObjectsUsingBlock:^(UIViewController<VEPageItem> * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (self.isVerticalScroll) {
            obj.view.frame = CGRectMake(0, idx * self._viewHeight, self._viewWidth, self._viewHeight);
        } else {
            obj.view.frame = CGRectMake(idx * self._viewWidth, 0, self._viewWidth, self._viewHeight);
        }
    }];
    [self reloadContentSize];
}

- (void)_reloadDataIfNeeded {
    if (self.needReloadData) {
        [self reloadData];
    }
}

- (void)_clearData {
    [self.viewControllers enumerateObjectsUsingBlock:^(UIViewController<VEPageItem> * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self _removeChildViewControllerFromDataSource:obj];
    }];
    [self.viewControllers removeAllObjects];
    self.currentDirection = VEPageItemMoveDirectionUnknown;
    self.itemCount = 0;
    self.currentIndex = VEPageMaxCount;
}

- (UIViewController<VEPageItem> *)_addChildViewControllerFromDataSourceIndex:(NSUInteger)index {
    UIViewController<VEPageItem> *viewController = [self _childViewControllerAtIndex:index];
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
    if ([viewController respondsToSelector:@selector(itemDidLoad)]) {
        [viewController itemDidLoad];
    }
    return viewController;
}

- (void)_removeChildViewControllerFromDataSource:(UIViewController<VEPageItem> *)removedViewController {
    [removedViewController willMoveToParentViewController:nil];
    [removedViewController.view removeFromSuperview];
    [removedViewController removeFromParentViewController];
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
    __block UIViewController<VEPageItem> *findViewController = nil;
    [self.viewControllers enumerateObjectsUsingBlock:^(UIViewController<VEPageItem> * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.veIndex == index) {
            findViewController = obj;
        }
    }];
    return findViewController;
}

- (void)_shouldChangeToNextPage {
    UIViewController<VEPageItem> *lastViewController = self.currentViewController;
    CGFloat page = _currentIndex;
    if (self.currentDirection == VEPageItemMoveDirectionNext) {
        page = self.currentIndex + 1;
    } else {
        page = self.currentIndex - 1;
    }
    if (self.isVerticalScroll) {
        page = self.scrollView.contentOffset.y / self._viewHeight + 0.5;
    } else {
        page = self.scrollView.contentOffset.x / self._viewWidth + 0.5;
    }
    if (self.currentDirection == VEPageItemMoveDirectionUnknown) {
        return;
    } else if (self.currentIndex == 0 && self.currentDirection == VEPageItemMoveDirectionPrevious) {
        return;
    } else if (self.currentIndex == (self.itemCount - 1) && self.currentDirection == VEPageItemMoveDirectionNext) {
        return;
    } else {
        [self _setCurrentIndex:(NSInteger)page autoAdjustOffset:NO];
    }
    if (_delegateHas.hasDidEndDisplayItem) {
        [self.delegate pageViewController:self didDisplayItem:lastViewController];
    }
    [lastViewController performSelector:@selector(viewDidDisappear:) withObject:@(YES)];
    lastViewController.veTransitioning = NO;
    [self.currentViewController endAppearanceTransition];
    self.scrollView.panGestureRecognizer.enabled = YES;
    self.currentViewController.veTransitioning = NO;
    self.currentDirection = VEPageItemMoveDirectionUnknown;
    self.shouldChangeToNextPage = NO;
}

- (void)_reloadDataWithAppearanceTransition:(BOOL)appearanceTransition {
    self.needReloadData = YES;
    NSInteger preIndex = self.currentIndex;
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
    NSMutableArray *addedViewControllers = [[NSMutableArray alloc] init];
    UIViewController<VEPageItem> *currentVieController = [self _addChildViewControllerFromDataSourceIndex:currentIndex];
    [addedViewControllers addObject:currentVieController];
    if (currentIndex != 0) {
        UIViewController<VEPageItem> *nextViewController = [self _addChildViewControllerFromDataSourceIndex:currentIndex - 1];
        [addedViewControllers addObject:nextViewController];
    }
    if (self.itemCount > 1 && currentIndex != self.itemCount - 1) {
        UIViewController<VEPageItem> *preViewController = [self _addChildViewControllerFromDataSourceIndex:currentIndex + 1];
        [addedViewControllers addObject:preViewController];
    }
    
    NSMutableArray *removedViewController = [[NSMutableArray alloc] init];
    [self.viewControllers enumerateObjectsUsingBlock:^(UIViewController<VEPageItem> * _Nonnull vc, NSUInteger idx, BOOL * _Nonnull stop) {
        __block BOOL findVC = NO;
        [addedViewControllers enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (vc == obj) {
                findVC = YES;
            }
        }];
        if (!findVC) {
            [removedViewController addObject:vc];
        }
    }];
    [removedViewController enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self _removeChildViewControllerFromDataSource:obj];
    }];
    [addedViewControllers enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![self.viewControllers containsObject:obj]) {
            [self.viewControllers addObject:obj];
        }
    }];
    [self.viewControllers removeObjectsInArray:removedViewController];
    UIViewController *lastViewController = self.currentViewController;
    _currentIndex = currentIndex;
    self.currentViewController = [self _childViewControllerAtIndex:_currentIndex];
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
    }
}

#pragma mark - Public Methods
 
- (UIViewController<VEPageItem> *)dequeueItemForReuseIdentifier:(NSString *)reuseIdentifier {
    NSMutableArray<UIViewController<VEPageItem> *> *cacheKeyViewControllers = [self.cacheViewControllers objectForKey:reuseIdentifier];
    if (!cacheKeyViewControllers) return nil;
    UIViewController<VEPageItem> *viewController = [cacheKeyViewControllers firstObject];
    [cacheKeyViewControllers removeObject:viewController];
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
        [self.scrollView setContentOffset:CGPointMake(0, (self.currentIndex - 1) * self.scrollView.frame.size.height) animated:YES];
    }
}

- (void)reloadNextData {
    if (_currentIndex < self.itemCount) {
        [self.scrollView setContentOffset:CGPointMake(0, (self.currentIndex + 1) * self.scrollView.frame.size.height) animated:YES];
    }
}

- (void)reloadDataWithPageIndex:(NSInteger)index animated:(BOOL)animated {
    if (index > 0 && index < self.itemCount) {
        [self.scrollView setContentOffset:CGPointMake(0, index * self.scrollView.frame.size.height) animated:animated];
    }
}

- (void)invalidateLayout {
    [self _reloadDataWithAppearanceTransition:NO];
}
  
- (void)reloadContentSize {
    if (_dataSourceHas.hasNumberOfItemInPageViewController) {
        NSInteger preItemCount = self.itemCount;
        self.itemCount = [_dataSource numberOfItemInPageViewController:self];
        if (!self.isVerticalScroll) {
            BOOL resetContentOffset = NO;
            if (preItemCount < self.itemCount) {
                resetContentOffset = YES;
            }
            [self.scrollView setContentSize:CGSizeMake(self._viewWidth * self.itemCount, 0)];
            if (resetContentOffset && self.scrollView.contentOffset.x > self.scrollView.contentSize.width - self._viewWidth) {
                self.scrollView.contentOffset = CGPointMake(self._viewWidth * (self.itemCount - 1), 0);
            }
        } else {
            BOOL resetContentOffset = NO;
            if (preItemCount < self.itemCount) {
                resetContentOffset = YES;
            }
            [self.scrollView setContentSize:CGSizeMake(0, self._viewHeight * self.itemCount)];
            if (resetContentOffset && self.scrollView.contentOffset.y > self.scrollView.contentSize.height - self._viewHeight) {
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
    if (_delegate) {
        _delegateHas.hasWillDisplayItem = [_delegate respondsToSelector:@selector(pageViewController:willDisplayItem:)];
        _delegateHas.hasDidEndDisplayItem = [_delegate respondsToSelector:@selector(pageViewController:didDisplayItem:)];
        _delegateHas.hasDidScrollChangeDirection = [_delegate respondsToSelector:@selector(pageViewController:didScrollChangeDirection:offsetProgress:)];
    }
}

- (void)setDataSource:(id<VEPageDataSource>)dataSource {
    _dataSource = dataSource;
    if (_dataSource) {
        _dataSourceHas.hasPageForItemAtIndex = [_dataSource respondsToSelector:@selector(pageViewController:pageForItemAtIndex:)];
        _dataSourceHas.hasNumberOfItemInPageViewController = [_dataSource respondsToSelector:@selector(numberOfItemInPageViewController:)];
        _dataSourceHas.hasIsVerticalPageScrollInPageViewController = [_dataSource respondsToSelector:@selector(shouldScrollVertically:)];
    }
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
    CGFloat itemWidth = self.isVerticalScroll ? self._viewHeight : self._viewWidth;
    CGFloat offsetABS = offset - itemWidth * self.currentIndex;
    UIViewController *changeToViewController = nil;
    CGFloat progress = fabs(offsetABS) / itemWidth;
    NSLog(@"zxy check abs offset = %lf", offsetABS);
    if (offsetABS > 0 && self.currentDirection != VEPageItemMoveDirectionNext) {
        if (self.currentIndex == self.itemCount - 1) {
            return;
        }
        self.currentDirection = VEPageItemMoveDirectionNext;
        if (progress >= 0.0) {
            if (!self.currentViewController.veTransitioning) {
                self.currentViewController.veTransitioning = YES;
                [self.currentViewController beginAppearanceTransition:NO animated:YES];
            }
            UIViewController<VEPageItem> *nextViewController = [self _childViewControllerAtIndex:self.currentIndex + 1];
            if (!nextViewController.veTransitioning) {
                nextViewController.veTransitioning = YES;
                [nextViewController beginAppearanceTransition:YES animated:YES];
                changeToViewController = nextViewController;
            }
            if (_delegateHas.hasWillDisplayItem) {
                [self.delegate pageViewController:self willDisplayItem:nextViewController];
            }
        }
    } else if (offsetABS < 0 && self.currentDirection != VEPageItemMoveDirectionPrevious) {
        if (self.currentIndex == 0) return;
        self.currentDirection = VEPageItemMoveDirectionPrevious;
        if (progress >= 0.0) {
            if (!self.currentViewController.veTransitioning) {
                self.currentViewController.veTransitioning = YES;
                [self.currentViewController beginAppearanceTransition:NO animated:YES];
            }
            UIViewController<VEPageItem> *preViewController = [self _childViewControllerAtIndex:self.currentIndex - 1];
            if (!preViewController.veTransitioning) {
                preViewController.veTransitioning = YES;
                [preViewController beginAppearanceTransition:YES animated:YES];
                changeToViewController = preViewController;
            }
            if (_delegateHas.hasWillDisplayItem) {
                [self.delegate pageViewController:self willDisplayItem:preViewController];
            }
        }
    }
    if (_delegateHas.hasDidScrollChangeDirection) {
        [self.delegate pageViewController:self didScrollChangeDirection:self.currentDirection offsetProgress:(progress > 1) ? 1 : progress];
    }
    if (progress < 0.0) {
        if (self.currentViewController.veTransitioning) {
            self.currentViewController.veTransitioning = NO;
        }
        if (changeToViewController.veTransitioning) {
            changeToViewController.veTransitioning = NO;
        }
        self.currentDirection = VEPageItemMoveDirectionUnknown;
    }
    if (progress >= 1.0) {
        self.shouldChangeToNextPage = YES;
        if (progress > 1 && self.shouldChangeToNextPage) {
            [self _shouldChangeToNextPage];
        }
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    CGPoint targetOffset = *targetContentOffset;
    CGFloat offset;
    CGFloat itemLength;
    if (self.isVerticalScroll) {
        offset = targetOffset.y;
        itemLength = self._viewHeight;
    } else {
        offset = targetOffset.x;
        itemLength = self._viewWidth;
    }
    NSUInteger idx = offset / itemLength;
    UIViewController<VEPageItem> *targetVC = [self _childViewControllerAtIndex:idx];
    if (targetVC != self.currentViewController) {
        if (targetVC.veTransitioning) { // fix unpair case
            [targetVC performSelector:@selector(viewDidAppear:) withObject:@(YES)];
            scrollView.panGestureRecognizer.enabled = NO;
        }
        [targetVC endAppearanceTransition];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.viewControllers enumerateObjectsUsingBlock:^(UIViewController<VEPageItem> * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.veTransitioning) {
            obj.veTransitioning = NO;
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

@end
