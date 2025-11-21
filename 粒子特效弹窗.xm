#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>

@interface AnnouncementManager : NSObject
+ (void)start;
@end

static UIWindow *am_w;
static UIView *am_overlay;
static UIView *am_container;
static UIButton *am_btn;
static UIButton *am_moreBtn;
static UIView *am_titleHost;
static UIView *am_contentHost;
static UIView *am_btnHost;
static UIView *am_moreHost;
static NSArray<CALayer *> *am_titleDots;
static NSArray<CALayer *> *am_contentDots;
static NSArray<CALayer *> *am_btnDots;
static NSArray<CALayer *> *am_moreDots;

static NSArray<NSValue *> *am_points_for_text(NSString *t, UIFont *f, CGSize sz, NSInteger step) {
    CGFloat sc = [UIScreen mainScreen].scale;
    size_t pw = (size_t)ceil(sz.width * sc);
    size_t ph = (size_t)ceil(sz.height * sc);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceGray();
    CGContextRef ctx = CGBitmapContextCreate(NULL, pw, ph, 8, pw, space, kCGImageAlphaNone);
    CGColorSpaceRelease(space);
    if (!ctx) return @[];
    CGContextSetFillColorWithColor(ctx, [UIColor blackColor].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, pw, ph));
    CGContextTranslateCTM(ctx, 0, ph);
    CGContextScaleCTM(ctx, sc, -sc);
    NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
    ps.alignment = NSTextAlignmentCenter;
    ps.lineBreakMode = NSLineBreakByWordWrapping;
    NSDictionary *attrs = @{NSFontAttributeName:f, NSForegroundColorAttributeName:[UIColor whiteColor], NSParagraphStyleAttributeName:ps};
    CGRect br = [t boundingRectWithSize:sz options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading) attributes:attrs context:nil];
    CGRect r = CGRectMake(0, (sz.height - br.size.height) * 0.5, sz.width, br.size.height);
    UIGraphicsPushContext(ctx);
    [t drawInRect:r withAttributes:attrs];
    UIGraphicsPopContext();
    UInt8 *data = (UInt8 *)CGBitmapContextGetData(ctx);
    NSMutableArray *pts = [NSMutableArray array];
    NSInteger stepPx = MAX(1, (NSInteger)(step * sc));
    if (data) {
        for (size_t y = 0; y < ph; y += stepPx) {
            size_t row = y * pw;
            for (size_t x = 0; x < pw; x += stepPx) {
                if (data[row + x] > 64) {
                    [pts addObject:[NSValue valueWithCGPoint:CGPointMake(((CGFloat)x)/sc, ((CGFloat)y)/sc)]];
                }
            }
        }
    }
    CGContextRelease(ctx);
    return pts;
}

static NSArray<NSValue *> *am_points_for_text_top(NSString *t, UIFont *f, CGSize sz, NSInteger step) {
    CGFloat sc = [UIScreen mainScreen].scale;
    size_t pw = (size_t)ceil(sz.width * sc);
    size_t ph = (size_t)ceil(sz.height * sc);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceGray();
    CGContextRef ctx = CGBitmapContextCreate(NULL, pw, ph, 8, pw, space, kCGImageAlphaNone);
    CGColorSpaceRelease(space);
    if (!ctx) return @[];
    CGContextSetFillColorWithColor(ctx, [UIColor blackColor].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, pw, ph));
    CGContextTranslateCTM(ctx, 0, ph);
    CGContextScaleCTM(ctx, sc, -sc);
    NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
    ps.alignment = NSTextAlignmentCenter;
    ps.lineBreakMode = NSLineBreakByWordWrapping;
    NSDictionary *attrs = @{NSFontAttributeName:f, NSForegroundColorAttributeName:[UIColor whiteColor], NSParagraphStyleAttributeName:ps};
    CGRect r = CGRectMake(0, 0, sz.width, sz.height);
    UIGraphicsPushContext(ctx);
    [t drawInRect:r withAttributes:attrs];
    UIGraphicsPopContext();
    UInt8 *data = (UInt8 *)CGBitmapContextGetData(ctx);
    NSMutableArray *pts = [NSMutableArray array];
    NSInteger stepPx = MAX(1, (NSInteger)(step * sc));
    if (data) {
        for (size_t y = 0; y < ph; y += stepPx) {
            size_t row = y * pw;
            for (size_t x = 0; x < pw; x += stepPx) {
                if (data[row + x] > 64) {
                    [pts addObject:[NSValue valueWithCGPoint:CGPointMake(((CGFloat)x)/sc, ((CGFloat)y)/sc)]];
                }
            }
        }
    }
    CGContextRelease(ctx);
    return pts;
}

