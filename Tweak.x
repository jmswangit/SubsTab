#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

@interface NSObject (SubsTabPivot)
- (NSMutableArray *)itemsArray;
- (id)pivotBarItemRenderer;
- (NSString *)pivotIdentifier;
@end


static const NSInteger SubsSection = 'subs';
static const NSInteger SubsTweakGroup = 'psyt';
static NSString *const kEnabledKey = @"SubsTabEnabled";

static BOOL SubsEnabled(void) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:kEnabledKey];
    return value == nil ? YES : [[NSUserDefaults standardUserDefaults] boolForKey:kEnabledKey];
}

static NSString *SubsIdentifier(void) {
    Class cls = objc_getClass("YTIBrowseRequest");
    SEL sel = @selector(browseIDForSubscriptionsTab);
    if (cls && [cls respondsToSelector:sel]) {
        NSString *identifier = ((NSString *(*)(id, SEL))objc_msgSend)((id)cls, sel);
        if (identifier.length) return identifier;
    }
    return @"FEsubscriptions";
}

static void SubsRefreshPivotBar(void) {
    Class cls = objc_getClass("YTHeaderContentComboViewController");
    if (cls && [cls instancesRespondToSelector:@selector(refreshPivotBar)]) {
        id controller = [[cls alloc] init];
        ((void (*)(id, SEL))objc_msgSend)(controller, @selector(refreshPivotBar));
    }
}

static void SubsToast(NSString *message, id responder) {
    Class cls = objc_getClass("YTToastResponderEvent");
    if (cls && [cls respondsToSelector:@selector(eventWithMessage:firstResponder:)]) {
        id event = ((id (*)(id, SEL, id, id))objc_msgSend)((id)cls, @selector(eventWithMessage:firstResponder:), message, responder);
        if ([event respondsToSelector:@selector(send)])
            ((void (*)(id, SEL))objc_msgSend)(event, @selector(send));
    }
}

static void SubsApply(NSMutableArray *items) {
    if (!items) return;
    NSString *identifier = SubsIdentifier();
    NSUInteger existing = [items indexOfObjectPassingTest:^BOOL(id item, NSUInteger index, BOOL *stop) {
        if (![item respondsToSelector:@selector(pivotBarItemRenderer)]) return NO;
        id renderer = [item pivotBarItemRenderer];
        return [[renderer pivotIdentifier] isEqualToString:identifier];
    }];

    if (!SubsEnabled()) {
        if (existing != NSNotFound) [items removeObjectAtIndex:existing];
        return;
    }
    if (existing != NSNotFound) return;

    Class rendererClass = objc_getClass("YTIPivotBarRenderer");
    SEL factory = @selector(pivotSupportedRenderersWithBrowseId:title:iconType:);
    if (!rendererClass || ![rendererClass respondsToSelector:factory]) return;

    id tab = ((id (*)(id, SEL, id, id, int))objc_msgSend)((id)rendererClass, factory, identifier, @"Subs", 66);
    if (!tab) return;
    NSUInteger index = MIN((NSUInteger)3, items.count);
    [items insertObject:tab atIndex:index];
}

static BOOL gTweaksHooked = NO;
static BOOL gUseTweaksGroup = NO;
static id (*gOriginalTweaks)(id, SEL);

static id SubsTweaksHook(id self, SEL _cmd) {
    NSMutableArray *tweaks = gOriginalTweaks ? gOriginalTweaks(self, _cmd) : [NSMutableArray array];
    if (![tweaks containsObject:@(SubsSection)]) [tweaks addObject:@(SubsSection)];
    return tweaks;
}

static void SubsInstallTweaksHook(void) {
    if (gTweaksHooked) return;
    Class cls = objc_getClass("YTSettingsGroupData");
    Method method = class_getClassMethod(cls, @selector(tweaks));
    if (!method) return;
    MSHookMessageEx(object_getClass(cls), @selector(tweaks), (IMP)SubsTweaksHook, (IMP *)&gOriginalTweaks);
    gTweaksHooked = YES;
    gUseTweaksGroup = YES;
}

