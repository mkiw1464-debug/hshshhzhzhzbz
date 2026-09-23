// FFEX IOS - Mod Menu UI
// iOS-style glass UI, black/grey transparent
// Tap 3 fingers × 3 times to toggle
// Sidebar tabs: ESP, AIM, MISC, SETTINGS
// Portrait-safe but game runs landscape

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include "FFEXCore.h"
#include "FFEXCore.h"

// ══════════════════════════════════════════════════════════════
// THEME
// ══════════════════════════════════════════════════════════════
#define MM_BG_COLOR         [UIColor colorWithRed:0.06 green:0.06 blue:0.09 alpha:0.88]
#define MM_PANEL_COLOR      [UIColor colorWithRed:0.10 green:0.10 blue:0.15 alpha:0.92]
#define MM_SIDEBAR_COLOR    [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:0.95]
#define MM_ACCENT_COLOR     [UIColor colorWithRed:0.15 green:0.55 blue:1.00 alpha:1.00]
#define MM_RISK_COLOR       [UIColor colorWithRed:1.00 green:0.45 blue:0.00 alpha:1.00]
#define MM_GREEN_COLOR      [UIColor colorWithRed:0.20 green:0.85 blue:0.40 alpha:1.00]
#define MM_RED_COLOR        [UIColor colorWithRed:1.00 green:0.25 blue:0.25 alpha:1.00]
#define MM_TEXT_COLOR       [UIColor whiteColor]
#define MM_SUBTEXT_COLOR    [UIColor colorWithWhite:0.65 alpha:1.0]
#define MM_BORDER_COLOR     [UIColor colorWithWhite:0.25 alpha:0.6]
#define MM_SEPARATOR_COLOR  [UIColor colorWithWhite:0.2 alpha:0.8]

#define MM_CORNER_RADIUS    14.0
#define MM_SIDEBAR_W        52.0
#define MM_MENU_W           240.0
#define MM_MENU_H           500.0
#define MM_ROW_H            42.0

// ══════════════════════════════════════════════════════════════
// ESP OVERLAY VIEW
// Draws boxes, lines, names, health bars over game
// ══════════════════════════════════════════════════════════════
@interface FFEXESPOverlay : UIView
@end

@implementation FFEXESPOverlay

