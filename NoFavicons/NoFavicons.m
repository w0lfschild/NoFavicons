#import "BookmarkButtonCell.h"
#import "BookmarkButton.h"
#import "ZKSwizzle.h"
#import <CommonCrypto/CommonDigest.h>

@import AppKit;

/*------------------------------------*/

NSInteger otherBMX;
int appsWidth;
BOOL is109;
BOOL isAppsVis;

/*------------------------------------*/

@interface NoFavicons : NSObject
@end

@implementation NoFavicons

+ (void) load {
    NSLog(@"NoFavicons loading...");
    
    // Initialize a few things
    is109 = (NSProcessInfo.processInfo.operatingSystemVersion.minorVersion == 9);
    appsWidth = 0;
    otherBMX = 0;
    isAppsVis = false;
    
    // Swizzle
    ZKSwizzle(wb_BookmarkButtonCell, BookmarkButtonCell);
    ZKSwizzle(wb_BookmarkButton, BookmarkButton);
    
    NSLog(@"%@ loaded into %@ on macOS 10.%ld", [self class], [[NSBundle mainBundle] bundleIdentifier], [[NSProcessInfo processInfo] operatingSystemVersion].minorVersion);
}

@end

/*------------------------------------*/

@interface wb_BookmarkButton : NSButton
@end

@implementation wb_BookmarkButton

// Check if the "Apps" button is hidden or not
- (void)setHidden:(BOOL)hidden {
    if ([self.title isEqualToString:NSLocalizedString(@"Apps", nil)]) {
        appsWidth = self.frame.size.width;
        isAppsVis = !hidden;
    }
    
    // Fix for an issue where an empty bookmark that crashes the browser when clicked shows after removing a bookmark
    if ([self.title isEqualToString:NSLocalizedString(@"(empty)", nil)] || [self.title isEqualToString:NSLocalizedString(@"(empty) ▾", nil)])
        hidden = true;
    
    ZKOrig(void, hidden);
}

// Adjust the frame size to be the size the title plus padding to account for removal of image
- (void)setFrame:(NSRect)frame {
    CGRect newFrame = frame;
    
    if ([self isInBar]) {
        // Only resize if the button has a title to prevent resizing the overflow button
        if ([[(BookmarkButtonCell*)[self cell] visibleTitle] length]) {
            NSSize titleSize = [[self attributedTitle] size];
            newFrame.size.width = ceil(titleSize.width + 10);
        }
    }
    
    ZKOrig(void, newFrame);
}

// Manually work some magic to allign all the buttons ✨
- (void)setFrameOrigin:(NSPoint)newOrigin {
    CGPoint origin = newOrigin;
    
    if ([self isInBar]) {
        // Get an array of all the buttons in the Bookmark Bar
        SEL getController = NSSelectorFromString(@"controller");
        NSArray *someButtons = [[NSArray alloc] initWithArray:[[[self superview] performSelector:getController] buttons]];
        
        // The start position of the leftmost button
        int xPos = 5;
        if (isAppsVis)
            xPos = 7 + appsWidth;
        
        // Set the xPos of self to equal the xPos of the button one to the left plus our own width plus 2 for buffer
        // When the browser is first initializing the buttons we don't show up in the someButtons array
        // To work around this we just assume we are the next button after the last
        if (someButtons.count > 0) {
            if ([someButtons containsObject:self]) {
                NSUInteger myPos = [someButtons indexOfObject:self];
                if (myPos > 0) {
                    BookmarkButton *prev = (BookmarkButton*)[someButtons objectAtIndex:myPos - 1];
                    xPos = prev.frame.origin.x + prev.frame.size.width + 2;
                }
            } else {
                BookmarkButton *prev = (BookmarkButton*)[someButtons lastObject];
                xPos = prev.frame.origin.x + prev.frame.size.width + 2;
            }
        }
        origin.x = xPos;
    }
    
    // Always show "Apps" button at left side of window
    if ([self.title isEqualToString:NSLocalizedString(@"Apps", nil)])
        origin.x = 5;
    
    // Always show "Other Bookmarks" at right side of window
    if ([self.title isEqualToString:NSLocalizedString(@"Other Bookmarks ▾", nil)]) {
        origin.x = [self superview].frame.size.width - self.frame.size.width - 5;
        otherBMX = origin.x;
    }

    // Always show overflow bookmarks button directly left of "Other Bookmarks"
    if (![[(BookmarkButtonCell*)[self cell] visibleTitle] length])
        origin.x = otherBMX - self.frame.size.width - 2;
    
    // Apply new frame with custom X position
    ZKOrig(void, origin);
}

