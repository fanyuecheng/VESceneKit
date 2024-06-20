//
//  VEPageViewController.h
//  VESceneKit
//
//  Created by real on 2022/7/12.
//  Edited by Fancy on 2023/6/27.
//  Copyright © 2022 ByteDance. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, VEPageItemMoveDirection) {
    VEPageItemMoveDirectionUnknown,
    VEPageItemMoveDirectionPrevious,
    VEPageItemMoveDirectionNext
};

@class VEPageViewController;
/// 子元素能力协议，类似于UITableViewCell的继承方法
@protocol VEPageItem <NSObject>

@optional
/// 元素的重用标识
@property (nonatomic, copy) NSString *reuseIdentifier;
/// 元素将要被重用时调用
- (void)prepareForReuse;
/// 元素被加载完成时调用
- (void)itemDidLoad;

@end
/// 整体的数据源设置
@protocol VEPageDataSource <NSObject>

@required
/// 需要多少个元素，类似于numberOfRowsInSection
- (NSInteger)numberOfItemInPageViewController:(VEPageViewController *)pageViewController;
/// 类似于UITableView的cellForRow，提供对应index的item元素
- (__kindof UIViewController <VEPageItem> *)pageViewController:(VEPageViewController *)pageViewController
                                            pageForItemAtIndex:(NSUInteger)index;

@optional
/// 滑动的方向，不实现的话，默认左右滑
- (BOOL)shouldScrollVertically:(VEPageViewController *)pageViewController;

@end
/// 整体的回调接收
@protocol VEPageDelegate <NSObject>

@optional
/// 元素滚动的进度
- (void)pageViewController:(VEPageViewController *)pageViewController
  didScrollChangeDirection:(VEPageItemMoveDirection)direction
            offsetProgress:(CGFloat)progress;
/// 元素将要展示的回调
- (void)pageViewController:(VEPageViewController *)pageViewController
           willDisplayItem:(id<VEPageItem>)viewController;
/// 元素展示完成回调
- (void)pageViewController:(VEPageViewController *)pageViewController
            didDisplayItem:(id<VEPageItem>)viewController;

@end
/// 整体框架入口类，相当于UITableView
@interface VEPageViewController : UIViewController
/// 当前展示元素的位置
@property (nonatomic, assign) NSUInteger currentIndex;
/// 回调接收
@property (nonatomic, weak)   id<VEPageDelegate>delegate;
/// 数据源接收
@property (nonatomic, weak)   id<VEPageDataSource>dataSource;
/// 内部承载滚动的View
@property (nonatomic, strong, readonly) UIScrollView *scrollView;
/// 当前item
@property (nonatomic, strong, readonly) UIViewController<VEPageItem> *currentViewController;
/// 从复用池中获得一个item，同UITableView方法
- (__kindof UIViewController<VEPageItem> *)dequeueItemForReuseIdentifier:(NSString *)reuseIdentifier;
/// 完全刷新，包括content size、layout、item的生命周期
- (void)reloadData;
/// 刷新pre
- (void)reloadPreData;
/// 刷新next
- (void)reloadNextData;
/// 刷新index
- (void)reloadDataWithPageIndex:(NSInteger)index animated:(BOOL)animated;
/// 刷新content size、layout，不刷新item的生命周期
- (void)invalidateLayout;
/// 仅刷新content size
- (void)reloadContentSize;

@end

NS_ASSUME_NONNULL_END
