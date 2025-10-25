#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>


static char kCSIndicatorKey;
static char kCSIndicatorLabelKey;
static char kCSSavedTextKey;
static UIViewController *getCurrentTopViewController() {
    UIWindow *keyWindow = nil;
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    
    UIViewController *topController = keyWindow.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    if ([topController isKindOfClass:[UINavigationController class]]) {
        topController = [(UINavigationController *)topController topViewController];
    }
    
    return topController;
}

static UIImage *captureScreenshot() {
    UIWindow *keyWindow = nil;
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    
    if (!keyWindow) return nil;
    
    UIGraphicsBeginImageContextWithOptions(keyWindow.bounds.size, NO, [UIScreen mainScreen].scale);
    [keyWindow.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return screenshot;
}

@interface UIViewController (ChatScreenshotHook)
- (void)addTripleTapScreenshotGesture;
- (void)handleTripleTapScreenshot:(UITapGestureRecognizer *)gesture;
- (void)addSwipeTextSaveGesture;
- (void)handleSwipeTextSave:(UISwipeGestureRecognizer *)gesture;
- (BOOL)isInputRelatedView:(UIView *)view;
- (void)saveTextBySelectAllAndCut;
- (void)restoreSavedInputText;
- (NSString *)getTextFromInputView:(UIView *)inputView;
- (void)clearTextInView:(UIView *)inputView;
- (void)addSwipeTextRestoreGesture;
- (void)handleSwipeTextRestore:(UISwipeGestureRecognizer *)gesture;
- (void)showScreenshotIndicatorWithMessage:(NSString *)message;
- (void)showScreenshotIndicator;
- (void)performScreenshotAndSend;
- (void)sendImageToChat:(UIImage *)image;
- (void)autoTriggerPaste;
- (void)triggerPasteMenu:(UIView *)textInput;
- (UIView *)findTextInputView;
- (UIView *)findTextInputViewInView:(UIView *)view;
- (UIView *)findFirstResponderInView:(UIView *)view;
- (UIView *)findEditableTextInputInView:(UIView *)view;
- (BOOL)isValidTextInputView:(UIView *)view;
- (void)updateScreenshotIndicator:(NSString *)message hideAfter:(NSTimeInterval)delay;
- (void)hideScreenshotIndicator;
- (void)showToast:(NSString *)message;
- (BOOL)shouldBlockScreenshotGesture:(UITapGestureRecognizer *)gesture;
- (BOOL)isValidScreenshotTriggerLocation:(CGPoint)location;
@end

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    NSString *className = NSStringFromClass([self class]);
    NSArray *chatVCPatterns = @[@"Chat", @"Message", @"BaseMsgContent", @"MMUIViewController"];
    
    BOOL isChatVC = NO;
    for (NSString *pattern in chatVCPatterns) {
        if ([className containsString:pattern]) {
            isChatVC = YES;
            break;
        }
    }
    
    if (isChatVC) {
        [self addTripleTapScreenshotGesture];
        [self addSwipeTextSaveGesture];
        [self addSwipeTextRestoreGesture];
    }
}

%new
- (void)addSwipeTextRestoreGesture {
    for (UIGestureRecognizer *gesture in self.view.gestureRecognizers) {
        if ([gesture isKindOfClass:[UISwipeGestureRecognizer class]]) {
            UISwipeGestureRecognizer *swipe = (UISwipeGestureRecognizer *)gesture;
            if (swipe.direction == UISwipeGestureRecognizerDirectionLeft) {
                if ([objc_getAssociatedObject(gesture, "isTextRestoreGesture") boolValue]) {
                    return;
                }
            }
        }
    }
    
    UISwipeGestureRecognizer *swipeGesture = [[UISwipeGestureRecognizer alloc]
                                             initWithTarget:self
                                             action:@selector(handleSwipeTextRestore:)];
    swipeGesture.direction = UISwipeGestureRecognizerDirectionLeft;
    swipeGesture.numberOfTouchesRequired = 1;
    objc_setAssociatedObject(swipeGesture, "isTextRestoreGesture", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self.view addGestureRecognizer:swipeGesture];
}