static void am_add_border_glow(UIView *v) { }

static NSArray<CALayer *> *am_animate_particles(UIView *host, NSArray<NSValue *> *pts, NSTimeInterval dur, CGFloat dotSize, UIColor *color) {
    CGSize sz = host.bounds.size;
    NSMutableArray *dots = [NSMutableArray arrayWithCapacity:pts.count];
    for (NSValue *v in pts) {
        CGPoint tg = [v CGPointValue];
        CALayer *dot = [CALayer layer];
        dot.bounds = CGRectMake(0, 0, dotSize, dotSize);
        dot.cornerRadius = dotSize * 0.5;
        dot.backgroundColor = color.CGColor;
        CGFloat rx = (CGFloat)arc4random_uniform((uint32_t)sz.width);
        CGFloat ry = (CGFloat)arc4random_uniform((uint32_t)sz.height);
        dot.position = CGPointMake(rx, ry);
        dot.opacity = 0.0;
        [host.layer addSublayer:dot];
        CABasicAnimation *pos = [CABasicAnimation animationWithKeyPath:@"position"];
        pos.fromValue = [NSValue valueWithCGPoint:CGPointMake(rx, ry)];
        pos.toValue = [NSValue valueWithCGPoint:tg];
        pos.duration = dur + ((arc4random()%100)/500.0);
        pos.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        CABasicAnimation *al = [CABasicAnimation animationWithKeyPath:@"opacity"];
        al.fromValue = @0.0; al.toValue = @1.0; al.duration = pos.duration * 0.6;
        CAAnimationGroup *g = [CAAnimationGroup animation];
        g.animations = @[pos, al];
        g.duration = pos.duration;
        g.fillMode = kCAFillModeForwards;
        g.removedOnCompletion = NO;
        [dot addAnimation:g forKey:nil];
        dot.position = tg;
        dot.opacity = 1.0;
        [dots addObject:dot];
    }
    return dots;
}

@implementation AnnouncementManager

