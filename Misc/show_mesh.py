import open3d as o3d
import numpy as np



mesh = o3d.io.read_triangle_mesh("sparse_points.ply")
o3d.visualization.draw_geometries([mesh])

print("Computing normal and rendering it.")
mesh.compute_vertex_normals()
print(np.asarray(mesh.triangle_normals))
o3d.visualization.draw_geometries([mesh])