%new
- (void)handleSwipeTextRestore:(UISwipeGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        // 检查滑动位置是否在输入框区域
        CGPoint location = [gesture locationInView:self.view];
        UIView *hitView = [self.view hitTest:location withEvent:nil];
        UIView *inputView = nil;
        UIView *currentView = hitView;
        while (currentView && !inputView) {
            if ([self isInputRelatedView:currentView]) {
                inputView = currentView;
                break;
            }
            currentView = currentView.superview;
        }
        
        if (!inputView) {
            return;
        }
        
        [self restoreSavedInputText];
    }
}

%new
- (void)addTripleTapScreenshotGesture {
    for (UIGestureRecognizer *gesture in self.view.gestureRecognizers) {
        if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
            UITapGestureRecognizer *tap = (UITapGestureRecognizer *)gesture;
            if (tap.numberOfTapsRequired == 3 && tap.numberOfTouchesRequired == 1) {
                if ([objc_getAssociatedObject(gesture, "isScreenshotGesture") boolValue]) {
                    return;
                }
            }
        }
    }
    
    UITapGestureRecognizer *tripleTapGesture = [[UITapGestureRecognizer alloc]
                                               initWithTarget:self
                                               action:@selector(handleTripleTapScreenshot:)];
    tripleTapGesture.numberOfTapsRequired = 3;
    tripleTapGesture.numberOfTouchesRequired = 1;
    tripleTapGesture.delaysTouchesBegan = NO;
    tripleTapGesture.delaysTouchesEnded = NO;
    tripleTapGesture.cancelsTouchesInView = NO;
    
    objc_setAssociatedObject(tripleTapGesture, "isScreenshotGesture", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self.view addGestureRecognizer:tripleTapGesture];
}

%new
- (void)handleTripleTapScreenshot:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        if ([self shouldBlockScreenshotGesture:gesture]) {
            return;
        }
        
        CGPoint location = [gesture locationInView:self.view];
        if (![self isValidScreenshotTriggerLocation:location]) {
            return;
        }
        
        [self showScreenshotIndicator];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self performScreenshotAndSend];
        });
    }
}

%new
- (void)addSwipeTextSaveGesture {
    for (UIGestureRecognizer *gesture in self.view.gestureRecognizers) {
        if ([gesture isKindOfClass:[UISwipeGestureRecognizer class]]) {
            UISwipeGestureRecognizer *swipe = (UISwipeGestureRecognizer *)gesture;
            if (swipe.direction == UISwipeGestureRecognizerDirectionRight) {
                if ([objc_getAssociatedObject(gesture, "isTextSaveGesture") boolValue]) {
                    return;
                }
            }
        }
    }
    
    UISwipeGestureRecognizer *swipeGesture = [[UISwipeGestureRecognizer alloc]
                                             initWithTarget:self
                                             action:@selector(handleSwipeTextSave:)];
    swipeGesture.direction = UISwipeGestureRecognizerDirectionRight;
    swipeGesture.numberOfTouchesRequired = 1;
    objc_setAssociatedObject(swipeGesture, "isTextSaveGesture", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self.view addGestureRecognizer:swipeGesture];
}

%new
- (void)handleSwipeTextSave:(UISwipeGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        CGPoint location = [gesture locationInView:self.view];
        UIView *hitView = [self.view hitTest:location withEvent:nil];
        UIView *inputView = nil;
        UIView *currentView = hitView;
        while (currentView && !inputView) {
            if ([self isInputRelatedView:currentView]) {
                inputView = currentView;
                break;
            }
            currentView = currentView.superview;
        }
        
        if (!inputView) {
            return;
        }
        
        [self saveTextBySelectAllAndCut];
    }
}

