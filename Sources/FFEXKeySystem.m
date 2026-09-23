// FFEX IOS - Key System & Login Page
// Intercepts Free Fire launch → shows FFEX login UI
// Supports: GBox, Esign, Sideloadly, AppInstaller
// iOS 15/16/17/18/26/27 compatible

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include "FFEXCore.h"

// ─── Language Strings ─────────────────────────────────────────
typedef NS_ENUM(NSInteger, FFEXLanguage) {
    FFEXLangEnglish = 0,
    FFEXLangIndonesian,
    FFEXLangVietnamese,
    FFEXLangPortuguese,
    FFEXLangChinese,
    FFEXLangArabic,
};

static NSDictionary *languageStrings() {
    return @{
        @"title": @{
            @(FFEXLangEnglish):    @"FFEX IOS",
            @(FFEXLangIndonesian): @"FFEX IOS",
            @(FFEXLangVietnamese): @"FFEX IOS",
            @(FFEXLangPortuguese): @"FFEX IOS",
            @(FFEXLangChinese):    @"FFEX IOS",
            @(FFEXLangArabic):     @"FFEX IOS",
        },
        @"status_online": @{
            @(FFEXLangEnglish):    @"STATUS: ONLINE",
            @(FFEXLangIndonesian): @"STATUS: ONLINE",
            @(FFEXLangVietnamese): @"TRẠNG THÁI: TRỰC TUYẾN",
            @(FFEXLangPortuguese): @"STATUS: ONLINE",
            @(FFEXLangChinese):    @"状态：在线",
            @(FFEXLangArabic):     @"الحالة: متصل",
        },
        @"status_offline": @{
            @(FFEXLangEnglish):    @"STATUS: OFFLINE",
            @(FFEXLangIndonesian): @"STATUS: OFFLINE",
            @(FFEXLangVietnamese): @"TRẠNG THÁI: NGOẠI TUYẾN",
            @(FFEXLangPortuguese): @"STATUS: OFFLINE",
            @(FFEXLangChinese):    @"状态：离线",
            @(FFEXLangArabic):     @"الحالة: غير متصل",
        },
        @"enter_key": @{
            @(FFEXLangEnglish):    @"ENTER LICENSE KEY",
            @(FFEXLangIndonesian): @"MASUKKAN KUNCI LISENSI",
            @(FFEXLangVietnamese): @"NHẬP KHÓA BẢN QUYỀN",
            @(FFEXLangPortuguese): @"INSERIR CHAVE DE LICENÇA",
            @(FFEXLangChinese):    @"输入授权密钥",
            @(FFEXLangArabic):     @"أدخل مفتاح الترخيص",
        },
        @"login": @{
            @(FFEXLangEnglish):    @"LOGIN",
            @(FFEXLangIndonesian): @"MASUK",
            @(FFEXLangVietnamese): @"ĐĂNG NHẬP",
            @(FFEXLangPortuguese): @"ENTRAR",
            @(FFEXLangChinese):    @"登录",
            @(FFEXLangArabic):     @"تسجيل الدخول",
        },
        @"key_valid": @{
            @(FFEXLangEnglish):    @"KEY VERIFIED ✓",
            @(FFEXLangIndonesian): @"KUNCI TERVERIFIKASI ✓",
            @(FFEXLangVietnamese): @"KHÓA HỢP LỆ ✓",
            @(FFEXLangPortuguese): @"CHAVE VERIFICADA ✓",
            @(FFEXLangChinese):    @"密钥已验证 ✓",
            @(FFEXLangArabic):     @"تم التحقق من المفتاح ✓",
        },
        @"key_invalid": @{
            @(FFEXLangEnglish):    @"INVALID KEY",
            @(FFEXLangIndonesian): @"KUNCI TIDAK VALID",
            @(FFEXLangVietnamese): @"KHÓA KHÔNG HỢP LỆ",
            @(FFEXLangPortuguese): @"CHAVE INVÁLIDA",
            @(FFEXLangChinese):    @"无效密钥",
            @(FFEXLangArabic):     @"مفتاح غير صالح",
        },
        @"installing_assets": @{
            @(FFEXLangEnglish):    @"INSTALLING ASSETS...",
            @(FFEXLangIndonesian): @"MEMASANG ASET...",
            @(FFEXLangVietnamese): @"ĐANG CÀI ĐẶT TÀI NGUYÊN...",
            @(FFEXLangPortuguese): @"INSTALANDO ATIVOS...",
            @(FFEXLangChinese):    @"正在安装资源...",
            @(FFEXLangArabic):     @"جارٍ تثبيت الأصول...",
        },
        @"installing_anticheat": @{
            @(FFEXLangEnglish):    @"INSTALLING ANTICHEAT BYPASS...",
            @(FFEXLangIndonesian): @"MEMASANG BYPASS ANTICHEAT...",
            @(FFEXLangVietnamese): @"ĐANG CÀI BYPASS ANTICHEAT...",
            @(FFEXLangPortuguese): @"INSTALANDO BYPASS ANTICHEAT...",
            @(FFEXLangChinese):    @"正在安装反作弊绕过...",
            @(FFEXLangArabic):     @"جارٍ تثبيت تجاوز مكافحة الغش...",
        },
        @"loading_ff": @{
            @(FFEXLangEnglish):    @"LOADING FREE FIRE...",
            @(FFEXLangIndonesian): @"MEMUAT FREE FIRE...",
            @(FFEXLangVietnamese): @"ĐANG TẢI FREE FIRE...",
            @(FFEXLangPortuguese): @"CARREGANDO FREE FIRE...",
            @(FFEXLangChinese):    @"正在加载自由之火...",
            @(FFEXLangArabic):     @"جارٍ تحميل فري فاير...",
        },
        @"channel": @{
            @(FFEXLangEnglish):    @"CHANNEL: t.me/ffexternal",
            @(FFEXLangIndonesian): @"SALURAN: t.me/ffexternal",
            @(FFEXLangVietnamese): @"KÊNH: t.me/ffexternal",
            @(FFEXLangPortuguese): @"CANAL: t.me/ffexternal",
            @(FFEXLangChinese):    @"频道：t.me/ffexternal",
            @(FFEXLangArabic):     @"القناة: t.me/ffexternal",
        },
        @"expired": @{
            @(FFEXLangEnglish):    @"KEY EXPIRED — PLEASE RENEW",
            @(FFEXLangIndonesian): @"KUNCI KADALUARSA — HARAP PERBARUI",
            @(FFEXLangVietnamese): @"KHÓA HẾT HẠN — VUI LÒNG GIA HẠN",
            @(FFEXLangPortuguese): @"CHAVE EXPIRADA — RENOVE",
            @(FFEXLangChinese):    @"密钥已过期 — 请续期",
            @(FFEXLangArabic):     @"انتهت صلاحية المفتاح — يرجى التجديد",
        },
    };
}