// Check if bookmark is in the bookmarks bar and not in a subfolder
- (BOOL)isInBar {
    BOOL result = false;
    if ([[self superview].className isEqualToString:@"BookmarkBarView"])
        result = true;
    return result;
}

@end

/*------------------------------------*/

@interface wb_BookmarkButtonCell : NSButtonCell
@end

@implementation wb_BookmarkButtonCell

static NSArray *Folderhashes = nil;

// Make the title start offset 5 and width to the frame size minus 10 for the padding
- (struct CGRect)titleRectForBounds:(struct CGRect)arg1 {
    CGRect result = ZKOrig(struct CGRect, arg1);
    result.origin.x = 5;
    result.size.width = arg1.size.width - 8;
    return result;
}

// Hide the button image
- (struct CGRect)imageRectForBounds:(struct CGRect)arg1 {
    if ([self.title length] && [[(BookmarkButtonCell*)self visibleTitle] length])
        return CGRectMake(4, -1, 0, 0);
    else
        return ZKOrig(struct CGRect, arg1);
}

// Add " ▾" to "Other Bookmarks"
- (void)setBookmarkCellText:(id)arg1 image:(id)arg2 {
    if (![(BookmarkButtonCell*)self isFolderButtonCell])
        if ([self imageIsFolder:arg2])
            arg1 = [self appendArrow:arg1];
    ZKOrig(void, arg1, arg2);
}

// 10.9 Fix
- (void)setImage:(NSImage *)image {
    ZKOrig(void, image);
    if (is109) {
        if (![(BookmarkButtonCell*)self isFolderButtonCell])
            if ([self imageIsFolder:[self image]])
                [self setTag:101];
        image = [NSImage alloc];
        if (![(BookmarkButtonCell*)self isFolderButtonCell])
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ ZKOrig(void, image); });
        else
            ZKOrig(void, image);
    }
}

// Add " ▾" to folders in the bookmar bar
- (void)setTitle:(NSString *)title {
    if (is109)
        if ([self tag] == 101)
            title = [self appendArrow:title];
    if (![(BookmarkButtonCell*)self isFolderButtonCell])
        if ([self imageIsFolder:[self image]])
            title = [self appendArrow:title];
    ZKOrig(void, title);
}

// Add " ▾" to end of input string if it's not already there
- (NSString *)appendArrow:(NSString*)original {
    if (![original hasSuffix:@" ▾"])
        original = [NSString stringWithFormat:@"%@ ▾", original];
    return original;
}

// Check if a button image is a folder image
- (BOOL)imageIsFolder:(NSImage*)image {
    if (Folderhashes == nil) {
        Folderhashes = [[NSArray alloc] initWithObjects:
                        @"4cc0afe6dc8a0cee961f15b087f6cc13784f6bad",
                        @"c3706d5b34a4b336f1a08b2819a01698c94c92ff",
                        @"e7bb69efe7575935236c0dacee014df026acbf8f",
                        @"fb95ab18021d0833b84ae893210edf05f85ba24d",
                        @"4fd0758c661623035ecf46b55ad13e6c5dec1fa4",
                        @"22cd19df85c313dcefe1342849ffdb1d7928388e",
                        nil];
    }
    NSData* data = [image TIFFRepresentation];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (uint)data.length, digest);
    NSMutableString* sha1 = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
        [sha1 appendFormat:@"%02x", digest[i]];
//    NSLog(@"wb_ %@ : %lu : %@", [self title], (unsigned long)self.hash, sha1);
    return ([Folderhashes indexOfObject:sha1] != NSNotFound);
}

@end