- (instancetype)init {
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        // Refresh 60fps
        CADisplayLink *dl = [CADisplayLink displayLinkWithTarget:self selector:@selector(refresh)];
        [dl addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return self;
}

- (void)refresh {
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    FFEXFeatures *f = ffex_getFeatures();
    if (!f->espEnabled) return;
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    
    // Enemy count top
    if (f->espDistance) {
        NSInteger enemyCount = ffex_getEnemyCount();
        NSString *countStr = [NSString stringWithFormat:@"ENEMIES: %ld", (long)enemyCount];
        NSDictionary *attrs = @{
            NSFontAttributeName: [UIFont boldSystemFontOfSize:13],
            NSForegroundColorAttributeName: MM_ACCENT_COLOR
        };
        [countStr drawAtPoint:CGPointMake(rect.size.width/2 - 50, 12) withAttributes:attrs];
    }
    
    NSArray *entities = ffex_getEntityList();
    
    for (NSValue *val in entities) {
        FFEXPlayer p;
        [val getValue:&p];
        
        if (p.isLocalPlayer) continue;
        if (!p.screenVisible) continue;
        if (p.distance > f->espMaxDistance) continue;
        
        // Color logic: knocked = red, alive = green
        UIColor *espColor = p.isKnocked ? MM_RED_COLOR : MM_GREEN_COLOR;
        CGContextSetStrokeColorWithColor(ctx, espColor.CGColor);
        
        float bx = p.screenHead.x - p.screenW/2;
        float by = p.screenHead.y;
        float bw = p.screenW;
        float bh = p.screenH;
        
        // ── Box ──
        if (f->espBox) {
            CGContextSetLineWidth(ctx, 1.5);
            // Corner box style
            float cs = bw * 0.25f; // corner size
            // Top-left
            CGContextMoveToPoint(ctx, bx, by + cs);
            CGContextAddLineToPoint(ctx, bx, by);
            CGContextAddLineToPoint(ctx, bx + cs, by);
            // Top-right
            CGContextMoveToPoint(ctx, bx + bw - cs, by);
            CGContextAddLineToPoint(ctx, bx + bw, by);
            CGContextAddLineToPoint(ctx, bx + bw, by + cs);
            // Bottom-left
            CGContextMoveToPoint(ctx, bx, by + bh - cs);
            CGContextAddLineToPoint(ctx, bx, by + bh);
            CGContextAddLineToPoint(ctx, bx + cs, by + bh);
            // Bottom-right
            CGContextMoveToPoint(ctx, bx + bw - cs, by + bh);
            CGContextAddLineToPoint(ctx, bx + bw, by + bh);
            CGContextAddLineToPoint(ctx, bx + bw, by + bh - cs);
            CGContextStrokePath(ctx);
        }
        
        // ── Line ──
        if (f->espLine) {
            UIColor *lineColor = p.isKnocked ? MM_RED_COLOR : MM_GREEN_COLOR;
            CGContextSetStrokeColorWithColor(ctx, lineColor.CGColor);
            CGContextSetLineWidth(ctx, 1.2);
            CGContextSetAlpha(ctx, 0.7);
            // Line from bottom-center of screen to player foot
            CGContextMoveToPoint(ctx, rect.size.width/2, rect.size.height);
            CGContextAddLineToPoint(ctx, p.screenFoot.x, p.screenFoot.y);
            CGContextStrokePath(ctx);
            CGContextSetAlpha(ctx, 1.0);
        }
        
        float textY = by - 14;
        
        // ── Name ──
        if (f->espName && p.nickname.length > 0) {
            UIColor *nameColor = p.isKnocked ?
                [UIColor colorWithRed:1 green:0.3 blue:0.3 alpha:1] :
                [UIColor colorWithRed:0.2 green:1 blue:0.5 alpha:1];
            
            // Name background
            CGSize nameSize = [p.nickname sizeWithAttributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:10]}];
            CGRect nameBg = CGRectMake(p.screenPos.x - nameSize.width/2 - 3, textY - 2, nameSize.width + 6, 14);
            CGContextSetFillColorWithColor(ctx, p.isKnocked ?
                [UIColor colorWithRed:0.5 green:0 blue:0 alpha:0.6].CGColor :
                [UIColor colorWithRed:0 green:0.3 blue:0 alpha:0.6].CGColor);
            CGContextFillRect(ctx, nameBg);
            
            [p.nickname drawAtPoint:CGPointMake(p.screenPos.x - nameSize.width/2, textY)
                     withAttributes:@{
                NSFontAttributeName: [UIFont boldSystemFontOfSize:10],
                NSForegroundColorAttributeName: nameColor,
            }];
            textY -= 14;
        }
        
        // ── Distance ──
        if (f->espDistance) {
            NSString *distStr = [NSString stringWithFormat:@"%.0fm", p.distance];
            CGSize ds = [distStr sizeWithAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:9]}];
            [distStr drawAtPoint:CGPointMake(p.screenPos.x - ds.width/2, by + bh + 2)
                  withAttributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:9],
                NSForegroundColorAttributeName: MM_SUBTEXT_COLOR,
            }];
        }
        
        // ── Health Bar ──
        if (f->espHealth && p.maxHp > 0) {
            float hpRatio = (float)p.curHp / (float)p.maxHp;
            float barH = bh * hpRatio;
            float barX = bx - 5;
            
            // Background
            CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.2 alpha:0.8].CGColor);
            CGContextFillRect(ctx, CGRectMake(barX, by, 3, bh));
            
            // HP fill
            UIColor *hpColor = hpRatio > 0.5f ? MM_GREEN_COLOR :
                               hpRatio > 0.25f ? [UIColor yellowColor] : MM_RED_COLOR;
            CGContextSetFillColorWithColor(ctx, hpColor.CGColor);
            CGContextFillRect(ctx, CGRectMake(barX, by + bh - barH, 3, barH));
            
            // HP text
            NSString *hpStr = [NSString stringWithFormat:@"%d", p.curHp];
            [hpStr drawAtPoint:CGPointMake(barX - 20, by + bh/2 - 5)
                withAttributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:9],
                NSForegroundColorAttributeName: hpColor,
            }];
        }
    }
    
    // ── Draw FOV Circle ──
    FFEXFeatures *feats = ffex_getFeatures();
    if (feats->aimEnabled && feats->drawFov) {
        CGPoint center = CGPointMake(rect.size.width/2, rect.size.height/2);
        CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1 alpha:0.25].CGColor);
        CGContextSetLineWidth(ctx, 1.0);
        CGContextAddArc(ctx, center.x, center.y, feats->fovRadius, 0, M_PI*2, 0);
        CGContextStrokePath(ctx);
    }
    
    CGContextRestoreGState(ctx);
}

