#import "PanelController.h"
#import "BackgroundView.h"
#import "StatusItemView.h"
#import "MenubarController.h"

//ウィンドウ表示の速度:0.15
#define OPEN_DURATION .15
//ウィンドウ表示閉じるときの速度:0.1
#define CLOSE_DURATION .1

//ウィンドウ高さ
#define POPUP_HEIGHT 130
//ウィンドウ幅
#define PANEL_WIDTH 280

#pragma mark -
@implementation PanelController

@synthesize backgroundView = _backgroundView;
@synthesize delegate = _delegate;

#pragma mark -
- (id)initWithDelegate:(id<PanelControllerDelegate>)delegate
{
    self = [super initWithWindowNibName:@"Panel"];
    if (self != nil)
    {
        _delegate = delegate;
    }
    return self;
}
- (void)dealloc
{
    NSLog(@"dealloc");
}

#pragma mark -

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    // Make a fully skinned panel
    NSPanel *panel = (id)[self window];
    [panel setAcceptsMouseMovedEvents:YES];
    [panel setLevel:NSPopUpMenuWindowLevel];
    [panel setOpaque:NO];
    [panel setBackgroundColor:[NSColor clearColor]];
}

#pragma mark - Public accessors

- (BOOL)hasActivePanel
{
    return _hasActivePanel;
}