static NSString *L(NSString *key, FFEXLanguage lang) {
    NSDictionary *all = languageStrings();
    NSDictionary *entry = all[key];
    if (!entry) return key;
    NSString *s = entry[@(lang)];
    return s ?: entry[@(FFEXLangEnglish)] ?: key;
}

// ─── Persistent Storage Keys ──────────────────────────────────
#define FFEX_KEY_STORAGE     @"ffex_license_key"
#define FFEX_LANG_STORAGE    @"ffex_language"
#define FFEX_EXPIRY_STORAGE  @"ffex_expiry_ts"
#define FFEX_CREATED_STORAGE @"ffex_created_ts"

// ─── API ──────────────────────────────────────────────────────
static NSString *const kFFEXApiBase = @"https://ffexxxx.vercel.app/app/api/licenses/validate";
static NSString *const kTelegramChannel = @"https://t.me/ffexternal";

// ─── Status Colors ────────────────────────────────────────────
static UIColor *colorGreen()  { return [UIColor colorWithRed:0 green:1 blue:0.4 alpha:1]; }
static UIColor *colorRed()    { return [UIColor colorWithRed:1 green:0.2 blue:0.2 alpha:1]; }
static UIColor *colorGold()   { return [UIColor colorWithRed:1 green:0.84 blue:0 alpha:1]; }
static UIColor *colorBg()     { return [UIColor colorWithRed:0.04 green:0.04 blue:0.08 alpha:0.97]; }
static UIColor *colorPanel()  { return [UIColor colorWithRed:0.08 green:0.08 blue:0.14 alpha:0.95]; }
static UIColor *colorAccent() { return [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:1]; }

