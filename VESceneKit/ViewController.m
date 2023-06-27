//
//  ViewController.m
//  VESceneKit
//
//  Created by Fancy on 2023/6/27.
//

#import "ViewController.h"
#import "VEPageViewController.h"

@interface TestCellViewController : UIViewController <VEPageItem>

@end

@implementation TestCellViewController

@synthesize reuseIdentifier;

- (void)viewDidLoad {
    [super viewDidLoad];

}
  
- (void)prepareForReuse {
    
}

- (void)itemDidLoad {
    
}

@end

@interface ViewController () <VEPageDataSource, VEPageDelegate>

@property (nonatomic, strong) VEPageViewController *pageContainer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initialUI];
}

- (void)initialUI {
    [self addChildViewController:self.pageContainer];
    [self.view addSubview:self.pageContainer.view];
    [self.pageContainer didMoveToParentViewController:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.pageContainer.view.frame = self.view.bounds;
}

#pragma mark - Getter
- (VEPageViewController *)pageContainer {
    if (!_pageContainer) {
        _pageContainer = [VEPageViewController new];
        _pageContainer.dataSource = self;
        _pageContainer.delegate = self;
        _pageContainer.scrollView.directionalLockEnabled = YES;
        _pageContainer.scrollView.scrollsToTop = NO;
    }
    return _pageContainer;
}

#pragma mark - VEPageDataSource
- (UIViewController<VEPageItem> *)pageViewController:(VEPageViewController *)pageViewController
                                  pageForItemAtIndex:(NSUInteger)index {
 
    TestCellViewController *cell = [pageViewController dequeueItemForReuseIdentifier:@"TestCellViewController"];
    if (!cell) {
        cell = [TestCellViewController new];
        cell.reuseIdentifier = @"TestCellViewController";
    }
    cell.view.backgroundColor = [self randomColor];
    return cell;
}

- (NSInteger)numberOfItemInPageViewController:(VEPageViewController *)pageViewController {
    return 10;
}

- (BOOL)shouldScrollVertically:(VEPageViewController *)pageViewController {
    return YES;
}

#pragma mark - VEPageDelegate

- (void)pageViewController:(VEPageViewController *)pageViewController
  didScrollChangeDirection:(VEPageItemMoveDirection)direction
            offsetProgress:(CGFloat)progress {
    NSLog(@"direction %@ progress %f", @(direction), progress);
}

- (void)pageViewController:(VEPageViewController *)pageViewController
           willDisplayItem:(id<VEPageItem>)viewController {
    NSLog(@"willDisplayItem %@", viewController);
}

- (void)pageViewController:(VEPageViewController *)pageViewController
            didDisplayItem:(id<VEPageItem>)viewController {
    NSLog(@"didDisplayItem %@", viewController);
}
 
#pragma mark - Private Method
- (UIColor *)randomColor {
    return [UIColor colorWithRed:(CGFloat)random() / (CGFloat)RAND_MAX
                         green:(CGFloat)random() / (CGFloat)RAND_MAX
                          blue:(CGFloat)random() / (CGFloat)RAND_MAX
                         alpha:1.0f];
}

@end