- (void)setHasActivePanel:(BOOL)flag
{
    if (_hasActivePanel != flag)
    {
        _hasActivePanel = flag;
        
        if (_hasActivePanel)
        {
            [self openPanel];
        }
        else
        {
            [self closePanel];
        }
    }
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification
{
    self.hasActivePanel = NO;
}

- (void)windowDidResignKey:(NSNotification *)notification;
{
    if ([[self window] isVisible])
    {
        self.hasActivePanel = NO;
    }
}

- (void)windowDidResize:(NSNotification *)notification
{
    NSLog(@"windowDidResize");
    NSWindow *panel = [self window];
    NSRect statusRect = [self statusRectForWindow:panel];
    NSRect panelRect = [panel frame];
    
    CGFloat statusX = roundf(NSMidX(statusRect));
    CGFloat panelX = statusX - NSMinX(panelRect);
    
    self.backgroundView.arrowX = panelX;
}

#pragma mark - Public methods

- (NSRect)statusRectForWindow:(NSWindow *)window
{
    NSLog(@"statusRectForWindow");
    NSRect screenRect = [[[NSScreen screens] objectAtIndex:0] frame];
    NSRect statusRect = NSZeroRect;
    
    StatusItemView *statusItemView = nil;
    if ([self.delegate respondsToSelector:@selector(statusItemViewForPanelController:)])
    {
        statusItemView = [self.delegate statusItemViewForPanelController:self];
    }
    
    if (statusItemView)
    {
        statusRect = statusItemView.globalRect;
        statusRect.origin.y = NSMinY(statusRect) - NSHeight(statusRect);
    }
    else
    {
        statusRect.size = NSMakeSize(STATUS_ITEM_VIEW_WIDTH, [[NSStatusBar systemStatusBar] thickness]);
        statusRect.origin.x = roundf((NSWidth(screenRect) - NSWidth(statusRect)) / 2);
        statusRect.origin.y = NSHeight(screenRect) - NSHeight(statusRect) * 2;
    }
    return statusRect;
}

- (void)openPanel
{
    [self updateData];
    
    NSWindow *panel = [self window];
    panel.backgroundColor = [NSColor whiteColor];
    
    NSRect screenRect = [[[NSScreen screens] objectAtIndex:0] frame];
    NSRect statusRect = [self statusRectForWindow:panel];

    NSRect panelRect = [panel frame];
    panelRect.size.width = PANEL_WIDTH;
    panelRect.size.height = POPUP_HEIGHT;
    panelRect.origin.x = roundf(NSMidX(statusRect) - NSWidth(panelRect) / 2);
    panelRect.origin.y = NSMaxY(statusRect) - NSHeight(panelRect);
    
    if (NSMaxX(panelRect) > (NSMaxX(screenRect) - ARROW_HEIGHT))
        panelRect.origin.x -= NSMaxX(panelRect) - (NSMaxX(screenRect) - ARROW_HEIGHT);
    
    [NSApp activateIgnoringOtherApps:NO];
    [panel setAlphaValue:0];
    [panel setFrame:statusRect display:YES];
    [panel makeKeyAndOrderFront:nil];
    
    NSTimeInterval openDuration = OPEN_DURATION;
    
    NSEvent *currentEvent = [NSApp currentEvent];
    if ([currentEvent type] == NSLeftMouseDown)
    {
        NSUInteger clearFlags = ([currentEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask);
        BOOL shiftPressed = (clearFlags == NSShiftKeyMask);
        BOOL shiftOptionPressed = (clearFlags == (NSShiftKeyMask | NSAlternateKeyMask));
        if (shiftPressed || shiftOptionPressed)
        {
            openDuration *= 10;
            
            if (shiftOptionPressed)
                NSLog(@"Icon is at %@\n\tMenu is on screen %@\n\tWill be animated to %@",
                      NSStringFromRect(statusRect), NSStringFromRect(screenRect), NSStringFromRect(panelRect));
        }
    }
    
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:openDuration];
    [[panel animator] setFrame:panelRect display:YES];
    [[panel animator] setAlphaValue:1];
    [NSAnimationContext endGrouping];
    
    timer = [NSTimer scheduledTimerWithTimeInterval:60.0 target:self selector:@selector(updateData) userInfo:nil repeats:true];
    [timer fire];
}
-(void)menuTapped{
    NSLog(@"welcome");
    //アプリの終了
     [NSApp terminate:self];
}
#pragma mark オプションアイコンクリック時
- (IBAction)buttonClicked:(NSButton *)sender {
    NSRect frame = [(NSButton *)sender frame];
    NSPoint menuOrigin = [[(NSButton *)sender superview] convertPoint:NSMakePoint(frame.origin.x, frame.origin.y)
                                                               toView:nil];
    
    NSEvent *event =  [NSEvent mouseEventWithType:NSLeftMouseDown
                                         location:menuOrigin
                                    modifierFlags:NSEventTypeGesture
                                        timestamp:NSTimeIntervalSince1970
                                     windowNumber:[[(NSButton *)sender window] windowNumber]
                                          context:[[(NSButton *)sender window] graphicsContext]
                                      eventNumber:0
                                       clickCount:1
                                         pressure:1];
    
    NSMenu *menu = [[NSMenu alloc] init];
    [menu insertItemWithTitle:@"exit"
                       action:@selector(menuTapped)
                keyEquivalent:@""
                      atIndex:0];
    
    [NSMenu popUpContextMenu:menu withEvent:event forView:(NSButton *)sender];
}

#pragma mark 60秒ごとにデータを更新
-(void)updateData{
#pragma mark 曜日取得
    NSCalendar* calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents* comps = [calendar components:NSWeekdayCalendarUnit fromDate:[NSDate date]];
    
    NSDateFormatter* df = [[NSDateFormatter alloc] init];
    df.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"ja"];
    
    //comps.weekdayは 1-7の値が取得できるので-1する
    NSString* weekDayStr = df.shortWeekdaySymbols[comps.weekday-1];
    NSLog(@"%@",weekDayStr);
    if([weekDayStr isEqualToString:@"土"] || [weekDayStr isEqualToString:@"日"]){
        self.timeLabel.font = [NSFont systemFontOfSize:15];
        self.timeLabel.stringValue = @"土日は使用できません。(開発中)";
        self.destinationLabel.stringValue = @"";
        return;
    }
    
    // 現在日付を取得
    NSDate *now = [NSDate date];
    
    NSCalendar *calendar2 = [NSCalendar currentCalendar];
    NSUInteger flags;
    NSDateComponents *comps2;
    
    // 時・分・秒を取得
    flags = NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
    comps2 = [calendar2 components:flags fromDate:now];
    
    NSInteger hour = comps2.hour;
    NSInteger minute = comps2.minute;
    NSInteger second = comps2.second;
    
    NSLog(@"%ld時 %ld分 %ld秒", hour, minute, second);
    NSBundle* bundle = [NSBundle mainBundle];
    //読み込むファイルパスを指定
    NSString* path = [bundle pathForResource:@"bus_data" ofType:@"plist"];
    NSDictionary* dic = [NSDictionary dictionaryWithContentsOfFile:path];
    NSDictionary* weekdayData = [dic objectForKey:@"weekday"];
    NSArray *items =[NSArray arrayWithArray:[weekdayData objectForKey:@"dataset"]];
    
    bool flg = false;
    
    for(NSDictionary* str in items){
        if(flg == false){
            NSLog(@"%@",[str objectForKey:@"departure"]);
            NSLog(@"%@",[str objectForKey:@"destination"]);
            
            NSString *bus_hour = [[str objectForKey:@"departure"] substringToIndex:2];
            
            // ３文字目から後ろを取得
            NSString *bus_minute = [[str objectForKey:@"departure"] substringFromIndex:3];
            if((int)hour * 60 + (int)minute <= [bus_hour integerValue] * 60 + [bus_minute integerValue]){
                
                NSLog(@"hello");
                flg = true;
                self.timeLabel.font = [NSFont systemFontOfSize:35];
                self.timeLabel.stringValue = [str objectForKey:@"departure"];
                self.destinationLabel.stringValue = [NSString stringWithFormat:@"%@ 行",[str objectForKey:@"destination"]];
            }
        }
    }
    if(flg == false){
        self.timeLabel.font = [NSFont systemFontOfSize:15];
        self.timeLabel.stringValue = @"本日の営業は終了しました。";
        self.destinationLabel.stringValue = @"";
        return;
    }
}
- (void)closePanel
{
    //タイマーを止める
    [timer invalidate];
    timer = nil;
    
    NSLog(@"closePanel");
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:CLOSE_DURATION];
    [[[self window] animator] setAlphaValue:0];
    [NSAnimationContext endGrouping];
    
    dispatch_after(dispatch_walltime(NULL, NSEC_PER_SEC * CLOSE_DURATION * 2), dispatch_get_main_queue(), ^{
        
        [self.window orderOut:nil];
    });
}

@end