// ─── FFEX Login View Controller ───────────────────────────────
@interface FFEXLoginViewController : UIViewController
@property (nonatomic, assign) FFEXLanguage currentLang;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *deviceLabel;
@property (nonatomic, strong) UILabel *iosVersionLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UITextField *keyField;
@property (nonatomic, strong) UIButton *loginButton;
@property (nonatomic, strong) UIButton *channelButton;
@property (nonatomic, strong) UIView *progressContainer;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) UILabel *expiryLabel;
@property (nonatomic, strong) UILabel *createdLabel;
@property (nonatomic, strong) UISegmentedControl *langSelector;
@property (nonatomic, assign) BOOL isOnline;
@end

@implementation FFEXLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Load saved language
    NSInteger savedLang = [[NSUserDefaults standardUserDefaults] integerForKey:FFEX_LANG_STORAGE];
    self.currentLang = (FFEXLanguage)savedLang;
    
    [self setupBackground];
    [self setupUI];
    [self checkOnlineStatus];
    [self loadSavedKey];
}

- (void)setupBackground {
    self.view.backgroundColor = colorBg();
    
    // Gradient background
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.view.bounds;
    gradient.colors = @[
        (id)[UIColor colorWithRed:0.02 green:0.02 blue:0.10 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0.05 green:0.05 blue:0.15 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0.02 green:0.02 blue:0.08 alpha:1].CGColor,
    ];
    gradient.startPoint = CGPointMake(0, 0);
    gradient.endPoint = CGPointMake(1, 1);
    [self.view.layer insertSublayer:gradient atIndex:0];
}

