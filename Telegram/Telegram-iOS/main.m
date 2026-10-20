#import <UIKit/UIKit.h>

// MindGram: with "Старый дизайн Telegram" on, ask UIKit for the pre-iOS 26 look of system controls
// (switches, alerts, menus, pickers) by adding UIDesignRequiresCompatibility to the in-memory
// Info.plist before UIKit reads it. The switch is MindGramDesign in MindGram/Core.
static void mindGramApplyClassicSystemDesign(void) {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"MindGram.classicDesign"]) {
        return;
    }
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    // Read by the «Отчёт» screen.
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"MindGram.classicDesignError"];
    @try {
        [(NSMutableDictionary *)info setObject:@YES forKey:@"UIDesignRequiresCompatibility"];
    } @catch (NSException *exception) {
        NSLog(@"MindGram: could not enable UIDesignRequiresCompatibility: %@", exception);
        [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"main.m mindGramApplyClassicSystemDesign(): %@: %@", exception.name, exception.reason] forKey:@"MindGram.classicDesignError"];
    }
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        mindGramApplyClassicSystemDesign();
        return UIApplicationMain(argc, argv, @"Application", @"AppDelegate");
    }
}