@end

// ══════════════════════════════════════════════════════════════
// MOD MENU ROW
// ══════════════════════════════════════════════════════════════
@interface FFEXMenuRow : UIView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UISwitch *toggle;
@property (nonatomic, strong) UILabel *riskLabel;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, copy)   void (^onToggle)(BOOL);
@property (nonatomic, copy)   void (^onSliderChange)(float);
- (instancetype)initWithTitle:(NSString *)title isRisk:(BOOL)risk;
- (instancetype)initSliderWithTitle:(NSString *)title min:(float)min max:(float)max value:(float)val;
@end

@implementation FFEXMenuRow

- (instancetype)initWithTitle:(NSString *)title isRisk:(BOOL)risk {
    self = [super initWithFrame:CGRectMake(0, 0, MM_MENU_W - MM_SIDEBAR_W, MM_ROW_H)];
    if (!self) return nil;
    self.backgroundColor = [UIColor clearColor];
    
    self.titleLabel = [UILabel new];
    self.titleLabel.text = title.uppercaseString;
    self.titleLabel.textColor = MM_TEXT_COLOR;
    self.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.titleLabel.frame = CGRectMake(12, 0, 130, MM_ROW_H);
    [self addSubview:self.titleLabel];
    
    if (risk) {
        self.riskLabel = [UILabel new];
        self.riskLabel.text = @"RISK";
        self.riskLabel.textColor = MM_RISK_COLOR;
        self.riskLabel.font = [UIFont boldSystemFontOfSize:8];
        self.riskLabel.frame = CGRectMake(12, 28, 40, 10);
        [self addSubview:self.riskLabel];
    }
    
    self.toggle = [UISwitch new];
    self.toggle.onTintColor = MM_ACCENT_COLOR;
    self.toggle.transform = CGAffineTransformMakeScale(0.75, 0.75);
    self.toggle.frame = CGRectMake(self.bounds.size.width - 56, (MM_ROW_H - 31*0.75)/2, 51*0.75, 31*0.75);
    [self.toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.toggle];
    
    // Separator
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(12, MM_ROW_H-0.5, self.bounds.size.width-24, 0.5)];
    sep.backgroundColor = MM_SEPARATOR_COLOR;
    [self addSubview:sep];
    
    return self;
}

- (instancetype)initSliderWithTitle:(NSString *)title min:(float)min max:(float)max value:(float)val {
    self = [super initWithFrame:CGRectMake(0, 0, MM_MENU_W - MM_SIDEBAR_W, MM_ROW_H + 20)];
    if (!self) return nil;
    self.backgroundColor = [UIColor clearColor];
    
    self.titleLabel = [UILabel new];
    self.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.titleLabel.textColor = MM_TEXT_COLOR;
    self.titleLabel.frame = CGRectMake(12, 4, self.bounds.size.width-24, 16);
    [self addSubview:self.titleLabel];
    
    self.slider = [[UISlider alloc] initWithFrame:CGRectMake(12, 24, self.bounds.size.width-24, 20)];
    self.slider.minimumValue = min;
    self.slider.maximumValue = max;
    self.slider.value = val;
    self.slider.minimumTrackTintColor = MM_ACCENT_COLOR;
    self.slider.maximumTrackTintColor = [UIColor colorWithWhite:0.3 alpha:1];
    [self.slider addTarget:self action:@selector(sliderMoved:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.slider];
    
    [self updateSliderTitle:title value:val];
    
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(12, self.bounds.size.height-0.5, self.bounds.size.width-24, 0.5)];
    sep.backgroundColor = MM_SEPARATOR_COLOR;
    [self addSubview:sep];
    
    return self;
}

- (void)updateSliderTitle:(NSString *)title value:(float)val {
    self.titleLabel.text = [NSString stringWithFormat:@"%@: %.0f", title.uppercaseString, val];
}

- (void)toggleChanged:(UISwitch *)sw {
    if (self.onToggle) self.onToggle(sw.isOn);
}

