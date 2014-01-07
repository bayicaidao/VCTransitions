//
//  ScaleAnimation.m
//  VCTransitions
//
//  Created by Tyler Tillage on 9/2/13.
//  Copyright (c) 2013 CapTech. All rights reserved.
//

#import "ScaleAnimation.h"

@interface ScaleAnimation() {
    CGFloat _startScale, _completionSpeed;
    id<UIViewControllerContextTransitioning> _context;
    UIView *_transitioningView;
    UIPinchGestureRecognizer *_pinchRecognizer;
}

-(void)updateWithPercent:(CGFloat)percent;
-(void)end:(BOOL)cancelled;

@end

@implementation ScaleAnimation

@synthesize viewForInteraction = _viewForInteraction;

-(instancetype)initWithNavigationController:(UINavigationController *)controller {
    self = [super init];
    if (self) {
        self.navigationController = controller;
        _completionSpeed = 0.2;
        
        _pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    }
    return self;
}

-(void)setViewForInteraction:(UIView *)viewForInteraction {
    if (_viewForInteraction && [_viewForInteraction.gestureRecognizers containsObject:_pinchRecognizer]) [_viewForInteraction removeGestureRecognizer:_pinchRecognizer];
    
    _viewForInteraction = viewForInteraction;
    [_viewForInteraction addGestureRecognizer:_pinchRecognizer];
}

#pragma mark - Animated Transitioning

-(void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    //Get references to the view hierarchy
    //  容器视图   转场动画在容器中进行。对于模态视图控制器的转场动画说这个控制器来展示模态视图。对于导航控制器的专场动画来说这个是Wrapper view，它控制了根视图控制器的视图的尺寸
    UIView *containerView = [transitionContext containerView];
    
    //  "From 视图控制器"      对于模态控制器的转场动画来说，这是推入或推出模态视图控制器的视图控制器。对于导航控制器来说，则是当前的视图控制器
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    
    //  "To 视图控制器"    对于模态视图控制器的转场动画说，这是被推入或推出的视图控制器。对于导航控制器来说也是如此
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    
    if (self.type == AnimationTypePresent) {
        //Add 'to' view to the hierarchy with 0.0 scale
        toViewController.view.transform = CGAffineTransformMakeScale(0.0, 0.0);
        [containerView insertSubview:toViewController.view aboveSubview:fromViewController.view];
        
        //Scale the 'to' view to to its final position
        [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
            toViewController.view.transform = CGAffineTransformMakeScale(1.0, 1.0);
        } completion:^(BOOL finished) {
            [transitionContext completeTransition:YES];
        }];
    } else if (self.type == AnimationTypeDismiss) {
        //Add 'to' view to the hierarchy
        [containerView insertSubview:toViewController.view belowSubview:fromViewController.view];
        
        //Scale the 'from' view down until it disappears
        [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
            fromViewController.view.transform = CGAffineTransformMakeScale(0.0, 0.0);
        } completion:^(BOOL finished) {
            [transitionContext completeTransition:YES];
        }];
    }
}

-(NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return 0.4;
}

-(void)animationEnded:(BOOL)transitionCompleted {
    self.interactive = NO;
}

#pragma mark - Interactive Transitioning

-(void)startInteractiveTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    //Maintain reference to context
    _context = transitionContext;
    
    //Get references to view hierarchy
    UIView *containerView = [transitionContext containerView];
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    
    //Insert 'to' view into hierarchy
    /*
     - (CGRect)initialFrameForViewController:(UIViewController *)vc;   当视图控制器的视图动画开始前的frame
     
     - (CGRect)finalFrameForViewController:(UIViewController *)vc;  当视图控制器的视图动画结束后的frame
     */
    toViewController.view.frame = [transitionContext finalFrameForViewController:toViewController];     //  当视图控制器的视图动画结束后的frame
    [containerView insertSubview:toViewController.view belowSubview:fromViewController.view];
    
    //Save reference for view to be scaled
    _transitioningView = fromViewController.view;
}

-(void)updateWithPercent:(CGFloat)percent {
    CGFloat scale = fabsf(percent-1.0);
    _transitioningView.transform = CGAffineTransformMakeScale(scale, scale);
    [_context updateInteractiveTransition:percent];
}

-(void)end:(BOOL)cancelled {
    if (cancelled) {
        [UIView animateWithDuration:_completionSpeed animations:^{
            _transitioningView.transform = CGAffineTransformMakeScale(1.0, 1.0);
        } completion:^(BOOL finished) {
            [_context cancelInteractiveTransition];
            [_context completeTransition:NO];
        }];
    } else {
        [UIView animateWithDuration:_completionSpeed animations:^{
            _transitioningView.transform = CGAffineTransformMakeScale(0.0, 0.0);
        } completion:^(BOOL finished) {
            [_context finishInteractiveTransition];
            [_context completeTransition:YES];
        }];
    }
}

-(void)handlePinch:(UIPinchGestureRecognizer *)pinch {
    CGFloat scale = pinch.scale;
	switch (pinch.state) {
		case UIGestureRecognizerStateBegan:
            _startScale = scale;
            self.interactive = YES;
            [self.navigationController popViewControllerAnimated:YES];
            break;
		case UIGestureRecognizerStateChanged: {
            CGFloat percent = (1.0 - scale/_startScale);
            [self updateWithPercent:(percent < 0.0) ? 0.0 : percent];
            break;
        }
        case UIGestureRecognizerStateEnded: {
            CGFloat percent = (1.0 - scale/_startScale);
            BOOL cancelled = ([pinch velocity] < 5.0 && percent <= 0.3);
            [self end:cancelled];
            break;
        }
        case UIGestureRecognizerStateCancelled: {
            CGFloat percent = (1.0 - scale/_startScale);
            BOOL cancelled = ([pinch velocity] < 5.0 && percent <= 0.3);
            [self end:cancelled];
            break;
        }
        case UIGestureRecognizerStatePossible:
            break;
        case UIGestureRecognizerStateFailed:
            break;
    }
}


@end