@interface YTAppSettingsPresentationData : NSObject
+ (NSArray *)settingsCategoryOrder;
@end
@interface YTSettingsGroupData : NSObject
@property (nonatomic, readonly, assign) NSUInteger type;
@property (nonatomic, readonly, strong) NSArray<NSNumber *> *orderedCategories;
- (NSArray<NSNumber *> *)orderedCategoriesForGroupType:(NSUInteger)type;
@end
@interface YTSettingsSectionItem : NSObject
+ (instancetype)switchItemWithTitle:(NSString *)title titleDescription:(NSString *)description accessibilityIdentifier:(NSString *)identifier switchOn:(BOOL)on switchBlock:(BOOL (^)(id, BOOL))block settingItemId:(int)itemId;
@end
@interface YTSettingsViewController : UIViewController
- (void)setSectionItems:(NSMutableArray *)items forCategory:(NSInteger)category title:(NSString *)title titleDescription:(NSString *)description headerHidden:(BOOL)hidden;
- (void)setSectionItems:(NSMutableArray *)items forCategory:(NSInteger)category title:(NSString *)title icon:(id)icon titleDescription:(NSString *)description headerHidden:(BOOL)hidden;
@end
@interface YTSettingsSectionItemManager : NSObject
- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry;
@end
@interface YTToastResponderEvent : NSObject
+ (instancetype)eventWithMessage:(NSString *)message firstResponder:(id)firstResponder;
- (void)send;
@end

%hook YTAppSettingsPresentationData
+ (NSArray *)settingsCategoryOrder {
    SubsInstallTweaksHook();
    NSArray *order = %orig;
    if (gUseTweaksGroup) return order;
    NSMutableArray *mutableOrder = [order mutableCopy];
    if (![mutableOrder containsObject:@(SubsSection)]) {
        NSUInteger index = [order indexOfObject:@(1)];
        if (index == NSNotFound) index = 0; else index += 1;
        [mutableOrder insertObject:@(SubsSection) atIndex:index];
    }
    return mutableOrder;
}
%end

%hook YTSettingsGroupData
- (NSArray<NSNumber *> *)orderedCategories {
    NSArray *categories = %orig;
    if (gUseTweaksGroup || self.type != 1) return categories;
    NSMutableArray *mutableCategories = [categories mutableCopy];
    if (![mutableCategories containsObject:@(SubsSection)])
        [mutableCategories insertObject:@(SubsSection) atIndex:0];
    return mutableCategories;
}
- (NSArray<NSNumber *> *)orderedCategoriesForGroupType:(NSUInteger)type {
    NSArray *categories = %orig;
    if (type != SubsTweakGroup) return categories;
    NSMutableArray *mutableCategories = [categories mutableCopy];
    if (![mutableCategories containsObject:@(SubsSection)])
        [mutableCategories insertObject:@(SubsSection) atIndex:0];
    return mutableCategories;
}
%end

%hook YTSettingsSectionItemManager
- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category != SubsSection) { %orig; return; }

    YTSettingsViewController *controller = [self valueForKey:@"_settingsViewControllerDelegate"];
    NSMutableArray *items = [NSMutableArray array];
    [items addObject:[%c(YTSettingsSectionItem) switchItemWithTitle:@"Subs Tab"
        titleDescription:@"Add a Subscriptions tab to the bottom bar"
        accessibilityIdentifier:nil
        switchOn:SubsEnabled()
        switchBlock:^BOOL(id cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kEnabledKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            SubsRefreshPivotBar();
            SubsToast(@"Restart YouTube if the tab doesn't update", controller);
            return YES;
        } settingItemId:0]];

    if ([controller respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)]) {
        [controller setSectionItems:items forCategory:SubsSection title:@"Subs Tab" icon:nil titleDescription:nil headerHidden:NO];
    } else {
        [controller setSectionItems:items forCategory:SubsSection title:@"Subs Tab" titleDescription:nil headerHidden:NO];
    }
}
%end

%hook YTPivotBarView
- (void)setRenderer:(id)renderer {
    if ([renderer respondsToSelector:@selector(itemsArray)]) SubsApply([renderer itemsArray]);
    %orig;
}
%end

%hook YTFloatingPivotBarView
- (void)setRenderer:(id)renderer {
    if ([renderer respondsToSelector:@selector(itemsArray)]) SubsApply([renderer itemsArray]);
    %orig;
}
%end

%ctor {
    %init;
    SubsInstallTweaksHook();
}