- (void)sliderMoved:(UISlider *)sl {
    if (self.onSliderChange) self.onSliderChange(sl.value);
    // Update label
    NSString *base = [self.titleLabel.text componentsSeparatedByString:@":"].firstObject;
    self.titleLabel.text = [NSString stringWithFormat:@"%@: %.0f", base, sl.value];
}

@end

// ══════════════════════════════════════════════════════════════
// MOD MENU VIEW CONTROLLER
// ══════════════════════════════════════════════════════════════
typedef NS_ENUM(NSInteger, FFEXMenuTab) {
    FFEXTabESP = 0,
    FFEXTabAIM,
    FFEXTabMISC,
    FFEXTabSettings,
};

@interface FFEXModMenuController : UIViewController
@property (nonatomic, strong) UIView *menuContainer;
@property (nonatomic, strong) UIView *sidebar;
@property (nonatomic, strong) UIScrollView *contentScroll;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, assign) FFEXMenuTab currentTab;
@property (nonatomic, strong) NSArray<UIButton *> *tabButtons;
@property (nonatomic, strong) FFEXESPOverlay *espOverlay;
@property (nonatomic, assign) NSInteger tapCount;
@property (nonatomic, strong) NSTimer *tapResetTimer;
@property (nonatomic, assign) BOOL menuVisible;
// Expiry countdown label (in settings tab)
@property (nonatomic, strong) NSTimer *expiryTimer;
@end

@implementation FFEXModMenuController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = NO;
    
    // ESP Overlay (always on top, passthrough)
    self.espOverlay = [[FFEXESPOverlay alloc] init];
    [self.view addSubview:self.espOverlay];
    
    // Three-finger triple-tap gesture
    UITapGestureRecognizer *tap3 = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleThreeFingerTap:)];
    tap3.numberOfTouchesRequired = 3;
    tap3.numberOfTapsRequired = 1;
    [self.view addGestureRecognizer:tap3];
    self.view.userInteractionEnabled = YES;
    
    [self buildMenuUI];
    self.menuContainer.hidden = YES;
}

- (void)handleThreeFingerTap:(UITapGestureRecognizer *)gr {
    [self.tapResetTimer invalidate];
    self.tapCount++;
    
    self.tapResetTimer = [NSTimer scheduledTimerWithTimeInterval:0.8
        target:self selector:@selector(resetTapCount) userInfo:nil repeats:NO];
    
    if (self.tapCount >= 3) {
        self.tapCount = 0;
        [self toggleMenu];
    }
}

- (void)resetTapCount {
    self.tapCount = 0;
}

- (void)toggleMenu {
    self.menuVisible = !self.menuVisible;
    
    [UIView animateWithDuration:0.25 delay:0
        usingSpringWithDamping:0.8 initialSpringVelocity:0.5
        options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.menuContainer.hidden = NO;
        self.menuContainer.alpha = self.menuVisible ? 1 : 0;
        self.menuContainer.transform = self.menuVisible ?
            CGAffineTransformIdentity :
            CGAffineTransformMakeScale(0.85, 0.85);
    } completion:^(BOOL done) {
        if (!self.menuVisible) self.menuContainer.hidden = YES;
    }];
}

