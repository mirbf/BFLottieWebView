//
//  BFLottieWebView.m
//

#import "BFLottieWebView.h"
@import WebKit;

NSErrorDomain const BFLottieWebViewErrorDomain = @"com.bigger.BFLottieWebView";

static NSString * const kBFLottieMessageHandlerName = @"mblottie";

typedef NS_ENUM(NSInteger, BFLottieWebViewInternalErrorCode) {
  BFLottieWebViewInternalErrorCodeMissingResource = 1,
  BFLottieWebViewInternalErrorCodeJavaScript = 2,
  BFLottieWebViewInternalErrorCodeNotReady = 3,
};

@interface BFLottieWebView () <WKScriptMessageHandler, WKNavigationDelegate>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, copy) NSString *pendingJSONBase64;
@property (nonatomic, assign) BOOL webReady;
@property (nonatomic, assign) BOOL hasFirstFrame;
@property (nonatomic, copy) void (^pendingLoadCompletion)(BOOL success, NSError * _Nullable error);

@end

@implementation BFLottieWebView

+ (WKProcessPool *)sharedProcessPool {
  static WKProcessPool *pool;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    pool = [[WKProcessPool alloc] init];
  });
  return pool;
}

+ (NSBundle *)resourceBundle {
  // CocoaPods typically packages resources into a separate .bundle.
  // With dynamic frameworks, that bundle is usually copied into the app main bundle.
  NSBundle *classBundle = [NSBundle bundleForClass:self];
  NSBundle *mainBundle = NSBundle.mainBundle;
  NSBundle *candidates[] = { classBundle, mainBundle };
  for (NSUInteger i = 0; i < 2; i++) {
    NSBundle *bundle = candidates[i];
    NSURL *resourceBundleURL = [bundle URLForResource:@"BFLottieWebView" withExtension:@"bundle"];
    if (resourceBundleURL == nil) {
      continue;
    }

    NSBundle *resourceBundle = [NSBundle bundleWithURL:resourceBundleURL];
    if (resourceBundle != nil) {
      return resourceBundle;
    }
  }
  return classBundle;
}

+ (NSURL *)toolHTMLURL {
  NSBundle *bundle = [self resourceBundle];

  NSURL *url = [bundle URLForResource:@"mblottie_web_tool" withExtension:@"html"];
  if (url == nil) {
    url = [bundle URLForResource:@"mblottie_web_tool" withExtension:@"html" subdirectory:@"Assets"];
  }
  return url;
}

+ (void)prewarm {
  static WKWebView *prewarmWebView;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSURL *htmlURL = [self toolHTMLURL];
    if (htmlURL == nil) {
      return;
    }

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.processPool = [self sharedProcessPool];

    // No message handler is installed for prewarm.
    // The JS bridge uses try/catch when posting messages.
    prewarmWebView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    prewarmWebView.opaque = NO;
    prewarmWebView.backgroundColor = UIColor.clearColor;
    prewarmWebView.scrollView.scrollEnabled = NO;

    NSURL *readAccessURL = [htmlURL URLByDeletingLastPathComponent];
    [prewarmWebView loadFileURL:htmlURL allowingReadAccessToURL:readAccessURL];
  });
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self commonInit];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if (self) {
    [self commonInit];
  }
  return self;
}

- (void)dealloc {
  // Break the strong reference cycle between WKWebView -> WKUserContentController -> message handler.
  [self.webView.configuration.userContentController removeScriptMessageHandlerForName:kBFLottieMessageHandlerName];
}