- (void)setupUI {
    CGFloat W = self.view.bounds.size.width;
    CGFloat H = self.view.bounds.size.height;
    CGFloat pad = 20.0;
    CGFloat panelW = MIN(W - pad*2, 360);
    CGFloat panelX = (W - panelW) / 2;
    CGFloat y = 40.0;
    
    // ── FFEX IOS Title ──
    self.titleLabel = [UILabel new];
    self.titleLabel.text = @"FFEX IOS";
    self.titleLabel.textColor = colorGold();
    self.titleLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:32] ?: [UIFont boldSystemFontOfSize:32];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.frame = CGRectMake(panelX, y, panelW, 44);
    [self.view addSubview:self.titleLabel];
    y += 50;

    // ── Language Selector ──
    NSArray *langs = @[@"EN", @"ID", @"VI", @"PT", @"CN", @"AR"];
    self.langSelector = [[UISegmentedControl alloc] initWithItems:langs];
    self.langSelector.selectedSegmentIndex = self.currentLang;
    self.langSelector.frame = CGRectMake(panelX, y, panelW, 30);
    self.langSelector.tintColor = colorAccent();
    if (@available(iOS 13.0, *)) {
        self.langSelector.selectedSegmentTintColor = colorAccent();
        [self.langSelector setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateNormal];
        [self.langSelector setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blackColor]} forState:UIControlStateSelected];
    }
    [self.langSelector addTarget:self action:@selector(langChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.langSelector];
    y += 44;
    
    // ── Panel ──
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(panelX, y, panelW, 300)];
    panel.backgroundColor = colorPanel();
    panel.layer.cornerRadius = 12;
    panel.layer.borderColor = colorAccent().CGColor;
    panel.layer.borderWidth = 1;
    [self.view addSubview:panel];
    
    CGFloat py = 16;
    CGFloat pw = panelW - 32;
    
    // Device model
    self.deviceLabel = [UILabel new];
    self.deviceLabel.text = [NSString stringWithFormat:@"DEVICE: %@", [self deviceName]];
    self.deviceLabel.textColor = [UIColor lightGrayColor];
    self.deviceLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.deviceLabel.frame = CGRectMake(16, py, pw, 18);
    [panel addSubview:self.deviceLabel];
    py += 22;
    
    // iOS Version
    self.iosVersionLabel = [UILabel new];
    self.iosVersionLabel.text = [NSString stringWithFormat:@"iOS: %@", [[UIDevice currentDevice] systemVersion]];
    self.iosVersionLabel.textColor = [UIColor lightGrayColor];
    self.iosVersionLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.iosVersionLabel.frame = CGRectMake(16, py, pw, 18);
    [panel addSubview:self.iosVersionLabel];
    py += 22;
    
    // Status
    self.statusLabel = [UILabel new];
    self.statusLabel.text = @"STATUS: CHECKING...";
    self.statusLabel.textColor = [UIColor yellowColor];
    self.statusLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightBold];
    self.statusLabel.frame = CGRectMake(16, py, pw, 18);
    [panel addSubview:self.statusLabel];
    py += 28;
    
    // Divider
    UIView *div = [[UIView alloc] initWithFrame:CGRectMake(16, py, pw, 1)];
    div.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1];
    [panel addSubview:div];
    py += 12;
    
    // Key expiry info
    self.expiryLabel = [UILabel new];
    self.expiryLabel.textColor = colorGold();
    self.expiryLabel.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    self.expiryLabel.frame = CGRectMake(16, py, pw, 16);
    [panel addSubview:self.expiryLabel];
    py += 20;
    
    self.createdLabel = [UILabel new];
    self.createdLabel.textColor = [UIColor lightGrayColor];
    self.createdLabel.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    self.createdLabel.frame = CGRectMake(16, py, pw, 16);
    [panel addSubview:self.createdLabel];
    py += 24;
    
    // Key input
    self.keyField = [[UITextField alloc] initWithFrame:CGRectMake(16, py, pw, 44)];
    self.keyField.placeholder = L(@"enter_key", self.currentLang);
    self.keyField.textColor = [UIColor whiteColor];
    self.keyField.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    self.keyField.layer.cornerRadius = 8;
    self.keyField.layer.borderColor = colorAccent().CGColor;
    self.keyField.layer.borderWidth = 1;
    self.keyField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,10,1)];
    self.keyField.leftViewMode = UITextFieldViewModeAlways;
    self.keyField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:L(@"enter_key", self.currentLang)
        attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.4 alpha:1]}];
    self.keyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.keyField.returnKeyType = UIReturnKeyDone;
    [self.keyField addTarget:self action:@selector(dismissKeyboard) forControlEvents:UIControlEventEditingDidEndOnExit];
    [panel addSubview:self.keyField];
    py += 52;
    
    // Login button
    self.loginButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.loginButton.frame = CGRectMake(16, py, pw, 44);
    [self.loginButton setTitle:L(@"login", self.currentLang) forState:UIControlStateNormal];
    self.loginButton.backgroundColor = colorAccent();
    self.loginButton.layer.cornerRadius = 8;
    self.loginButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.loginButton addTarget:self action:@selector(loginTapped) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:self.loginButton];
    py += 52;
    
    // Resize panel
    CGRect pf = panel.frame;
    pf.size.height = py + 12;
    panel.frame = pf;
    y += pf.size.height + 16;
    
    // Telegram channel button
    self.channelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.channelButton.frame = CGRectMake(panelX, y, panelW, 36);
    [self.channelButton setTitle:L(@"channel", self.currentLang) forState:UIControlStateNormal];
    [self.channelButton setTitleColor:colorAccent() forState:UIControlStateNormal];
    self.channelButton.titleLabel.font = [UIFont systemFontOfSize:12];
    [self.channelButton addTarget:self action:@selector(openChannel) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.channelButton];
    y += 44;
    
    // Progress container (hidden initially)
    self.progressContainer = [[UIView alloc] initWithFrame:CGRectMake(panelX, y, panelW, 90)];
    self.progressContainer.hidden = YES;
    self.progressContainer.backgroundColor = colorPanel();
    self.progressContainer.layer.cornerRadius = 10;
    [self.view addSubview:self.progressContainer];
    
    self.progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, panelW-32, 22)];
    self.progressLabel.textColor = colorAccent();
    self.progressLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightMedium];
    self.progressLabel.textAlignment = NSTextAlignmentCenter;
    [self.progressContainer addSubview:self.progressLabel];
    
    self.progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressBar.frame = CGRectMake(16, 48, panelW-32, 4);
    self.progressBar.progressTintColor = colorAccent();
    self.progressBar.trackTintColor = [UIColor colorWithWhite:0.2 alpha:1];
    [self.progressContainer addSubview:self.progressBar];
}

