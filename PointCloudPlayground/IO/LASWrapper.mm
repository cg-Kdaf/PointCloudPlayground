//
//  LASWrapper.mm
//  PointCloudPlayground
//
//  Created by Colin Marmond on 22/02/2026.
//
#import "LASWrapper.h"
#include <laszip_api.h>

@implementation LASWrapper

- (NSData *)loadPointsFromPath:(NSString *)path count:(int *)outCount {
  laszip_POINTER reader;
  if (laszip_create(&reader)) return nil;
  
  laszip_BOOL is_compressed;
  if (laszip_open_reader(reader, [path UTF8String], &is_compressed)) {
    laszip_clean(reader);
    return nil;
  }
  printf("Is compressed %i\n", is_compressed);
  
  // Get header info to know how many points to read
  laszip_header* header;
  laszip_get_header_pointer(reader, &header);
  
  int numPoints = (int)header->number_of_point_records;
  if (numPoints == 0) numPoints = (int)header->extended_number_of_point_records;
  *outCount = numPoints;
  
  // Allocate buffer
  size_t bufferSize = numPoints * 3 * sizeof(float);
  float* pointBuffer = (float*)malloc(bufferSize);
  
  // Prepare to read points
  laszip_point* point;
  laszip_get_point_pointer(reader, &point);
  
  for (int i = 0; i < numPoints; i++) {
    laszip_read_point(reader);
    
    // LASzip C API handles the scaling/offset logic inside get_x/y/z
    // if you use the header values, but here we do it manually:
    pointBuffer[i*3 + 0] = (float)(point->X * header->x_scale_factor);
    pointBuffer[i*3 + 1] = (float)(point->Y * header->y_scale_factor);
    pointBuffer[i*3 + 2] = (float)(point->Z * header->z_scale_factor);
  }
  
  laszip_close_reader(reader);
  laszip_clean(reader);
  
  return [NSData dataWithBytesNoCopy:pointBuffer length:bufferSize freeWhenDone:YES];
}

@end