%new
- (BOOL)isInputRelatedView:(UIView *)view {
    if ([view isKindOfClass:[UITextView class]] || [view isKindOfClass:[UITextField class]]) {
        return YES;
    }
    
    NSString *className = NSStringFromClass([view class]);
    NSArray *inputViewPatterns = @[
        @"TextView", @"TextField", @"MMText", @"MMInput",
        @"ChatInput", @"MessageInput", @"InputView", @"TextInput",
        @"MMGrowingTextView", @"MMChatInputView"
    ];
    
    for (NSString *pattern in inputViewPatterns) {
        if ([className containsString:pattern]) {
            return YES;
        }
    }
    
    return NO;
}

%new
- (void)saveTextBySelectAllAndCut {
    UIView *textInput = [self findTextInputView];
    if (!textInput) {
        [self updateScreenshotIndicator:@"天籁简提示：未找到输入框" hideAfter:1.0];
        return;
    }
    
    NSString *currentText = [self getTextFromInputView:textInput];

    if (!currentText || currentText.length == 0) {
        [self updateScreenshotIndicator:@"天籁简提示：输入框为空" hideAfter:1.0];
        return;
    }
    
    NSString *trimmedText = [currentText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedText.length == 0) {
        [self updateScreenshotIndicator:@"天籁简提示：输入框为空" hideAfter:1.0];
        return;
    }
    
    objc_setAssociatedObject(self, &kCSSavedTextKey, currentText, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self clearTextInView:textInput];
    
    [self updateScreenshotIndicator:@"天籁简提示：已保存内容" hideAfter:1.0];
}

%new
- (NSString *)getTextFromInputView:(UIView *)inputView {
    if (!inputView) return nil;
    
    NSString *text = nil;
    
    if ([inputView isKindOfClass:[UITextView class]]) {
        text = [(UITextView *)inputView text];
    } else if ([inputView isKindOfClass:[UITextField class]]) {
        text = [(UITextField *)inputView text];
    }
    
    if (!text && [inputView respondsToSelector:@selector(text)]) {
        @try {
            text = [inputView performSelector:@selector(text)];
        } @catch (NSException *exception) {
        }
    }
    
    if (!text) {
        @try {
            text = [inputView valueForKey:@"text"];
        } @catch (NSException *exception) {
        }
    }
    
    if (!text) {
        NSArray *textProperties = @[@"string", @"content", @"textContent", @"inputText"];
        for (NSString *property in textProperties) {
            @try {
                id value = [inputView valueForKey:property];
                if (value && [value isKindOfClass:[NSString class]]) {
                    text = (NSString *)value;
                    break;
                }
            } @catch (NSException *exception) {
            }
        }
    }
    
    return text;
}

%new
- (void)clearTextInView:(UIView *)inputView {
    if (!inputView) return;
    
    if ([inputView isKindOfClass:[UITextView class]]) {
        [(UITextView *)inputView setText:@""];
        return;
    } else if ([inputView isKindOfClass:[UITextField class]]) {
        [(UITextField *)inputView setText:@""];
        return;
    }
    
    if ([inputView respondsToSelector:@selector(setText:)]) {
        @try {
            [inputView performSelector:@selector(setText:) withObject:@""];
            return;
        } @catch (NSException *exception) {
        }
    }
    
    @try {
        [inputView setValue:@"" forKey:@"text"];
    } @catch (NSException *exception) {
    }
}

