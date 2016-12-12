#import "BookmarkButtonCell.h"
#import "ZKSwizzle.h"
#import <CommonCrypto/CommonDigest.h>

@import AppKit;

@interface NoFavicons : NSObject
@end

NoFavicons *plugin;

@implementation NoFavicons 

+ (NoFavicons*) sharedInstance
{
    static NoFavicons * plugin = nil;
    
    if (plugin == nil)
        plugin = [[NoFavicons alloc] init];
    
    return plugin;
}

+ (void) load
{
    NSLog(@"NoFavicons loading...");
    plugin = [NoFavicons sharedInstance];
    ZKSwizzle(wb_BookmarkButtonCell, BookmarkButtonCell);
    NSLog(@"%@ loaded into %@ on macOS 10.%ld", [self class], [[NSBundle mainBundle] bundleIdentifier], [[NSProcessInfo processInfo] operatingSystemVersion].minorVersion);
}

@end

@interface wb_BookmarkButtonCell : NSButtonCell
@end

@implementation wb_BookmarkButtonCell

static NSString *minWidth = @"wb_NF_minWidth";
static NSArray *Folderhashes = nil;

- (struct CGRect)imageRectForBounds:(struct CGRect)arg1
{
    // Remove Image
    if ([[self title] isEqualToString:@""])
        return ZKOrig(struct CGRect, arg1);
    
    return CGRectZero;
}

- (double)textStartXOffset
{
    // Proper text placement
    return 5.0;
}

- (struct CGSize)cellSize
{
    // Prevent this from resizing larger once the initial size is set above 0
    // Buttons will still resize when edited but this prevents a resize when the favicon is first loaded
    CGSize result = ZKOrig(struct CGSize);
    int oldsize = [objc_getAssociatedObject(self, minWidth) intValue];
    int newsize = result.width;
    if (oldsize == 0)
        objc_setAssociatedObject(self, minWidth, [NSNumber numberWithInt:newsize], OBJC_ASSOCIATION_RETAIN);
    if (newsize <= oldsize)
        objc_setAssociatedObject(self, minWidth, [NSNumber numberWithInt:newsize], OBJC_ASSOCIATION_RETAIN);
    if (oldsize != 0)
        result.width = oldsize;
    
    return result;
}

- (void)setBookmarkCellText:(id)arg1 image:(id)arg2
{    
    if ([self imageIsFolder:arg2])
        if (![(BookmarkButtonCell*)self isFolderButtonCell])
            arg1 = [NSString stringWithFormat:@"%@ ▾", arg1];
    ZKOrig(void, arg1, nil);
}

- (BOOL) imageIsFolder: (NSImage*)image
{
    if (Folderhashes == nil) {
        Folderhashes = [[NSArray alloc] initWithObjects:@"4cc0afe6dc8a0cee961f15b087f6cc13784f6bad", @"c3706d5b34a4b336f1a08b2819a01698c94c92ff", @"e7bb69efe7575935236c0dacee014df026acbf8f", nil];
    }
    NSData* data = [image TIFFRepresentation];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (uint)data.length, digest);
    NSMutableString* sha1 = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
        [sha1 appendFormat:@"%02x", digest[i]];
    return ([Folderhashes indexOfObject:sha1] != NSNotFound);
}

@end