- (void)buildMenuUI {
    CGRect screen = [UIScreen mainScreen].bounds;
    // Menu position: left side, vertically centered
    CGFloat menuH = MM_MENU_H;
    CGFloat menuY = (screen.size.height - menuH) / 2;
    CGFloat menuX = 10;
    
    self.menuContainer = [[UIView alloc] initWithFrame:CGRectMake(menuX, menuY, MM_MENU_W, menuH)];
    self.menuContainer.backgroundColor = MM_BG_COLOR;
    self.menuContainer.layer.cornerRadius = MM_CORNER_RADIUS;
    self.menuContainer.layer.borderColor = MM_BORDER_COLOR.CGColor;
    self.menuContainer.layer.borderWidth = 0.5;
    
    // Blur background
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = self.menuContainer.bounds;
    blurView.layer.cornerRadius = MM_CORNER_RADIUS;
    blurView.clipsToBounds = YES;
    [self.menuContainer insertSubview:blurView atIndex:0];
    
    // Header
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, MM_MENU_W, 40)];
    header.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.14 alpha:0.9];
    UILabel *headerLabel = [UILabel new];
    headerLabel.text = @"FFEX IOS";
    headerLabel.textColor = [UIColor colorWithRed:1 green:0.84 blue:0 alpha:1];
    headerLabel.font = [UIFont boldSystemFontOfSize:15];
    headerLabel.textAlignment = NSTextAlignmentCenter;
    headerLabel.frame = header.bounds;
    [header addSubview:headerLabel];
    
    // Close button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(MM_MENU_W - 36, 4, 32, 32);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [closeBtn setTitleColor:[UIColor colorWithWhite:0.6 alpha:1] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];
    [self.menuContainer addSubview:header];
    
    // Sidebar
    self.sidebar = [[UIView alloc] initWithFrame:CGRectMake(0, 40, MM_SIDEBAR_W, menuH-40)];
    self.sidebar.backgroundColor = MM_SIDEBAR_COLOR;
    UIView *sidebarRight = [[UIView alloc] initWithFrame:CGRectMake(MM_SIDEBAR_W-0.5, 0, 0.5, self.sidebar.bounds.size.height)];
    sidebarRight.backgroundColor = MM_BORDER_COLOR;
    [self.sidebar addSubview:sidebarRight];
    [self.menuContainer addSubview:self.sidebar];
    
    // Tab buttons — SF Symbols bergaya bulat seperti screenshot
    // Tab 0: ESP   → eye.circle.fill
    // Tab 1: AIM   → scope           (crosshair/target)
    // Tab 2: MISC  → bolt.circle.fill (⚡ action)
    // Tab 3: SETTINGS → key.fill
    NSArray *tabSymbols = @[
        @"eye.circle.fill",     // ESP  — mata dalam bulatan solid
        @"scope",               // AIM  — crosshair / target reticle
        @"bolt.circle.fill",    // MISC — kilat dalam bulatan
        @"key.fill",            // SETTINGS — kunci solid
    ];
    NSMutableArray *btns = [NSMutableArray new];
    for (int i = 0; i < 4; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(0, i * 58, MM_SIDEBAR_W, 56);
        btn.tag = i;

        // Konfigurasi SF Symbol
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration
            configurationWithPointSize:26
            weight:UIImageSymbolWeightMedium
            scale:UIImageSymbolScaleMedium];

        UIImage *icon = [UIImage systemImageNamed:tabSymbols[i]
                         withConfiguration:cfg];

        // Warna: tab aktif = biru accent, lain = abu gelap
        UIColor *activeColor = MM_ACCENT_COLOR;
        UIColor *inactiveColor = [UIColor colorWithWhite:0.45 alpha:1.0];

        [btn setImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
             forState:UIControlStateNormal];
        btn.tintColor = (i == 0) ? activeColor : inactiveColor;

        // Background tab aktif: segi empat rounded dengan highlight
        btn.backgroundColor = (i == 0)
            ? [UIColor colorWithRed:0.15 green:0.55 blue:1.0 alpha:0.18]
            : [UIColor clearColor];
        btn.layer.cornerRadius = 10;

        // Highlight bar kiri untuk tab aktif
        if (i == 0) {
            UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, 10, 3, 36)];
            bar.backgroundColor = activeColor;
            bar.layer.cornerRadius = 1.5;
            bar.tag = 999; // tag untuk update kemudian
            [btn addSubview:bar];
        }

        [btn addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.sidebar addSubview:btn];
        [btns addObject:btn];
    }
    self.tabButtons = btns;
    
    // Content scroll
    self.contentScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(MM_SIDEBAR_W, 40,
                                                                          MM_MENU_W - MM_SIDEBAR_W,
                                                                          menuH - 40)];
    self.contentScroll.backgroundColor = [UIColor clearColor];
    self.contentScroll.showsVerticalScrollIndicator = NO;
    [self.menuContainer addSubview:self.contentScroll];
    
    [self.view addSubview:self.menuContainer];
    
    // Load first tab
    [self loadTab:FFEXTabESP];
}

- (void)tabTapped:(UIButton *)btn {
    FFEXMenuTab tab = (FFEXMenuTab)btn.tag;

    UIColor *activeColor   = MM_ACCENT_COLOR;
    UIColor *inactiveColor = [UIColor colorWithWhite:0.45 alpha:1.0];
    UIColor *activeBg      = [UIColor colorWithRed:0.15 green:0.55 blue:1.0 alpha:0.18];

    for (UIButton *b in self.tabButtons) {
        // Reset semua ke inactive
        b.backgroundColor = [UIColor clearColor];
        b.tintColor       = inactiveColor;

        // Buang highlight bar lama
        UIView *oldBar = [b viewWithTag:999];
        [oldBar removeFromSuperview];
    }

    // Set active state
    btn.backgroundColor = activeBg;
    btn.tintColor       = activeColor;

    // Tambah bar kiri untuk tab aktif
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, 10, 3, 36)];
    bar.backgroundColor  = activeColor;
    bar.layer.cornerRadius = 1.5;
    bar.tag = 999;
    [btn addSubview:bar];

    [self loadTab:tab];
}