- (void)commonInit {
  _renderer = BFLottieWebRendererSVG;
  _loop = YES;
  _speed = 1.0;
  _hidesUntilFirstFrame = YES;
  _revealAnimationDuration = 0.12;

  self.backgroundColor = UIColor.clearColor;

  WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
  config.processPool = [BFLottieWebView sharedProcessPool];

  WKUserContentController *ucc = [[WKUserContentController alloc] init];
  [ucc addScriptMessageHandler:self name:kBFLottieMessageHandlerName];
  config.userContentController = ucc;

  // Avoid partial paints that can look like a flash.
  if ([config respondsToSelector:@selector(setSuppressesIncrementalRendering:)]) {
    config.suppressesIncrementalRendering = YES;
  }

  WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
  webView.translatesAutoresizingMaskIntoConstraints = NO;
  webView.navigationDelegate = self;
  webView.opaque = NO;
  webView.backgroundColor = UIColor.clearColor;
  webView.scrollView.backgroundColor = UIColor.clearColor;
  webView.scrollView.scrollEnabled = NO;

  if (@available(iOS 15.0, *)) {
    webView.underPageBackgroundColor = UIColor.clearColor;
  }

  if (self.hidesUntilFirstFrame) {
    webView.alpha = 0.0;
  }

  [self addSubview:webView];
  [NSLayoutConstraint activateConstraints:@[
    [webView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
    [webView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    [webView.topAnchor constraintEqualToAnchor:self.topAnchor],
    [webView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
  ]];
  self.webView = webView;

  self.webReady = NO;
  self.hasFirstFrame = NO;

  [self loadToolHTML];
}

- (void)loadToolHTML {
  NSURL *htmlURL = [BFLottieWebView toolHTMLURL];
  if (htmlURL == nil) {
    NSError *error = [NSError errorWithDomain:BFLottieWebViewErrorDomain
                                         code:BFLottieWebViewInternalErrorCodeMissingResource
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Missing mblottie_web_tool.html in the app bundle." }];
    [self emitError:error stage:@"missing_resource"];
    [self finishPendingLoadWithSuccess:NO error:error];
    return;
  }

  NSURL *readAccessURL = [BFLottieWebView resourceBundle].bundleURL;
  if (readAccessURL == nil) {
    readAccessURL = [htmlURL URLByDeletingLastPathComponent];
  }
  [self.webView loadFileURL:htmlURL allowingReadAccessToURL:readAccessURL];
}

// MARK: - Public

- (void)setHidesUntilFirstFrame:(BOOL)hidesUntilFirstFrame {
  _hidesUntilFirstFrame = hidesUntilFirstFrame;
  if (hidesUntilFirstFrame && !self.hasFirstFrame) {
    self.webView.alpha = 0.0;
  } else {
    self.webView.alpha = 1.0;
  }
}

- (void)setLoop:(BOOL)loop {
  _loop = loop;
  if (self.webReady) {
    NSString *js = [NSString stringWithFormat:@"window.__setLoop && window.__setLoop(%@)", loop ? @"true" : @"false"]; 
    [self.webView evaluateJavaScript:js completionHandler:nil];
  }
}

- (void)setSpeed:(CGFloat)speed {
  _speed = speed;
  if (self.webReady) {
    NSString *js = [NSString stringWithFormat:@"window.__setSpeed && window.__setSpeed(%f)", speed];
    [self.webView evaluateJavaScript:js completionHandler:nil];
  }
}

- (void)loadAnimationWithJSONData:(NSData *)jsonData completion:(void (^)(BOOL success, NSError * _Nullable error))completion {
  self.pendingLoadCompletion = completion;
  self.pendingJSONBase64 = [jsonData base64EncodedStringWithOptions:0] ?: @"";
  self.hasFirstFrame = NO;

  if (self.hidesUntilFirstFrame) {
    self.webView.alpha = 0.0;
  }

  if (self.webReady) {
    [self loadPendingAnimationIntoWeb];
  }
}

- (void)play {
  [self.webView evaluateJavaScript:@"window.__play && window.__play()" completionHandler:nil];
}

- (void)pause {
  [self.webView evaluateJavaScript:@"window.__pause && window.__pause()" completionHandler:nil];
}

- (void)stop {
  [self.webView evaluateJavaScript:@"window.__stop && window.__stop()" completionHandler:nil];
}

- (void)setProgress:(CGFloat)progress {
  CGFloat p = MIN(1.0, MAX(0.0, progress));
  NSString *js = [NSString stringWithFormat:@"window.__setProgress && window.__setProgress(%f)", p];
  [self.webView evaluateJavaScript:js completionHandler:nil];
}

- (void)selfTestWithCompletion:(void (^)(NSDictionary * _Nullable result, NSError * _Nullable error))completion {
  [self.webView evaluateJavaScript:@"window.__selfTest && window.__selfTest()"
                 completionHandler:^(id result, NSError *error) {
    NSDictionary *dict = [result isKindOfClass:[NSDictionary class]] ? (NSDictionary *)result : nil;
    completion(dict, error);
  }];
}

// MARK: - Private

- (NSString *)rendererString {
  switch (self.renderer) {
    case BFLottieWebRendererCanvas:
      return @"canvas";
    case BFLottieWebRendererSVG:
    default:
      return @"svg";
  }
}

- (void)loadPendingAnimationIntoWeb {
  if (self.pendingJSONBase64.length == 0) {
    return;
  }

  NSDictionary *opts = @{
    @"renderer": [self rendererString],
    @"loop": @(self.loop),
    @"autoplay": @NO,
    @"speed": @(self.speed),
  };

  NSString *optsJSON = @"{}";
  NSData *optsData = [NSJSONSerialization dataWithJSONObject:opts options:0 error:nil];
  if (optsData != nil) {
    optsJSON = [[NSString alloc] initWithData:optsData encoding:NSUTF8StringEncoding] ?: @"{}";
  }

  // Pass base64 as a JS string literal. Base64 normally doesn't include quotes/backslashes, but we escape anyway.
  NSString *b64 = self.pendingJSONBase64 ?: @"";
  NSString *b64Escaped = [[b64 stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
                                 stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
  NSString *b64JSON = [NSString stringWithFormat:@"\"%@\"", b64Escaped];

  NSString *js = [NSString stringWithFormat:@"window.__loadLottieBase64 && window.__loadLottieBase64(%@, %@)", b64JSON, optsJSON];

  __weak typeof(self) weakSelf = self;
  [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
    __strong typeof(weakSelf) self = weakSelf;
    if (!self) { return; }

    if (error) {
      NSError *wrapped = [NSError errorWithDomain:BFLottieWebViewErrorDomain
                                             code:BFLottieWebViewInternalErrorCodeJavaScript
                                         userInfo:@{ NSLocalizedDescriptionKey: error.localizedDescription }];
      [self emitError:wrapped stage:@"evaluateJavaScript(loadLottie)" ];
      [self finishPendingLoadWithSuccess:NO error:wrapped];
      return;
    }

    if ([result isKindOfClass:[NSNumber class]] && ![(NSNumber *)result boolValue]) {
      NSError *wrapped = [NSError errorWithDomain:BFLottieWebViewErrorDomain
                                             code:BFLottieWebViewInternalErrorCodeJavaScript
                                         userInfo:@{ NSLocalizedDescriptionKey: @"JS returned false from __loadLottieBase64" }];
      [self emitError:wrapped stage:@"js(__loadLottieBase64 returned false)" ];
      [self finishPendingLoadWithSuccess:NO error:wrapped];
    }
  }];
}

- (void)finishPendingLoadWithSuccess:(BOOL)success error:(NSError * _Nullable)error {
  if (self.pendingLoadCompletion == nil) {
    return;
  }
  void (^completion)(BOOL, NSError * _Nullable) = self.pendingLoadCompletion;
  self.pendingLoadCompletion = nil;
  completion(success, error);
}

- (void)emitEvent:(BFLottieWebEventType)event info:(NSDictionary * _Nullable)info {
  if (self.eventHandler) {
    self.eventHandler(self, event, info);
  }
}

- (void)revealIfNeeded {
  if (!self.hidesUntilFirstFrame) {
    return;
  }

  if (self.webView.alpha >= 1.0) {
    return;
  }

  NSTimeInterval duration = self.revealAnimationDuration;
  [UIView animateWithDuration:duration
                        delay:0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                   animations:^{
    self.webView.alpha = 1.0;
  } completion:nil];
}

// MARK: - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
  (void)webView;
  (void)navigation;
  // Wait for JS to post "ready" before calling into lottie-web.
}

- (void)emitError:(NSError *)error stage:(NSString *)stage {
  if (error == nil) {
    return;
  }

  NSString *message = error.localizedDescription ?: @"(unknown error)";
  NSMutableDictionary *info = [@{ @"message": message } mutableCopy];
  if (stage.length > 0) {
    info[@"stage"] = stage;
  }
  if (error.domain.length > 0) {
    info[@"domain"] = error.domain;
  }
  info[@"code"] = @(error.code);

  NSURL *failingURL = error.userInfo[NSURLErrorFailingURLErrorKey];
  if ([failingURL isKindOfClass:[NSURL class]] && failingURL.absoluteString.length > 0) {
    info[@"url"] = failingURL.absoluteString;
  }

  [self emitEvent:BFLottieWebEventTypeError info:info];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
  (void)webView;
  (void)navigation;
  self.webReady = NO;

  [self emitError:error stage:@"didFailProvisionalNavigation"];
  [self finishPendingLoadWithSuccess:NO error:error];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
  (void)webView;
  (void)navigation;
  self.webReady = NO;

  [self emitError:error stage:@"didFailNavigation"];
  [self finishPendingLoadWithSuccess:NO error:error];
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
  (void)webView;
  self.webReady = NO;

  NSError *error = [NSError errorWithDomain:BFLottieWebViewErrorDomain
                                     code:BFLottieWebViewInternalErrorCodeNotReady
                                 userInfo:@{ NSLocalizedDescriptionKey: @"WebContent process terminated" }];
  [self emitError:error stage:@"webContentProcessDidTerminate"];

  // Reload the tool page so subsequent calls can succeed.
  [self loadToolHTML];
}

// MARK: - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
  (void)userContentController;

  if (![message.name isEqualToString:kBFLottieMessageHandlerName]) {
    return;
  }

  NSDictionary *body = [message.body isKindOfClass:[NSDictionary class]] ? (NSDictionary *)message.body : nil;
  NSString *type = [body[@"type"] isKindOfClass:[NSString class]] ? body[@"type"] : nil;
  id payload = body[@"payload"];

  if ([type isEqualToString:@"ready"]) {
    self.webReady = YES;
    [self emitEvent:BFLottieWebEventTypeReady info:[payload isKindOfClass:[NSDictionary class]] ? (NSDictionary *)payload : nil];
    [self loadPendingAnimationIntoWeb];
    return;
  }

  if ([type isEqualToString:@"loaded"]) {
    [self emitEvent:BFLottieWebEventTypeAnimationLoaded info:[payload isKindOfClass:[NSDictionary class]] ? (NSDictionary *)payload : nil];
    [self finishPendingLoadWithSuccess:YES error:nil];
    return;
  }

  if ([type isEqualToString:@"firstFrame"]) {
    self.hasFirstFrame = YES;

    [self revealIfNeeded];
    [self emitEvent:BFLottieWebEventTypeFirstFrame info:nil];
    return;
  }

  if ([type isEqualToString:@"error"]) {
    NSString *messageText = [payload isKindOfClass:[NSString class]] ? (NSString *)payload : @"Unknown error";
    NSError *wrapped = [NSError errorWithDomain:BFLottieWebViewErrorDomain
                                           code:BFLottieWebViewInternalErrorCodeJavaScript
                                       userInfo:@{ NSLocalizedDescriptionKey: messageText }];
    [self emitError:wrapped stage:@"js(messageHandler)" ];
    [self finishPendingLoadWithSuccess:NO error:wrapped];
    return;
  }
}

@end
