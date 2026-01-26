//
//  BFLottieWebView.h
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BFLottieWebRenderer) {
  BFLottieWebRendererSVG = 0,
  BFLottieWebRendererCanvas = 1,
};

typedef NS_ENUM(NSInteger, BFLottieWebEventType) {
  BFLottieWebEventTypeReady = 0,
  BFLottieWebEventTypeAnimationLoaded = 1,
  BFLottieWebEventTypeFirstFrame = 2,
  BFLottieWebEventTypeError = 3,
};

FOUNDATION_EXPORT NSErrorDomain const BFLottieWebViewErrorDomain;

@interface BFLottieWebView : UIView

/// Renderer used by lottie-web. Default: BFLottieWebRendererSVG.
@property (nonatomic, assign) BFLottieWebRenderer renderer;

/// Whether to loop the animation. Default: YES.
@property (nonatomic, assign) BOOL loop;

/// Playback speed. Default: 1.0.
@property (nonatomic, assign) CGFloat speed;

/// Hides the internal WKWebView until the first frame is rendered to reduce white flash.
/// Default: YES.
@property (nonatomic, assign) BOOL hidesUntilFirstFrame;

/// Duration of the reveal animation when `hidesUntilFirstFrame` is enabled. Default: 0.12.
@property (nonatomic, assign) NSTimeInterval revealAnimationDuration;

/// Event callback.
/// - info keys:
///   - Ready: { hasLottie: BOOL, lottieVersion: NSString?, ua: NSString }
///   - AnimationLoaded: { v: NSString?, renderer: NSString }
///   - Error: { message: NSString }
@property (nonatomic, copy, nullable) void (^eventHandler)(BFLottieWebView *view, BFLottieWebEventType event, NSDictionary * _Nullable info);

/// Optional warm-up to reduce the first WKWebView load time.
+ (void)prewarm;

/// Loads the given Lottie JSON.
- (void)loadAnimationWithJSONData:(NSData *)jsonData completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

- (void)play;
- (void)pause;
- (void)stop;

/// Sets playback progress (0..1).
- (void)setProgress:(CGFloat)progress;

/// JS self-test (lottie-web presence/version/UA).
- (void)selfTestWithCompletion:(void (^)(NSDictionary * _Nullable result, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