- (void)updateLabels {
    [self.loginButton setTitle:L(@"login", self.currentLang) forState:UIControlStateNormal];
    self.keyField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:L(@"enter_key", self.currentLang)
        attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.4 alpha:1]}];
    [self.channelButton setTitle:L(@"channel", self.currentLang) forState:UIControlStateNormal];
    [self updateStatusLabel];
}

- (void)updateStatusLabel {
    NSString *statusKey = self.isOnline ? @"status_online" : @"status_offline";
    self.statusLabel.text = L(statusKey, self.currentLang);
    self.statusLabel.textColor = self.isOnline ? colorGreen() : colorRed();
}

- (void)langChanged:(UISegmentedControl *)seg {
    self.currentLang = (FFEXLanguage)seg.selectedSegmentIndex;
    [[NSUserDefaults standardUserDefaults] setInteger:self.currentLang forKey:FFEX_LANG_STORAGE];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self updateLabels];
}

- (NSString *)deviceName {
    struct utsname sysInfo;
    uname(&sysInfo);
    return [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
}

- (void)checkOnlineStatus {
    NSURL *url = [NSURL URLWithString:kFFEXApiBase];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                      cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                  timeoutInterval:5.0];
    req.HTTPMethod = @"GET";
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            // If server is reachable at all, we're "online"
            self.isOnline = (error == nil && http != nil);
            [self updateStatusLabel];
            
            if (!self.isOnline) {
                // Offline: hide key field, just show saved key status
                [self showOfflineMode];
            }
        });
    }];
    [task resume];
}

- (void)showOfflineMode {
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:FFEX_KEY_STORAGE];
    if (savedKey.length > 0) {
        // Offline + saved key → disable input, show saved
        self.keyField.text = savedKey;
        self.keyField.enabled = NO;
        self.keyField.alpha = 0.6;
        [self.loginButton setTitle:L(@"key_valid", self.currentLang) forState:UIControlStateNormal];
        self.loginButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.1 alpha:1];
        // Show expiry info if available
        [self updateExpiryLabels];
    }
    // If no saved key, keep UI as is but disable login
}

- (void)loadSavedKey {
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:FFEX_KEY_STORAGE];
    if (savedKey.length > 0) {
        self.keyField.text = savedKey;
        [self updateExpiryLabels];
    }
}

- (void)updateExpiryLabels {
    NSTimeInterval expiry = [[NSUserDefaults standardUserDefaults] doubleForKey:FFEX_EXPIRY_STORAGE];
    NSTimeInterval created = [[NSUserDefaults standardUserDefaults] doubleForKey:FFEX_CREATED_STORAGE];
    
    if (expiry > 0) {
        NSDate *expiryDate = [NSDate dateWithTimeIntervalSince1970:expiry];
        NSDateFormatter *fmt = [NSDateFormatter new];
        fmt.dateFormat = @"yyyy-MM-dd HH:mm";
        NSTimeInterval remaining = expiry - [[NSDate date] timeIntervalSince1970];
        NSInteger days = MAX(0, (NSInteger)(remaining / 86400));
        self.expiryLabel.text = [NSString stringWithFormat:@"EXPIRES: %@ (%ld days)", [fmt stringFromDate:expiryDate], (long)days];
        
        // Auto-logout check
        if (remaining <= 0) {
            [self handleKeyExpired];
        }
    }
    
    if (created > 0) {
        NSDate *createdDate = [NSDate dateWithTimeIntervalSince1970:created];
        NSDateFormatter *fmt = [NSDateFormatter new];
        fmt.dateFormat = @"yyyy-MM-dd HH:mm";
        self.createdLabel.text = [NSString stringWithFormat:@"CREATED: %@", [fmt stringFromDate:createdDate]];
    }
}

