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

/// 滚动方向
typedef NS_ENUM(NSUInteger, VEPageItemMoveDirection) {
    VEPageItemMoveDirectionUnknown,
    VEPageItemMoveDirectionPrevious,
    VEPageItemMoveDirectionNext
};

@class VEPageViewController;
/// Cell Protocol
@protocol VEPageItem <NSObject>

@optional

@property (nonatomic, copy) NSString *reuseIdentifier;
 
- (void)prepareForReuse;
 
- (void)itemDidLoad;

@end

/// Page DataSource
@protocol VEPageDataSource <NSObject>

@required

- (NSInteger)numberOfItemInPageViewController:(VEPageViewController *)pageViewController;

- (__kindof UIViewController <VEPageItem> *)pageViewController:(VEPageViewController *)pageViewController
                                            pageForItemAtIndex:(NSUInteger)index;

@optional
- (BOOL)shouldScrollVertically:(VEPageViewController *)pageViewController;

@end

@protocol VEPageDelegate <NSObject>

@optional

- (void)pageViewController:(VEPageViewController *)pageViewController
  didScrollChangeDirection:(VEPageItemMoveDirection)direction
            offsetProgress:(CGFloat)progress;

- (void)pageViewController:(VEPageViewController *)pageViewController
           willDisplayItem:(id<VEPageItem>)viewController;

- (void)pageViewController:(VEPageViewController *)pageViewController
         didDisplayItem:(id<VEPageItem>)viewController;

@end

@interface VEPageViewController : UIViewController

@property (nonatomic, assign) NSUInteger currentIndex;

@property (nonatomic, weak)   id<VEPageDelegate>delegate;

@property (nonatomic, weak)   id<VEPageDataSource>dataSource;

- (UIScrollView *)scrollView;

- (__kindof UIViewController<VEPageItem> *)dequeueItemForReuseIdentifier:(NSString *)reuseIdentifier;

- (void)reloadData;

- (void)invalidateLayout;

- (void)reloadContentSize;

@end

NS_ASSUME_NONNULL_END