+ (void)start {
    if (am_w) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (am_w) return;
        am_w = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        am_w.windowLevel = UIWindowLevelAlert + 1;
        am_overlay = [[UIView alloc] initWithFrame:am_w.bounds];
        am_overlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.28];
        [am_w addSubview:am_overlay];
        CGFloat W = MIN(CGRectGetWidth(am_w.bounds) * 0.82, 360);
        CGFloat H = MIN(CGRectGetHeight(am_w.bounds) * 0.6, 360);
        am_container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, H)];
        am_container.center = am_overlay.center;
        am_container.backgroundColor = [UIColor clearColor];
        [am_overlay addSubview:am_container];
        am_container.layer.cornerRadius = 18;
        am_container.layer.shadowColor = [UIColor blackColor].CGColor;
        am_container.layer.shadowOpacity = 0.35;
        am_container.layer.shadowRadius = 24.0;
        am_container.layer.shadowOffset = CGSizeMake(0, 18);
        am_add_border_glow(am_container);
        CGSize titleSz = CGSizeMake(W - 32, 90);
        UIFont *tf = [UIFont boldSystemFontOfSize:40];
        UIFont *cf = [UIFont systemFontOfSize:24];
        NSString *contentText = @"弹窗演示\n更多关注“天籁简”";
        NSDictionary *cattrs = @{NSFontAttributeName:cf, NSParagraphStyleAttributeName:({ NSMutableParagraphStyle *p=[NSMutableParagraphStyle new]; p.alignment=NSTextAlignmentCenter; p.lineBreakMode=NSLineBreakByWordWrapping; p; }), NSForegroundColorAttributeName:[UIColor whiteColor]};
        CGRect cbr = [contentText boundingRectWithSize:CGSizeMake(W - 32, CGFLOAT_MAX) options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading) attributes:cattrs context:nil];
        CGSize contentSz = CGSizeMake(W - 32, ceil(cbr.size.height));
        NSArray *titlePts = am_points_for_text(@"公告", tf, titleSz, 1);
        NSArray *contentPts = am_points_for_text_top(contentText, cf, contentSz, 1);
        UIView *titleHost = [[UIView alloc] initWithFrame:CGRectMake(16, 24, titleSz.width, titleSz.height)];
        UIView *contentHost = [[UIView alloc] initWithFrame:CGRectMake(16, 24 + titleSz.height, contentSz.width, contentSz.height)];
        titleHost.backgroundColor = [UIColor clearColor];
        contentHost.backgroundColor = [UIColor clearColor];
        [am_container addSubview:titleHost];
        [am_container addSubview:contentHost];
        am_titleHost = titleHost;
        am_contentHost = contentHost;
        am_btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [am_btn setTitle:@"" forState:UIControlStateNormal];
        am_btn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
        am_btn.alpha = 0.0;
        CGFloat rowW = W - 32.0;
        CGFloat spacing = 12.0;
        CGFloat itemW = floor((rowW - spacing) / 2.0);
        CGFloat btnY = CGRectGetMaxY(contentHost.frame) + 36.0;
        am_btn.frame = CGRectMake(16.0, btnY, itemW, 44.0);
        am_btn.backgroundColor = [UIColor clearColor];
        [am_btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        am_btn.layer.cornerRadius = 13;
        am_btn.layer.masksToBounds = YES;
        [am_container addSubview:am_btn];
        am_moreBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [am_moreBtn setTitle:@"" forState:UIControlStateNormal];
        am_moreBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
        am_moreBtn.alpha = 0.0;
        am_moreBtn.frame = CGRectMake(16.0 + itemW + spacing, btnY, itemW, 44.0);
        am_moreBtn.backgroundColor = [UIColor clearColor];
        [am_moreBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        am_moreBtn.layer.cornerRadius = 13;
        am_moreBtn.layer.masksToBounds = YES;
        [am_container addSubview:am_moreBtn];
        UIView *btnHost = [[UIView alloc] initWithFrame:am_btn.bounds];
        btnHost.backgroundColor = [UIColor clearColor];
        btnHost.userInteractionEnabled = NO;
        [am_btn addSubview:btnHost];
        am_btnHost = btnHost;
        UIView *moreHost = [[UIView alloc] initWithFrame:am_moreBtn.bounds];
        moreHost.backgroundColor = [UIColor clearColor];
        moreHost.userInteractionEnabled = NO;
        [am_moreBtn addSubview:moreHost];
        am_moreHost = moreHost;
        CAShapeLayer *btnBorder = [CAShapeLayer layer];
        btnBorder.path = [UIBezierPath bezierPathWithRoundedRect:am_btn.bounds cornerRadius:am_btn.layer.cornerRadius].CGPath;
        btnBorder.fillColor = [UIColor colorWithWhite:1 alpha:0].CGColor;
        btnBorder.strokeColor = [UIColor colorWithRed:0.5 green:0.8 blue:1 alpha:0.75].CGColor;
        btnBorder.lineWidth = 2.4;
        btnBorder.shadowColor = [UIColor colorWithRed:0.3 green:0.7 blue:1 alpha:1].CGColor;
        btnBorder.shadowOpacity = 1.0;
        btnBorder.shadowRadius = 14.0;
        btnBorder.shadowOffset = CGSizeZero;
        [am_btn.layer addSublayer:btnBorder];
        CABasicAnimation *breath = [CABasicAnimation animationWithKeyPath:@"opacity"];
        breath.fromValue = @0.3;
        breath.toValue = @1.0;
        breath.duration = 0.9;
        breath.autoreverses = YES;
        breath.repeatCount = HUGE_VALF;
        [btnBorder addAnimation:breath forKey:@"breath"];
        CAGradientLayer *pulse = [CAGradientLayer layer];
        pulse.frame = btnHost.bounds;
        pulse.colors = @[(__bridge id)[UIColor colorWithRed:0.3 green:0.7 blue:1 alpha:0.28].CGColor,
                         (__bridge id)[UIColor colorWithRed:0.9 green:0.98 blue:1 alpha:0.28].CGColor];
        pulse.startPoint = CGPointMake(0, 0);
        pulse.endPoint = CGPointMake(1, 1);
        pulse.cornerRadius = am_btn.layer.cornerRadius;
        [btnHost.layer insertSublayer:pulse atIndex:0];
        CABasicAnimation *btnPulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
        btnPulse.fromValue = @0.2;
        btnPulse.toValue = @0.7;
        btnPulse.duration = 0.9;
        btnPulse.autoreverses = YES;
        btnPulse.repeatCount = HUGE_VALF;
        [pulse addAnimation:btnPulse forKey:@"btnPulse"];
        CAShapeLayer *moreBorder = [CAShapeLayer layer];
        moreBorder.path = [UIBezierPath bezierPathWithRoundedRect:am_moreBtn.bounds cornerRadius:am_moreBtn.layer.cornerRadius].CGPath;
        moreBorder.fillColor = [UIColor colorWithWhite:1 alpha:0].CGColor;
        moreBorder.strokeColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.7 alpha:0.75].CGColor;
        moreBorder.lineWidth = 2.4;
        moreBorder.shadowColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.6 alpha:1].CGColor;
        moreBorder.shadowOpacity = 1.0;
        moreBorder.shadowRadius = 14.0;
        moreBorder.shadowOffset = CGSizeZero;
        [am_moreBtn.layer addSublayer:moreBorder];
        CABasicAnimation *breath2 = [CABasicAnimation animationWithKeyPath:@"opacity"];
        breath2.fromValue = @0.3;
        breath2.toValue = @1.0;
        breath2.duration = 0.9;
        breath2.autoreverses = YES;
        breath2.repeatCount = HUGE_VALF;
        [moreBorder addAnimation:breath2 forKey:@"breath"];
        CAGradientLayer *pulse2 = [CAGradientLayer layer];
        pulse2.frame = moreHost.bounds;
        pulse2.colors = @[(__bridge id)[UIColor colorWithRed:0.2 green:0.95 blue:0.6 alpha:0.26].CGColor,
                          (__bridge id)[UIColor colorWithRed:0.7 green:1.0 blue:0.8 alpha:0.26].CGColor];
        pulse2.startPoint = CGPointMake(0, 0);
        pulse2.endPoint = CGPointMake(1, 1);
        pulse2.cornerRadius = am_moreBtn.layer.cornerRadius;
        [moreHost.layer insertSublayer:pulse2 atIndex:0];
        CABasicAnimation *morePulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
        morePulse.fromValue = @0.2;
        morePulse.toValue = @0.7;
        morePulse.duration = 0.9;
        morePulse.autoreverses = YES;
        morePulse.repeatCount = HUGE_VALF;
        [pulse2 addAnimation:morePulse forKey:@"btnPulse"];
        CABasicAnimation *shadowPulse = [CABasicAnimation animationWithKeyPath:@"shadowRadius"];
        shadowPulse.fromValue = @12.0;
        shadowPulse.toValue = @24.0;
        shadowPulse.duration = 0.9;
        shadowPulse.autoreverses = YES;
        shadowPulse.repeatCount = HUGE_VALF;
        [am_btn.layer addAnimation:shadowPulse forKey:@"shadowPulse"];
        CABasicAnimation *shadowPulse2 = [CABasicAnimation animationWithKeyPath:@"shadowRadius"];
        shadowPulse2.fromValue = @12.0;
        shadowPulse2.toValue = @24.0;
        shadowPulse2.duration = 0.9;
        shadowPulse2.autoreverses = YES;
        shadowPulse2.repeatCount = HUGE_VALF;
        [am_moreBtn.layer addAnimation:shadowPulse2 forKey:@"shadowPulse"];
        [am_btn addTarget:[AnnouncementManager class] action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
        [am_moreBtn addTarget:[AnnouncementManager class] action:@selector(openMore) forControlEvents:UIControlEventTouchUpInside];
        [am_container bringSubviewToFront:am_btn];
        [am_container bringSubviewToFront:am_moreBtn];
        [am_w makeKeyAndVisible];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            am_titleDots = am_animate_particles(titleHost, titlePts, 1.6, 1.5, [UIColor colorWithRed:1 green:0.9 blue:0.4 alpha:1]);
            am_contentDots = am_animate_particles(contentHost, contentPts, 2.0, 1.3, [UIColor colorWithRed:0.7 green:0.9 blue:1 alpha:1]);
        });
        NSArray *btnPts = am_points_for_text(@"确认", [UIFont boldSystemFontOfSize:20], btnHost.bounds.size, 1);
        NSArray *morePts = am_points_for_text(@"更多资源", [UIFont boldSystemFontOfSize:20], moreHost.bounds.size, 1);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            am_btnDots = am_animate_particles(btnHost, btnPts, 1.2, 1.2, [UIColor colorWithRed:0.7 green:0.9 blue:1 alpha:1]);
            am_moreDots = am_animate_particles(moreHost, morePts, 1.2, 1.2, [UIColor colorWithRed:0.5 green:1.0 blue:0.7 alpha:1]);
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            am_btn.transform = CGAffineTransformMakeScale(0.92, 0.92);
            am_moreBtn.transform = CGAffineTransformMakeScale(0.92, 0.92);
            [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                am_btn.alpha = 1.0;
                am_moreBtn.alpha = 1.0;
                am_btn.transform = CGAffineTransformIdentity;
                am_moreBtn.transform = CGAffineTransformIdentity;
            } completion:nil];
        });
    });
}