%new
- (void)restoreSavedInputText {
    NSString *savedText = objc_getAssociatedObject(self, &kCSSavedTextKey);
    if (!savedText || savedText.length == 0) {
        [self updateScreenshotIndicator:@"天籁简提示：无暂存内容" hideAfter:1.0];
        return;
    }
    
    UIView *textInput = [self findTextInputView];
    if (!textInput) {
        [self updateScreenshotIndicator:@"天籁简提示：未找到输入框" hideAfter:1.0];
        return;
    }
    
    if ([textInput respondsToSelector:@selector(becomeFirstResponder)]) {
        [textInput performSelector:@selector(becomeFirstResponder)];
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 直接设置文本内容（不使用剪贴板）
        BOOL restoreSuccess = NO;
        if ([textInput isKindOfClass:[UITextView class]]) {
            [(UITextView *)textInput setText:savedText];
            restoreSuccess = YES;
        } else if ([textInput isKindOfClass:[UITextField class]]) {
            [(UITextField *)textInput setText:savedText];
            restoreSuccess = YES;
        }
        
        if (!restoreSuccess && [textInput respondsToSelector:@selector(setText:)]) {
            @try {
                [textInput performSelector:@selector(setText:) withObject:savedText];
                restoreSuccess = YES;
            } @catch (NSException *exception) {
            }
        }
        
        if (!restoreSuccess) {
            @try {
                [textInput setValue:savedText forKey:@"text"];
                restoreSuccess = YES;
            } @catch (NSException *exception) {
            }
        }
        
        if (restoreSuccess) {
            objc_setAssociatedObject(self, &kCSSavedTextKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [self updateScreenshotIndicator:@"天籁简提示：已恢复内容" hideAfter:1.0];
        } else {
            [self updateScreenshotIndicator:@"天籁简提示：恢复失败" hideAfter:1.0];
        }
    });
}

%new
- (void)showScreenshotIndicator {
    [self showScreenshotIndicatorWithMessage:@"天籁简提示：📸 正在截图"];
}

%new
- (void)showScreenshotIndicatorWithMessage:(NSString *)message {
    CGFloat height = 32.0;
    CGFloat topInset = 64.0;
    if (@available(iOS 11.0, *)) {
        topInset = self.view.safeAreaInsets.top ?: 44.0;
    }
    
    UIFont *font = [UIFont systemFontOfSize:13];
    CGSize textSize = [message sizeWithAttributes:@{NSFontAttributeName: font}];
    CGFloat minWidth = 80.0;  // 最小宽度
    CGFloat maxWidth = self.view.bounds.size.width - 40.0;  // 最大宽度（留边距）
    CGFloat padding = 16.0;  // 左右内边距
    CGFloat width = MAX(minWidth, MIN(maxWidth, textSize.width + padding));
    
    UIView *indicator = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - width - 12.0,
                                                                 topInset + 12.0,
                                                                 width, height)];
    indicator.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
    indicator.layer.cornerRadius = 16;
    indicator.userInteractionEnabled = NO;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(padding/2, 0, width - padding, height)];
    label.text = message;
    label.textColor = [UIColor whiteColor];
    label.font = font;
    label.textAlignment = NSTextAlignmentCenter;
    label.userInteractionEnabled = NO;
    label.numberOfLines = 1;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    [indicator addSubview:label];
    objc_setAssociatedObject(self, &kCSIndicatorKey, indicator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kCSIndicatorLabelKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    indicator.alpha = 0;
    [self.view addSubview:indicator];
    [UIView animateWithDuration:0.18 animations:^{ indicator.alpha = 1; }];
}

%new
- (void)performScreenshotAndSend {
    UIImage *screenshot = captureScreenshot();
    
    if (!screenshot) {
        [self updateScreenshotIndicator:@"天籁简提示：截图失败" hideAfter:1.6];
        return;
    }
    
    [self sendImageToChat:screenshot];
}

%new
- (void)sendImageToChat:(UIImage *)image {
    @try {
        UIPasteboard.generalPasteboard.image = image;
        [self updateScreenshotIndicator:@"天籁简提示：截图已复制，正在启动粘贴" hideAfter:2.0];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self autoTriggerPaste];
        });
        
    } @catch (NSException *exception) {
        UIPasteboard.generalPasteboard.image = image;
        [self updateScreenshotIndicator:@"天籁简提示：截图已复制到剪贴板" hideAfter:1.6];
    }
}

%new
- (void)autoTriggerPaste {
    UIView *textInput = [self findTextInputView];
    if (!textInput) {
        [self updateScreenshotIndicator:@"天籁简提示：未找到输入框，已复制到剪贴板" hideAfter:1.6];
        return;
    }
    
    if ([textInput respondsToSelector:@selector(becomeFirstResponder)]) {
        [textInput performSelector:@selector(becomeFirstResponder)];
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([textInput respondsToSelector:@selector(paste:)]) {
            [textInput performSelector:@selector(paste:) withObject:nil];
            [self updateScreenshotIndicator:@"天籁简提示：截图已粘贴" hideAfter:1.6];
        } else {
            [self triggerPasteMenu:textInput];
        }
    });
}

