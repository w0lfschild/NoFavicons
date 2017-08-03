#import "BookmarkButtonCell.h"
#import "BookmarkButton.h"
#import "ZKSwizzle.h"
#import <CommonCrypto/CommonDigest.h>

@import AppKit;

@interface NoFavicons : NSObject
@end

/*------------------------------------*/

NoFavicons *plugin;

@implementation NoFavicons 

+ (NoFavicons*) sharedInstance {
    static NoFavicons * plugin = nil;
    
    if (plugin == nil)
        plugin = [[NoFavicons alloc] init];
    
    return plugin;
}

+ (void) load {
    NSLog(@"NoFavicons loading...");
    plugin = [NoFavicons sharedInstance];
    ZKSwizzle(wb_BookmarkButtonCell, BookmarkButtonCell);
    ZKSwizzle(wb_BookmarkButton, BookmarkButton);
    NSLog(@"%@ loaded into %@ on macOS 10.%ld", [self class], [[NSBundle mainBundle] bundleIdentifier], [[NSProcessInfo processInfo] operatingSystemVersion].minorVersion);
}

@end

/*------------------------------------*/


@interface wb_BookmarkButton : NSButton
@end

@implementation wb_BookmarkButton

// Adjust the frame size to be the size the title plus padding to account for removal of image
- (void)setFrame:(NSRect)frame {
    CGRect newFrame = frame;
    
    if ([self isInBar]) {
//        if ([self.title length] && [[(BookmarkButtonCell*)[self cell] visibleTitle] length]) {
            NSSize titleSize = [[self attributedTitle] size];
            newFrame.size.width = ceil(titleSize.width + 10);
//        }
    }
    
    ZKOrig(void, newFrame);
}

//- (void)draggingSession:(id)arg1 endedAtPoint:(struct CGPoint)arg2 operation:(unsigned long long)arg3 {
//    ZKOrig(void, arg1, arg2, arg3);
//}

// Manually work some magic to allign all the buttons ✨
- (void)setFrameOrigin:(NSPoint)newOrigin {
//    NSLog(@"wb_ %hhd", ZKHookIvar(self, BOOL, "dragPending_"));
    CGPoint origin = newOrigin;
    if ([self isInBar]) {
        
        // Make an array of all buttons in bookmark bar
        NSMutableArray *buttons = [[NSMutableArray alloc] initWithArray:[[self superview] subviews]];
        NSMutableArray *sortButtons = [[NSMutableArray alloc] init];
        
        // Try to weed out any odd buttons that don't belong
        for (BookmarkButton *bm in buttons) {
            if ([bm respondsToSelector:@selector(title)]) {
//                if ([[bm title] length]) {
                    if (bm.frame.origin.x > 5 && bm.frame.origin.y == 4) {
                        [bm setTag:bm.frame.origin.x];
                        [sortButtons addObject:bm];
                    }
//                }
            }
        }
        
        // Sort the buttons by x position from smallest to largest
        NSSortDescriptor *sortDescriptor;
        sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"tag" ascending:YES];
        NSArray *final = [[NSArray alloc] initWithArray:sortButtons];
        final = [final sortedArrayUsingDescriptors:@[sortDescriptor]];
        
        // Loop through the button list until we match the current button
        if (final.count > 1) {
            for (int i = 1; i < (final.count - 1); i++) {
                if ([self isEqualTo:[final objectAtIndex:i]]) {
                    NSObject *prev = [final objectAtIndex:i-1];
                    BookmarkButton *test = (BookmarkButton*)prev;
                    int newX = test.frame.origin.x + test.frame.size.width + 2;
                    origin.x = newX;
//                    NSLog(@"wb_ %@ : %@ : %@ : %@", [self title], NSStringFromRect(self.frame), test.title, NSStringFromRect(test.frame));
                    break;
                }
            }
        }
    }
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
    result.size.width = arg1.size.width - 10;
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
            if (![arg1 hasSuffix:@" ▾"])
                arg1 = [NSString stringWithFormat:@"%@ ▾", arg1];
    ZKOrig(void, arg1, arg2);
}

// Add " ▾" to folders in the bookmar bar
- (void)setTitle:(NSString *)title {
    if (![(BookmarkButtonCell*)self isFolderButtonCell]) {
        if ([self imageIsFolder:[self image]])
            if (![title hasSuffix:@" ▾"])
                title = [NSString stringWithFormat:@"%@ ▾", title];
    }
    ZKOrig(void, title);
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