+ (void)dismiss {
    if (!am_w) return;
    am_btn.userInteractionEnabled = NO;
    CFTimeInterval now = CACurrentMediaTime();
    NSArray *groups = @[am_titleDots ?: @[], am_contentDots ?: @[], am_btnDots ?: @[], am_moreDots ?: @[]];
    for (NSArray *arr in groups) {
        for (CALayer *l in arr) {
            CGPoint p = l.position;
            CGFloat ang = (CGFloat)(arc4random_uniform(628)) / 100.0f;
            CGFloat d1 = 40.0f + (CGFloat)(arc4random_uniform(60));
            CGFloat d2 = d1 + 80.0f + (CGFloat)(arc4random_uniform(80));
            CGPoint t1 = CGPointMake(p.x + cosf(ang) * d1, p.y + sinf(ang) * d1);
            CGPoint t2 = CGPointMake(p.x + cosf(ang) * d2, p.y + sinf(ang) * d2);
            CAKeyframeAnimation *pos = [CAKeyframeAnimation animationWithKeyPath:@"position"];
            pos.values = @[[NSValue valueWithCGPoint:p], [NSValue valueWithCGPoint:t1], [NSValue valueWithCGPoint:t2]];
            pos.keyTimes = @[@0.0, @0.6, @1.0];
            pos.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut], [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
            pos.duration = 1.6;
            CABasicAnimation *op = [CABasicAnimation animationWithKeyPath:@"opacity"];
            op.fromValue = @(l.opacity);
            op.toValue = @0.0;
            op.duration = 1.6;
            op.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            CAAnimationGroup *g = [CAAnimationGroup animation];
            g.animations = @[pos, op];
            g.duration = 1.6;
            g.fillMode = kCAFillModeForwards;
            g.removedOnCompletion = NO;
            CFTimeInterval delay = ((arc4random()%200)/1000.0);
            g.beginTime = now + delay;
            [l addAnimation:g forKey:nil];
            l.position = t2;
            l.opacity = 0.0;
        }
    }
    [UIView animateWithDuration:1.2 delay:0.15 options:UIViewAnimationOptionCurveEaseOut animations:^{
        am_overlay.alpha = 0.0;
        am_container.alpha = 0.0;
    } completion:^(BOOL f){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1900 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            am_w.hidden = YES;
            am_w = nil; am_overlay = nil; am_container = nil; am_btn = nil; am_titleHost = nil; am_contentHost = nil; am_btnHost = nil; am_titleDots = nil; am_contentDots = nil; am_btnDots = nil;
        });
    }];
}

+ (void)openMore {
    NSURL *u = [NSURL URLWithString:@"https://tltds.cn"];
    if (!u) return;
    UIApplication *app = [UIApplication sharedApplication];
    if ([app respondsToSelector:@selector(openURL:options:completionHandler:)]) {
        [app openURL:u options:@{} completionHandler:nil];
    } else {
        [app openURL:u];
    }
}

@end

__attribute__((constructor))
static void am_ctor(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ [AnnouncementManager start]; });
}
