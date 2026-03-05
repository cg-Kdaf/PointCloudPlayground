# Image Localizer module

The idea of this module is to take a single image and localize it in the point cloud map. This is done by taking the image, extracting features from it, and then matching those features to the point cloud map. This will allow us to determine the location of the camera in the point cloud map.

## Approach:

### First idea (not tryed, probably not working):
The first idea I had was to use a model that estimates the image depth (using Apple Depth Pro for example) channel and then create a point cloud from the image. With this point cloud I would do a point cloud matching with geometric descriptors (proposed by 3DMatch for example).

### Second idea:
The second idea is to make my own model based on what 3DMatch does. I would take local descriptors from the image and match that with local descriptors from the point cloud.
Because it is not the same moality, I would learn from localized data (maybe aligning a 3d scan and taking the images positions as ground truth) and then learn the correspondance between image descriptors and point cloud descriptors.
