//
//  CWWebViewController.m
//  CWWebViewController
//
//  Created by 深圳策维科技有限公司 on 2017/9/13.
//  Copyright © 2017年 陈伟. All rights reserved.
//

#import "CWWebViewController.h"
#import <WebKit/WebKit.h>
#import <MJRefresh/MJRefresh.h>
#import <Masonry.h>

#define SCREENBOUNDS [UIScreen mainScreen].bounds
#define NAV_HEIGHT 64
#define SCREEN_W self.view.bounds.size.width

@interface CWWebViewController ()<UIWebViewDelegate, WKNavigationDelegate, WKUIDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIWebView *ui_webView;
@property (nonatomic, strong) WKWebView *wk_webView;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) MJRefreshNormalHeader *refreshNormalHeader;
@property (nonatomic, strong) UIButton *reloadButton;

@end

@implementation CWWebViewController

//MARK: - 懒加载
- (UIWebView *)ui_webView
{
    if (!_ui_webView) {
        _ui_webView = [[UIWebView alloc]initWithFrame:CGRectZero];
        _ui_webView.delegate = self;
        _ui_webView.scrollView.showsVerticalScrollIndicator = !_hideVScIndicator;
        _ui_webView.scrollView.showsHorizontalScrollIndicator = !_hideHScIndicator;
        // 添加下拉刷新
        if ([[UIDevice currentDevice].systemVersion floatValue] >= 10.0 && _canRefresh) {
            // 当系统版本大于10.0且需要刷新
            _ui_webView.scrollView.mj_header = self.refreshNormalHeader;
        }
    }
    return _ui_webView;
}

- (WKWebView *)wk_webView
{
    if (!_wk_webView) {
        WKUserContentController *userContentController = [WKUserContentController new];
        WKUserScript *cookieScript = [[WKUserScript alloc] initWithSource:_sourceStr injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
        [userContentController addUserScript:cookieScript];
        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc]init];
        configuration.userContentController = userContentController;
        _wk_webView = [[WKWebView alloc]initWithFrame:CGRectZero configuration:configuration];
        _wk_webView.navigationDelegate = self;
        _wk_webView.UIDelegate = self;
        _wk_webView.scrollView.showsVerticalScrollIndicator = !_hideVScIndicator;
        _wk_webView.scrollView.showsHorizontalScrollIndicator = !_hideHScIndicator;
        // 允许侧滑返回至上一网页
        _wk_webView.allowsBackForwardNavigationGestures = YES;
        // 添加下拉刷新
        if ([[[UIDevice currentDevice]systemVersion]floatValue] >= 10.0 && _canRefresh) {
            _wk_webView.scrollView.mj_header = self.refreshNormalHeader;
        }
        // 监听网页的加载进度
        [_wk_webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:NULL];
    }
    return _wk_webView;
}

- (UIProgressView *)progressView
{
    if (_progressView != nil) return _progressView;
    _progressView = [[UIProgressView alloc]init];
    // 显示/隐藏导航栏
    _progressView.frame = _isHideNavigationBar ? CGRectMake(0, 20, SCREEN_W, 3) :CGRectMake(0, NAV_HEIGHT, SCREEN_W, 3);
    _progressView.progressTintColor = _progressViewColor == nil? [UIColor orangeColor] : _progressViewColor;

    return _progressView;
}

- (MJRefreshNormalHeader *)refreshNormalHeader
{
    if (_refreshNormalHeader != nil) return _refreshNormalHeader;
    _refreshNormalHeader = [MJRefreshNormalHeader headerWithRefreshingTarget:self refreshingAction:@selector(reload)];
    
    return _refreshNormalHeader;
}

#pragma mark - 生命周期
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.automaticallyAdjustsScrollViewInsets = NO;
    [self.view addSubview:self.reloadButton];
    
    [self createWebView];
    [self loadRequest];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshWorkView:) name:SHOW_NAVBAR_NOTIFI object:nil];
}

- (void)refreshWorkView:(NSNotification *)info
{
    [self showNavigationBar];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self showNavigationBar];
    //设置代理
    self.navigationController.interactivePopGestureRecognizer.delegate = self;
    //启用系统自带的滑动手势
    self.navigationController.interactivePopGestureRecognizer.enabled = !_offPopGesture;
    
}
// 导航栏操作
- (void)showNavigationBar
{
    [self.navigationController setNavigationBarHidden:_isHideNavigationBar];
    if (_isHideNavigationBar == NO) {
        self.navigationController.navigationBar.translucent = YES;
    }
}

//MARK: - 创建并添加 webView
- (void)createWebView
{
    if (_useUIWebView) {// 使用 UIWebView
        [self.view addSubview:self.ui_webView];
        if (_isHideNavigationBar) { // 隐藏
            [self.ui_webView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.edges.mas_equalTo(UIEdgeInsetsMake(20, 0, 0, 0));
            }];
        }else {
            [self.ui_webView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.edges.mas_equalTo(UIEdgeInsetsMake(NAV_HEIGHT, 0, 0, 0));
            }];
        }
    }else {
        [self.view addSubview:self.wk_webView];
        [self.view addSubview:self.progressView];
        if (_isHideNavigationBar) { // 隐藏
            [self.wk_webView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.edges.mas_equalTo(UIEdgeInsetsMake(20, 0, 0, 0));
            }];
        }else {
            [self.wk_webView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.edges.mas_equalTo(UIEdgeInsetsMake(NAV_HEIGHT, 0, 0, 0));
            }];
        }
    }
}

// 页面销毁
- (void)dealloc {
    [_wk_webView removeObserver:self forKeyPath:@"estimatedProgress"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_wk_webView stopLoading];
    [_ui_webView stopLoading];
    _wk_webView.UIDelegate = nil;
    _wk_webView.navigationDelegate = nil;
    _ui_webView.delegate = nil;
}