%new
- (void)triggerPasteMenu:(UIView *)textInput {
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    if ([menuController isMenuVisible]) {
        [menuController setMenuVisible:NO animated:NO];
    }
    
    CGPoint center = CGPointMake(textInput.bounds.size.width / 2, textInput.bounds.size.height / 2);
    [menuController setTargetRect:CGRectMake(center.x, center.y, 1, 1) inView:textInput];
    [menuController setMenuVisible:YES animated:YES];
    
    [self updateScreenshotIndicator:@"天籁简提示：请手动点击粘贴" hideAfter:2.5];
}

%new
- (UIView *)findTextInputView {
    UIView *firstResponder = [self findFirstResponderInView:self.view];
    if (firstResponder && [self isValidTextInputView:firstResponder]) {
        return firstResponder;
    }
    
    UIView *editableInput = [self findEditableTextInputInView:self.view];
    if (editableInput) {
        return editableInput;
    }
    
    return [self findTextInputViewInView:self.view];
}

%new
- (UIView *)findFirstResponderInView:(UIView *)view {
    if ([view isFirstResponder]) {
        return view;
    }
    
    for (UIView *subview in view.subviews) {
        UIView *firstResponder = [self findFirstResponderInView:subview];
        if (firstResponder) {
            return firstResponder;
        }
    }
    
    return nil;
}

%new
- (UIView *)findEditableTextInputInView:(UIView *)view {
    if ([self isValidTextInputView:view]) {
        BOOL isEditable = YES;
        if ([view isKindOfClass:[UITextView class]]) {
            isEditable = [(UITextView *)view isEditable];
        } else if ([view isKindOfClass:[UITextField class]]) {
            isEditable = [(UITextField *)view isEnabled];
        } else {
            @try {
                NSNumber *editableValue = [view valueForKey:@"editable"];
                if (editableValue) {
                    isEditable = [editableValue boolValue];
                }
            } @catch (NSException *exception) {
                isEditable = YES;
            }
        }
        
        if (isEditable) {
            return view;
        }
    }
    
    for (UIView *subview in view.subviews) {
        UIView *found = [self findEditableTextInputInView:subview];
        if (found) {
            return found;
        }
    }
    
    return nil;
}

%new
- (BOOL)isValidTextInputView:(UIView *)view {
    if (!view) return NO;
    if ([view isKindOfClass:[UITextView class]] || [view isKindOfClass:[UITextField class]]) {
        return YES;
    }
    
    if ([view respondsToSelector:@selector(text)] &&
        ([view respondsToSelector:@selector(setText:)] || [view respondsToSelector:@selector(insertText:)])) {
        return YES;
    }
    
    NSString *className = NSStringFromClass([view class]);
    NSArray *inputViewPatterns = @[
        @"TextView", @"TextField", @"MMText", @"MMInput",
        @"ChatInput", @"MessageInput", @"InputView", @"TextInput",
        @"MMGrowingTextView", @"MMChatInputView", @"MMUITextView"
    ];
    
    for (NSString *pattern in inputViewPatterns) {
        if ([className containsString:pattern]) {
            return YES;
        }
    }
    
    return NO;
}

%new
- (UIView *)findTextInputViewInView:(UIView *)view {
    if ([self isValidTextInputView:view]) {
        return view;
    }
    
    for (UIView *sub in view.subviews) {
        UIView *found = [self findTextInputViewInView:sub];
        if (found) return found;
    }
    return nil;
}