- (void)loadTab:(FFEXMenuTab)tab {
    self.currentTab = tab;
    
    // Remove existing content
    for (UIView *v in self.contentScroll.subviews) [v removeFromSuperview];
    
    NSMutableArray *rows = [NSMutableArray new];
    FFEXFeatures *f = ffex_getFeatures();
    
    switch (tab) {
        case FFEXTabESP:
            [rows addObject:[self makeHeaderRow:@"ESP"]];
            [rows addObject:[self makeRow:@"ESP ON/OFF" risk:NO value:f->espEnabled onChange:^(BOOL v){ f->espEnabled = v; }]];
            
            [rows addObject:[self makeHeaderRow:@"DRAW OPTIONS"]];
            [rows addObject:[self makeRow:@"ESP LINE" risk:NO value:f->espLine onChange:^(BOOL v){ f->espLine = v; }]];
            [rows addObject:[self makeRow:@"ESP BOX" risk:NO value:f->espBox onChange:^(BOOL v){ f->espBox = v; }]];
            [rows addObject:[self makeRow:@"ESP NAME" risk:NO value:f->espName onChange:^(BOOL v){ f->espName = v; }]];
            [rows addObject:[self makeRow:@"ESP HEALTH" risk:NO value:f->espHealth onChange:^(BOOL v){ f->espHealth = v; }]];
            [rows addObject:[self makeRow:@"ESP DISTANCE" risk:NO value:f->espDistance onChange:^(BOOL v){ f->espDistance = v; }]];
            
            [rows addObject:[self makeSliderRow:@"ESP DISTANCE" min:0 max:300 value:f->espMaxDistance
                onChange:^(float v){ f->espMaxDistance = v; }]];
            break;
            
        case FFEXTabAIM:
            [rows addObject:[self makeHeaderRow:@"AIMBOT"]];
            [rows addObject:[self makeRow:@"AIM ON/OFF" risk:NO value:f->aimEnabled onChange:^(BOOL v){ f->aimEnabled = v; }]];
            [rows addObject:[self makeRow:@"AIMBOT ON/OFF" risk:NO value:f->aimbotEnabled onChange:^(BOOL v){ f->aimbotEnabled = v; }]];
            
            [rows addObject:[self makeHeaderRow:@"TARGET PART"]];
            [rows addObject:[self makeSegmentRow:@[@"HEAD", @"NECK", @"CHEST", @"BODY", @"LEG"]
                selectedIndex:f->targetPart onChange:^(NSInteger idx){ f->targetPart = idx; }]];
            
            [rows addObject:[self makeHeaderRow:@"FOV"]];
            [rows addObject:[self makeRow:@"DRAW FOV" risk:NO value:f->drawFov onChange:^(BOOL v){ f->drawFov = v; }]];
            [rows addObject:[self makeSliderRow:@"FOV RADIUS" min:0 max:500 value:f->fovRadius
                onChange:^(float v){ f->fovRadius = v; }]];
            [rows addObject:[self makeRow:@"AIM FOV ON/OFF" risk:NO value:f->aimFov onChange:^(BOOL v){ f->aimFov = v; }]];
            
            [rows addObject:[self makeHeaderRow:@"SILENT"]];
            [rows addObject:[self makeRow:@"AIM SILENT ON/OFF" risk:NO value:f->aimSilent onChange:^(BOOL v){ f->aimSilent = v; }]];
            break;
            
        case FFEXTabMISC:
            [rows addObject:[self makeHeaderRow:@"MOVEMENT"]];
            [rows addObject:[self makeRow:@"SPEED RUN X2" risk:YES value:f->speedRun onChange:^(BOOL v){ f->speedRun = v; }]];
            [rows addObject:[self makeRow:@"FLY (SPAM JUMP)" risk:YES value:f->fly onChange:^(BOOL v){ f->fly = v; }]];
            
            [rows addObject:[self makeHeaderRow:@"COMBAT"]];
            [rows addObject:[self makeRow:@"FAST FIRE" risk:YES value:f->fastFire onChange:^(BOOL v){ f->fastFire = v; }]];
            [rows addObject:[self makeRow:@"AUTO FIRE" risk:YES value:f->autoFire onChange:^(BOOL v){ f->autoFire = v; }]];
            
            [rows addObject:[self makeHeaderRow:@"SURVIVAL"]];
            [rows addObject:[self makeRow:@"FAST MEDKIT" risk:YES value:f->fastMedkit onChange:^(BOOL v){ f->fastMedkit = v; }]];
            [rows addObject:[self makeRow:@"FAST REVIVE" risk:YES value:f->fastRevive onChange:^(BOOL v){ f->fastRevive = v; }]];
            break;
            
        case FFEXTabSettings: {
            [rows addObject:[self makeHeaderRow:@"SETTINGS"]];
            
            // Key expiry countdown
            UIView *expiryView = [self makeInfoRow:@"KEY EXPIRY" value:[self expiryCountdownString]];
            [rows addObject:expiryView];
            
            UIView *createdView = [self makeInfoRow:@"KEY CREATED" value:[self keyCreatedString]];
            [rows addObject:createdView];
            
            UIView *chanView = [self makeInfoRow:@"CHANNEL" value:@"t.me/ffexternal"];
            [rows addObject:chanView];
            
            [rows addObject:[self makeRow:@"STREAMPROOF" risk:NO value:f->streamproof onChange:^(BOOL v){
                f->streamproof = v;
                ffex_setStreamproof(v);
            }]];
            
            // Start expiry timer
            [self.expiryTimer invalidate];
            __unsafe_unretained typeof(self) weakSelf = self;
            self.expiryTimer = [NSTimer scheduledTimerWithTimeInterval:60.0 repeats:YES block:^(NSTimer *t) {
                [weakSelf updateExpiryRow:expiryView];
                // Auto-logout check
                NSTimeInterval expiry = [[NSUserDefaults standardUserDefaults] doubleForKey:@"ffex_expiry_ts"];
                if (expiry > 0 && expiry < [[NSDate date] timeIntervalSince1970]) {
                    [t invalidate];
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"FFEXKeyExpired" object:nil];
                }
            }];
            break;
        }
    }
    
    // Layout rows
    CGFloat y = 8;
    CGFloat contentW = MM_MENU_W - MM_SIDEBAR_W;
    for (UIView *row in rows) {
        row.frame = CGRectMake(0, y, contentW, row.frame.size.height);
        [self.contentScroll addSubview:row];
        y += row.frame.size.height;
    }
    self.contentScroll.contentSize = CGSizeMake(contentW, y + 8);
}

