// Copyright 1997-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "NSImage-OAExtensions.h"

#define OFForEachInArray(arrayExpression, valueType, valueVar, loopBody) { NSArray * valueVar ## _array = (arrayExpression); unsigned int valueVar ## _count , valueVar ## _index; valueVar ## _count = [( valueVar ## _array ) count]; for( valueVar ## _index = 0; valueVar ## _index < valueVar ## _count ; valueVar ## _index ++ ) { valueType valueVar = [( valueVar ## _array ) objectAtIndex:( valueVar ## _index )]; loopBody ; } }

@implementation NSImage (OAExtensions)

+ (NSImage *)imageNamed:(NSString *)name inBundleForClass:(Class)cls {
    NSBundle *bundle = [NSBundle bundleForClass:cls];
    NSURL *URL = [NSURL fileURLWithPath:[bundle pathForImageResource:name]];
    return [[[NSImage alloc] initWithContentsOfURL:URL] autorelease];
}


- (void)drawFlippedInRect:(NSRect)rect fromRect:(NSRect)sourceRect operation:(NSCompositingOperation)op fraction:(float)delta;
{
    CGContextRef context;
    
    /*
     There are two reasons for this method.
     One, to invert the Y-axis so we can draw the image flipped.
     Two, to deal with the crackheaded behavior of NSCachedImageRep (RADAR #4985046) where it snaps its drawing bounds to integer coordinates *in the current user space*. This means that if your coordinate system is scaled from the default you get screwy results (OBS #35894).
     */
    
    context = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSaveGState(context); {
        CGContextTranslateCTM(context, NSMinX(rect), NSMaxY(rect));
        if (sourceRect.size.width == 0 && sourceRect.size.height == 0)
            sourceRect.size = [self size];
        CGContextScaleCTM(context,rect.size.width/sourceRect.size.width, -1 * ( rect.size.height/sourceRect.size.height ));
        
        // <bug://bugs/43240> (10.5/Leopard: Placed EPS and PDF images corrupted when opacity changed in Image Inspector), <bug://bugs/44518> (Copied and pasted PDFs rasterize when their opacity is changed) and RADAR 5586059 / 4766375 all involve PDF caching problems. The following seems to fix it even though I do not know why...
        OFForEachInArray([self representations], NSImageRep *, rep, {
            if ([rep isKindOfClass:[NSPDFImageRep class]] || [rep isKindOfClass:[NSEPSImageRep class]]) {
                CGContextSetAlpha(context, delta);
                delta = 1.0;
                break;
            }
        });
        
        rect.origin.x = rect.origin.y = 0; // We've translated ourselves so it's zero
        rect.size = sourceRect.size;  // We've scaled ourselves to match
        [self drawInRect:rect fromRect:sourceRect operation:op fraction:delta];
    } CGContextRestoreGState(context);
    
    /*
     NSAffineTransform *flipTransform;
     NSPoint transformedPoint;
     NSSize transformedSize;
     NSRect transformedRect;
     
     flipTransform = [[NSAffineTransform alloc] init];
     [flipTransform scaleXBy:1.0 yBy:-1.0];
     
     transformedPoint = [flipTransform transformPoint:rect.origin];
     transformedSize = [flipTransform transformSize:rect.size];
     [flipTransform concat];
     transformedRect = NSMakeRect(transformedPoint.x, transformedPoint.y + transformedSize.height, transformedSize.width, -transformedSize.height);
     [anImage drawInRect:transformedRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
     [flipTransform concat];
     [flipTransform release];
     */
}

- (void)drawFlippedInRect:(NSRect)rect fromRect:(NSRect)sourceRect operation:(NSCompositingOperation)op;
{
    [self drawFlippedInRect:rect fromRect:sourceRect operation:op fraction:1.0];
}

- (void)drawFlippedInRect:(NSRect)rect operation:(NSCompositingOperation)op fraction:(float)delta;
{
    [self drawFlippedInRect:rect fromRect:NSZeroRect operation:op fraction:delta];
}

- (void)drawFlippedInRect:(NSRect)rect operation:(NSCompositingOperation)op;
{
    [self drawFlippedInRect:rect operation:op fraction:1.0];
}

@end