%new
- (void)updateScreenshotIndicator:(NSString *)message hideAfter:(NSTimeInterval)delay {
    UIView *indicator = objc_getAssociatedObject(self, &kCSIndicatorKey);
    UILabel *label = objc_getAssociatedObject(self, &kCSIndicatorLabelKey);

    if (!indicator || !label) {
        [self showScreenshotIndicatorWithMessage:message ?: @""];
        indicator = objc_getAssociatedObject(self, &kCSIndicatorKey);
        label = objc_getAssociatedObject(self, &kCSIndicatorLabelKey);
    } else {
        NSString *newMessage = message ?: @"";
        label.text = newMessage;
        UIFont *font = [UIFont systemFontOfSize:13];
        CGSize textSize = [newMessage sizeWithAttributes:@{NSFontAttributeName: font}];
        CGFloat minWidth = 80.0;
        CGFloat maxWidth = self.view.bounds.size.width - 40.0;
        CGFloat padding = 16.0;
        CGFloat newWidth = MAX(minWidth, MIN(maxWidth, textSize.width + padding));
        CGRect frame = indicator.frame;
        frame.origin.x = self.view.bounds.size.width - newWidth - 12.0;
        frame.size.width = newWidth;
        indicator.frame = frame;
        label.frame = CGRectMake(padding/2, 0, newWidth - padding, frame.size.height);
    }

    if (delay > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self hideScreenshotIndicator];
        });
    }
}

%new
- (void)hideScreenshotIndicator {
    UIView *indicator = objc_getAssociatedObject(self, &kCSIndicatorKey);
    if (!indicator) return;
    
    [UIView animateWithDuration:0.25 animations:^{
        indicator.alpha = 0;
    } completion:^(BOOL finished) {
        [indicator removeFromSuperview];
        objc_setAssociatedObject(self, &kCSIndicatorKey, nil, OBJC_ASSOCIATION_ASSIGN);
        objc_setAssociatedObject(self, &kCSIndicatorLabelKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }];
}

%new
- (void)showToast:(NSString *)message {
    [self updateScreenshotIndicator:message hideAfter:1.6];
}

%new
- (BOOL)shouldBlockScreenshotGesture:(UITapGestureRecognizer *)gesture {
    NSString *className = NSStringFromClass([self class]);
    NSArray *blockPatterns = @[
        @"Emoji", @"Sticker", @"Expression", @"Emoticon",
        @"MMEmoticonView", @"MMStickerView", @"MMExpressionView",
        @"EmojiPicker", @"StickerPicker", @"ExpressionPicker"
    ];
    
    for (NSString *pattern in blockPatterns) {
        if ([className containsString:pattern]) {
            return YES;
        }
    }
    
    CGPoint location = [gesture locationInView:self.view];
    UIView *hitView = [self.view hitTest:location withEvent:nil];
    
    UIView *currentView = hitView;
    while (currentView) {
        NSString *viewClassName = NSStringFromClass([currentView class]);
        for (NSString *pattern in blockPatterns) {
            if ([viewClassName containsString:pattern]) {
                return YES;
            }
        }
        currentView = currentView.superview;
    }
    
    return NO;
}

%new
- (BOOL)isValidScreenshotTriggerLocation:(CGPoint)location {
    UIView *hitView = [self.view hitTest:location withEvent:nil];
    if (!hitView) return NO;
    NSString *className = NSStringFromClass([hitView class]);
    NSArray *invalidPatterns = @[
        @"Button", @"UIButton", @"MMUIButton",
        @"Emoji", @"Sticker", @"Expression", @"Emoticon",
        @"Keyboard", @"InputAccessory", @"Toolbar",
        @"NavigationBar", @"TabBar", @"SegmentedControl"
    ];
    
    UIView *currentView = hitView;
    while (currentView) {
        NSString *viewClassName = NSStringFromClass([currentView class]);
        for (NSString *pattern in invalidPatterns) {
            if ([viewClassName containsString:pattern]) {
                return NO;
            }
        }
        if (currentView.userInteractionEnabled &&
            ([currentView isKindOfClass:[UIControl class]] ||
             [currentView isKindOfClass:[UIButton class]])) {
            return NO;
        }
        
        currentView = currentView.superview;
    }
    CGRect validRect = CGRectInset(self.view.bounds, 50, 100);
    return CGRectContainsPoint(validRect, location);
}

%end