// ─── Row Factories ─────────────────────────────────────────────
- (UIView *)makeHeaderRow:(NSString *)title {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, MM_MENU_W - MM_SIDEBAR_W, 28)];
    v.backgroundColor = [UIColor colorWithRed:0.08 green:0.12 blue:0.20 alpha:0.8];
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, v.bounds.size.width, 28)];
    lbl.text = title;
    lbl.textColor = MM_ACCENT_COLOR;
    lbl.font = [UIFont boldSystemFontOfSize:10];
    [v addSubview:lbl];
    return v;
}

- (UIView *)makeRow:(NSString *)title risk:(BOOL)risk value:(BOOL)value onChange:(void(^)(BOOL))onChange {
    FFEXMenuRow *row = [[FFEXMenuRow alloc] initWithTitle:title isRisk:risk];
    row.toggle.on = value;
    row.onToggle = onChange;
    return row;
}

- (UIView *)makeSliderRow:(NSString *)title min:(float)min max:(float)max value:(float)val onChange:(void(^)(float))onChange {
    FFEXMenuRow *row = [[FFEXMenuRow alloc] initSliderWithTitle:title min:min max:max value:val];
    row.onSliderChange = onChange;
    return row;
}

- (UIView *)makeSegmentRow:(NSArray<NSString *> *)options selectedIndex:(NSInteger)idx onChange:(void(^)(NSInteger))onChange {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0,0,MM_MENU_W-MM_SIDEBAR_W, 50)];
    v.backgroundColor = [UIColor clearColor];
    UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:options];
    seg.selectedSegmentIndex = idx;
    seg.frame = CGRectMake(8, 8, v.bounds.size.width-16, 34);
    seg.selectedSegmentTintColor = MM_ACCENT_COLOR;
    [seg setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont systemFontOfSize:9]} forState:UIControlStateNormal];
    [seg setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blackColor], NSFontAttributeName: [UIFont boldSystemFontOfSize:9]} forState:UIControlStateSelected];
    void (^cb)(NSInteger) = onChange;
    [seg addActionForTarget:^(UIAction *a) {
        cb(seg.selectedSegmentIndex);
    } forEvent:UIControlEventValueChanged];
    [v addSubview:seg];
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(8, 49, v.bounds.size.width-16, 0.5)];
    sep.backgroundColor = MM_SEPARATOR_COLOR;
    [v addSubview:sep];
    return v;
}

