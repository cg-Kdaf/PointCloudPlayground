//
//  LASWrapper.h
//  PointCloudPlayground
//
//  Created by Colin Marmond on 22/02/2026.
//

#import <Foundation/Foundation.h>

@interface LASWrapper : NSObject

/**
 * Loads points from a .laz or .las file.
 * Returns NSData containing a raw buffer of 'float' values (X, Y, Z sequence).
 * 'count' is populated with the number of points found.
 */
- (NSData * _Nullable)loadPointsFromPath:(NSString * _Nonnull)path
                                   count:(int * _Nonnull)outCount;

@end