// 监听进度条
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context{
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        // 防止进度条回退, goback可能会出现这种情况
        if ([change[@"new"] floatValue] < [change[@"old"] floatValue]) return;
        
        _progressView.progress = [change[@"new"] floatValue];
        if (_progressView.progress == 1.0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                _progressView.hidden = YES;
            });
        }
    }else{
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

// 刷新网页
- (void)reload
{
    [_wk_webView reload];
    [_ui_webView reload];
    
}

- (UIButton*)reloadButton {
    if (!_reloadButton) {
        _reloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _reloadButton.frame = CGRectMake(0, 0, 150, 150);
        _reloadButton.center = self.view.center;
        _reloadButton.layer.cornerRadius = 75.0;
        NSString *normalImage = _reloadButtonImage == nil? @"sure_placeholder_error" : _reloadButtonImage;
        [_reloadButton setBackgroundImage:[UIImage imageNamed:normalImage] forState:UIControlStateNormal];
        [_reloadButton setTitle:@"您的网络有问题，请检查您的网络设置" forState:UIControlStateNormal];
        [_reloadButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        [_reloadButton setTitleEdgeInsets:UIEdgeInsetsMake(200, -50, 0, -50)];
        _reloadButton.titleLabel.numberOfLines = 0;
        _reloadButton.titleLabel.textAlignment = NSTextAlignmentCenter;
        CGRect rect = _reloadButton.frame;
        rect.origin.y -= 100;
        _reloadButton.frame = rect;
        _reloadButton.enabled = NO;
    }
    return _reloadButton;
}

// 设置 cookie
- (void)setCookieWithName:(NSString *)cookieName cookieValue:(NSString *)cookieValue cookieDomain:(NSString *)cookieDomain cookieCommentURL:(NSString *)cookieCommentURL cookiePort:(id)cookiePort
{
    if (cookieName == nil || cookieValue == nil || cookieDomain == nil || cookiePort == nil) {
        NSLog(@"setCookie 中 值不能为空");
        return;
    }
    NSMutableDictionary *cookieProperties = [NSMutableDictionary dictionary];
    [cookieProperties setObject:cookieName forKey:NSHTTPCookieName];
    [cookieProperties setObject:cookieValue forKey:NSHTTPCookieValue];
    [cookieProperties setObject:cookieDomain forKey:NSHTTPCookieDomain];
    [cookieProperties setObject:cookieCommentURL forKey:NSHTTPCookieCommentURL];
    [cookieProperties setObject:cookiePort forKey:NSHTTPCookiePort];
    [cookieProperties setObject:@"/" forKey:NSHTTPCookiePath];
    [cookieProperties setObject:@"0" forKey:NSHTTPCookieVersion];
    
    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
}


#pragma mark 加载请求
- (void)loadRequest {
    if (![self.url hasPrefix:@"http"]) {//是否具有http前缀
        self.url = [NSString stringWithFormat:@"https://%@",self.url];
    }

    if (_useUIWebView) {
        [_ui_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.url]]];
    } else {
        if (_sourceStr != nil) {
            NSMutableURLRequest *request= [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.url]];
            [request setValue:_cookieValue forHTTPHeaderField:@"Cookie"];
            [_wk_webView loadRequest:request];
        }else {
            [_wk_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.url]]];
        }
    }
}

#pragma mark - UIWebView代理
// 是否开始加载请求
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    webView.hidden = NO;
    // 不加载空白网址
    if ([request.URL.scheme isEqual:@"about"]) {
        webView.hidden = YES;
        return NO;
    }
    
    NSString *hostname = request.URL.absoluteString;
    if ([hostname hasPrefix:@"next://"] || [hostname containsString:@"returnOrder"]) {
        [self.navigationController popViewControllerAnimated:YES];
    }
    
    return YES;
}
// 加载成功
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    // 获取 html 文本标题为导航栏标题
    if (self.title == nil) {
        self.title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    }
    [_refreshNormalHeader endRefreshing];
}
// 加载失败
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    webView.hidden = YES;
}



#pragma mark - WKWebView 代理
//MARK: - 拦截html的交互事件
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:
(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {

    NSString *hostname = navigationAction.request.URL.absoluteString;
    if ([hostname hasPrefix:@"next://"] || [hostname containsString:@"returnOrder"]) {
        [self.navigationController popViewControllerAnimated:YES];
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
}

// 如果设置为不允许响应，web内容就不会传过来
- (void)webView:(WKWebView *)webView
decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse
decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    decisionHandler(WKNavigationResponsePolicyAllow);
    
}

// 开始导航跳转时会回调
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    webView.hidden = NO;
    _progressView.hidden = NO;
    if ([webView.URL.scheme isEqual:@"about"]) {
        webView.hidden = YES;
    }
}

// 导航完成时，会回调（也就是页面载入完成了）
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    // 设置导航栏标题
    if (self.title == nil) {
        [webView evaluateJavaScript:@"document.title" completionHandler:^(id _Nullable title, NSError * _Nullable error) {
            self.title = title;
        }];
    }
    // 是否打开js的复制黏贴功能
    if (_canCopy) {
        [self.wk_webView evaluateJavaScript:@"document.documentElement.style.webkitUserSelect='block';" completionHandler:nil];
        [self.wk_webView evaluateJavaScript:@"document.documentElement.style.webkitTouchCallout='block';" completionHandler:nil];
    }
    [_refreshNormalHeader endRefreshing];
}

//MARK: - HTTPS认证
- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if ([challenge previousFailureCount] == 0) {
            NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
        } else {
            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        }
    } else {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
    }
    
}


@end