- (UIView *)makeInfoRow:(NSString *)title value:(NSString *)value {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0,0,MM_MENU_W-MM_SIDEBAR_W, MM_ROW_H)];
    v.tag = 9001; // identify for updates
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 4, 90, 16)];
    titleLbl.text = title;
    titleLbl.textColor = MM_SUBTEXT_COLOR;
    titleLbl.font = [UIFont systemFontOfSize:9];
    titleLbl.tag = 1;
    [v addSubview:titleLbl];
    UILabel *valLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 20, (MM_MENU_W-MM_SIDEBAR_W)-24, 14)];
    valLbl.text = value;
    valLbl.textColor = MM_TEXT_COLOR;
    valLbl.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    valLbl.tag = 2;
    [v addSubview:valLbl];
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(12, MM_ROW_H-0.5, (MM_MENU_W-MM_SIDEBAR_W)-24, 0.5)];
    sep.backgroundColor = MM_SEPARATOR_COLOR;
    [v addSubview:sep];
    return v;
}

- (void)updateExpiryRow:(UIView *)row {
    UILabel *lbl = (UILabel *)[row viewWithTag:2];
    lbl.text = [self expiryCountdownString];
}

- (NSString *)expiryCountdownString {
    NSTimeInterval expiry = [[NSUserDefaults standardUserDefaults] doubleForKey:@"ffex_expiry_ts"];
    if (expiry == 0) return @"N/A";
    NSTimeInterval remaining = expiry - [[NSDate date] timeIntervalSince1970];
    if (remaining <= 0) return @"EXPIRED";
    NSInteger days = (NSInteger)(remaining / 86400);
    NSInteger hours = (NSInteger)((remaining - days*86400) / 3600);
    NSInteger mins = (NSInteger)((remaining - days*86400 - hours*3600) / 60);
    return [NSString stringWithFormat:@"%ldd %ldh %ldm", (long)days, (long)hours, (long)mins];
}

- (NSString *)keyCreatedString {
    NSTimeInterval created = [[NSUserDefaults standardUserDefaults] doubleForKey:@"ffex_created_ts"];
    if (created == 0) return @"N/A";
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:created];
    NSDateFormatter *fmt = [NSDateFormatter new];
    fmt.dateFormat = @"yyyy-MM-dd";
    return [fmt stringFromDate:d];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape | UIInterfaceOrientationMaskPortrait;
}

@end

// ══════════════════════════════════════════════════════════════
// INSTALL MOD MENU
// Called after login complete
// ══════════════════════════════════════════════════════════════
static FFEXModMenuController *g_modMenu = nil;

void ffex_installModMenu(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) {
                    scene = (UIWindowScene *)s;
                    break;
                }
            }
        }
        
        static UIWindow *menuWindow = nil;
        if (@available(iOS 13.0, *)) {
            if (scene) menuWindow = [[UIWindow alloc] initWithWindowScene:scene];
        }
        if (!menuWindow) menuWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        
        menuWindow.windowLevel = UIWindowLevelAlert + 50;
        menuWindow.backgroundColor = [UIColor clearColor];
        menuWindow.rootViewController = g_modMenu = [FFEXModMenuController new];
        menuWindow.hidden = NO;
        [menuWindow makeKeyAndVisible];
        
        // Listen for key expired → logout
        [[NSNotificationCenter defaultCenter] addObserverForName:@"FFEXKeyExpired"
            object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            // Clear credentials and hide menu
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ffex_license_key"];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ffex_expiry_ts"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            menuWindow.hidden = YES;
            ffex_installLoginPage(); // show login again
        }];
        
        NSLog(@"[FFEX] Mod menu installed");
    });
}