- (void)handleKeyExpired {
    // Clear saved key, show expired message
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:FFEX_KEY_STORAGE];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:FFEX_EXPIRY_STORAGE];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:FFEX_CREATED_STORAGE];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    self.keyField.text = @"";
    self.keyField.enabled = YES;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FFEX IOS"
        message:L(@"expired", self.currentLang)
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)loginTapped {
    [self dismissKeyboard];
    
    NSString *key = [self.keyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (key.length == 0) return;
    
    if (!self.isOnline) {
        // Offline mode — check saved key
        NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:FFEX_KEY_STORAGE];
        if ([savedKey isEqualToString:key]) {
            NSTimeInterval expiry = [[NSUserDefaults standardUserDefaults] doubleForKey:FFEX_EXPIRY_STORAGE];
            if (expiry > [[NSDate date] timeIntervalSince1970]) {
                [self onKeyValid:nil];
                return;
            } else {
                [self handleKeyExpired];
                return;
            }
        }
        // No saved valid key and offline → show error
        [self showBanner:L(@"key_invalid", self.currentLang) color:colorRed()];
        return;
    }
    
    // Online validation
    self.loginButton.enabled = NO;
    [self.loginButton setTitle:@"VALIDATING..." forState:UIControlStateNormal];
    
    NSURL *url = [NSURL URLWithString:kFFEXApiBase];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    req.HTTPBody = [[NSString stringWithFormat:@"{\"key\":\"%@\"}", key]
                    dataUsingEncoding:NSUTF8StringEncoding];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.loginButton.enabled = YES;
            
            if (err || !data) {
                [self showBanner:L(@"key_invalid", self.currentLang) color:colorRed()];
                [self.loginButton setTitle:L(@"login", self.currentLang) forState:UIControlStateNormal];
                return;
            }
            
            NSError *jsonErr;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:0
                                                                   error:&jsonErr];
            
            BOOL valid = [json[@"valid"] boolValue] || [json[@"status"] isEqualToString:@"active"];
            
            if (valid) {
                // Save key
                [[NSUserDefaults standardUserDefaults] setObject:key forKey:FFEX_KEY_STORAGE];
                
                // Save expiry
                id expiryRaw = json[@"expires_at"] ?: json[@"expiryDate"] ?: json[@"expiry"];
                if (expiryRaw) {
                    NSTimeInterval ts = 0;
                    if ([expiryRaw isKindOfClass:[NSNumber class]]) {
                        ts = [(NSNumber *)expiryRaw doubleValue];
                    } else if ([expiryRaw isKindOfClass:[NSString class]]) {
                        NSDateFormatter *fmt = [NSDateFormatter new];
                        fmt.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
                        NSDate *d = [fmt dateFromString:expiryRaw];
                        ts = d.timeIntervalSince1970;
                    }
                    [[NSUserDefaults standardUserDefaults] setDouble:ts forKey:FFEX_EXPIRY_STORAGE];
                }
                
                // Save created
                id createdRaw = json[@"created_at"] ?: json[@"createdDate"];
                if (createdRaw) {
                    NSTimeInterval ts = 0;
                    if ([createdRaw isKindOfClass:[NSNumber class]]) {
                        ts = [(NSNumber *)createdRaw doubleValue];
                    } else if ([createdRaw isKindOfClass:[NSString class]]) {
                        NSDateFormatter *fmt = [NSDateFormatter new];
                        fmt.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
                        NSDate *d = [fmt dateFromString:createdRaw];
                        ts = d.timeIntervalSince1970;
                    }
                    [[NSUserDefaults standardUserDefaults] setDouble:ts forKey:FFEX_CREATED_STORAGE];
                }
                
                [[NSUserDefaults standardUserDefaults] synchronize];
                [self updateExpiryLabels];
                [self onKeyValid:json];
                
            } else {
                [self showBanner:L(@"key_invalid", self.currentLang) color:colorRed()];
                [self.loginButton setTitle:L(@"login", self.currentLang) forState:UIControlStateNormal];
            }
        });
    }];
    [task resume];
}

- (void)onKeyValid:(NSDictionary *)json {
    // Show KEY VERIFIED popup
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FFEX IOS"
        message:L(@"key_valid", self.currentLang)
        preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            [self startLoadingSequence];
        }];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
    
    [self.loginButton setTitle:L(@"key_valid", self.currentLang) forState:UIControlStateNormal];
    self.loginButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.1 alpha:1];
}

- (void)startLoadingSequence {
    // Show progress UI
    self.progressContainer.hidden = NO;
    self.loginButton.enabled = NO;
    self.keyField.enabled = NO;
    
    NSArray *steps = @[
        @{@"key": @"installing_assets",    @"progress": @0.3, @"delay": @1.5},
        @{@"key": @"installing_anticheat", @"progress": @0.7, @"delay": @1.5},
        @{@"key": @"loading_ff",           @"progress": @1.0, @"delay": @1.2},
    ];
    
    [self runLoadingStep:0 steps:steps];
}

