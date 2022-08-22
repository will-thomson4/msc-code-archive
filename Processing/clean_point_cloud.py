import open3d as o3d
import numpy as np

pcd = o3d.io.read_point_cloud("./sparse_points.ply")

points = np.asarray(pcd.points)
# Find the average 3D point from points
center = np.mean(points, axis=0)
print("Center of mass:", center)
center[1] -= 1.5
center[2] -= 2.5
radius = 4

# Calculate distances to center, set new points
distances = np.linalg.norm(points - center, axis=1)
pcd.points = o3d.utility.Vector3dVector(points[distances <= radius])

# Write point cloud out
o3d.io.write_point_cloud("sparse_points_interest.ply", pcd)


# o3d.visualization.draw_geometries([pcd],
#                                   zoom=0.3412,
#                                   front=[0.4257, -0.2125, -0.8795],
#                                   lookat=[2.6172, 2.0475, 1.532],
#                                   up=[-0.0694, -0.9768, 0.2024])