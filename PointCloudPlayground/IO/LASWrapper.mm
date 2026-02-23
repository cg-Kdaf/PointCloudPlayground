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
  size_t bufferSize = numPoints * 4 * sizeof(float);
  float* pointBuffer = (float*)malloc(bufferSize);
  const double medium_x = (header->max_x - header->min_x) / 2.0 + header->min_x;
  const double medium_y = (header->max_y - header->min_y) / 2.0 + header->min_y;
  const double medium_z = (header->max_z - header->min_z) / 2.0 + header->min_z;
  
  // Prepare to read points
  laszip_point* point;
  laszip_get_point_pointer(reader, &point);
  
  for (int i = 0; i < numPoints; i++) {
    laszip_read_point(reader);
    
    // LASzip C API handles the scaling/offset logic inside get_x/y/z
    // if you use the header values, but here we do it manually:
    double worldX = point->X * header->x_scale_factor + header->x_offset;
    double worldY = point->Y * header->y_scale_factor + header->y_offset;
    double worldZ = point->Z * header->z_scale_factor + header->z_offset;
    
    pointBuffer[i*4 + 0] = (float)(worldX - medium_x);
    pointBuffer[i*4 + 1] = (float)(worldY - medium_y);
    pointBuffer[i*4 + 2] = (float)(worldZ - medium_z);
    pointBuffer[i*4 + 3] = 0.0;
  }
  
  laszip_close_reader(reader);
  laszip_clean(reader);
  
  return [NSData dataWithBytesNoCopy:pointBuffer length:bufferSize freeWhenDone:YES];
}

@end