- (void)runLoadingStep:(NSInteger)idx steps:(NSArray *)steps {
    if (idx >= steps.count) {
        // Done → launch Free Fire
        [self launchFreeFire];
        return;
    }
    
    NSDictionary *step = steps[idx];
    NSString *labelKey = step[@"key"];
    float progress = [step[@"progress"] floatValue];
    NSTimeInterval delay = [step[@"delay"] doubleValue];
    
    self.progressLabel.text = L(labelKey, self.currentLang);
    [self.progressBar setProgress:progress animated:YES];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self runLoadingStep:idx+1 steps:steps];
    });
}

- (void)launchFreeFire {
    // Dismiss login UI → hand control back to original game AppDelegate
    // The cheat hooks are already installed; we just dismiss this VC
    self.progressContainer.hidden = YES;
    
    // Notify FFEXCore that login is complete
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FFEXLoginComplete" object:nil];
    
    // Remove this VC from window
    [UIView animateWithDuration:0.4 animations:^{
        self.view.alpha = 0;
    } completion:^(BOOL finished) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }];
}

- (void)openChannel {
    NSURL *url = [NSURL URLWithString:kTelegramChannel];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)showBanner:(NSString *)msg color:(UIColor *)color {
    UIView *banner = [[UIView alloc] initWithFrame:CGRectMake(20, -60, self.view.bounds.size.width-40, 50)];
    banner.backgroundColor = color;
    banner.layer.cornerRadius = 8;
    
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectInset(banner.bounds, 12, 0)];
    lbl.text = msg;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont boldSystemFontOfSize:13];
    lbl.textAlignment = NSTextAlignmentCenter;
    [banner addSubview:lbl];
    [self.view addSubview:banner];
    
    [UIView animateWithDuration:0.3 animations:^{
        banner.frame = CGRectMake(20, 20, self.view.bounds.size.width-40, 50);
    } completion:^(BOOL done) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3 animations:^{
                banner.frame = CGRectMake(20, -60, self.view.bounds.size.width-40, 50);
            } completion:^(BOOL d) {
                [banner removeFromSuperview];
            }];
        });
    }];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

@end

// ─── App Delegate Hook ────────────────────────────────────────
// Intercept didFinishLaunchingWithOptions to show login FIRST
@interface FFEXAppDelegateHook : NSObject
@end

static UIWindow *ffexLoginWindow = nil;

void ffex_installLoginPage(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Check if key already saved and valid (offline fast path)
        NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:FFEX_KEY_STORAGE];
        NSTimeInterval expiry = [[NSUserDefaults standardUserDefaults] doubleForKey:FFEX_EXPIRY_STORAGE];
        BOOL hasValidSavedKey = savedKey.length > 0 && expiry > [[NSDate date] timeIntervalSince1970];
        
        // Create login window over game
        UIWindowScene *scene = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) {
                    scene = (UIWindowScene *)s;
                    break;
                }
            }
        }
        
        if (@available(iOS 13.0, *)) {
            if (scene) {
                ffexLoginWindow = [[UIWindow alloc] initWithWindowScene:scene];
            }
        }
        if (!ffexLoginWindow) {
            ffexLoginWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }
        
        ffexLoginWindow.windowLevel = UIWindowLevelAlert + 100;
        ffexLoginWindow.backgroundColor = colorBg();
        
        FFEXLoginViewController *vc = [FFEXLoginViewController new];
        ffexLoginWindow.rootViewController = vc;
        ffexLoginWindow.hidden = NO;
        [ffexLoginWindow makeKeyAndVisible];
        
        // Listen for login complete
        [[NSNotificationCenter defaultCenter] addObserverForName:@"FFEXLoginComplete"
            object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            ffexLoginWindow.hidden = YES;
            ffexLoginWindow = nil;
        }];
        
        // If we have a valid saved key and we're offline, auto-proceed after assets loading
        if (hasValidSavedKey) {
            // Will be handled by loadSavedKey + showOfflineMode
        }
    });
}
