import cv2
import numpy as np
import os
import zlib
import numpy as np
from PIL import Image


#Create output and intermediate directories
def create_dirs(path):
    try:
        if not os.path.exists(path):
            os.makedirs(path)
    except OSError:
        print ('Error: Creating directory of {}'.format(path))

create_dirs('output')
create_dirs('intermediate')


#----------------------------------------Convert Depth Stream Into Video----------------------------------------
depth_path = './raw-data/Depth'

# Depth data parameters
W = 640
H = 480

#This section inspired by mantoone and their work on iPad depth streaming
#see https://github.com/mantoone/DepthCapture
with open(depth_path, 'rb') as depth_file:
    data = zlib.decompress(depth_file.read(), -15)
 
FRAME_COUNT = int(len(data) / W / H / 2)

frames = np.frombuffer(data, np.float16).reshape(FRAME_COUNT,H,W).copy()
frames = np.nan_to_num(frames, 0)
maxim = frames.max()
imgs = (frames / maxim * 255.0).astype('uint8')

FPS = 25
fourcc = cv2.VideoWriter_fourcc(*'mp4v')
out = cv2.VideoWriter('intermediate/depth_video.mp4',fourcc, FPS, (h,w))

for i in range(FRAME_COUNT):
    out.write(cv2.cvtColor(np.flip(imgs[i,:,:].T, axis=1), cv2.COLOR_GRAY2BGR))

out.release()


#----------------------------------------Extract Images From Videos----------------------------------------
cap = cv2.VideoCapture('./raw-data/output.mov')

create_dirs('intermediate/unprocessed-imgs')

TRIM_FRAME = 20
SAMPLE_RATE = 10

#Loop over video first to count frames
total_frames = 0
while(True):
    ret, frame = cap.read()
    if ret:
        total_frames += 1
    else:
        break

cap.release()
cv2.destroyAllWindows()

#Read RGB video in, sample out frames and same to unprocessed-imgs
cap = cv2.VideoCapture('./raw-data/output.mov')
TRIM_FRAME = total_frames - TRIM_FRAME
current_frame = 0
count = 0

while(True):
    ret, frame = cap.read()
    
    if ret:
        if current_frame < TRIM_FRAME:
            if current_frame % SAMPLE_RATE == 0:
                name = './intermediate/unprocessed-imgs/'+ "{:03d}".format(count) + '.png'
                print ('Creating...' + name)
                cv2.imwrite(name, frame)
                count += 1

        current_frame += 1
    else:
        break

cap.release()
cv2.destroyAllWindows()


#Read depth video in, sample out frames and same to unprocessed-depths
create_dirs('intermediate/unprocessed-depths')

cap = cv2.VideoCapture('intermediate/depth_video.mp4')
current_frame = 0
count = 0

while(True):
    ret, frame = cap.read()
    
    if ret:
        if current_frame < TRIM_FRAME:
            if current_frame % SAMPLE_RATE == 0:
                #save current frame as a 3 digit number
                name = './intermediate/unprocessed-depths/' + "{:03d}".format(count) + '.png'
                print ('Creating...' + name)
                cv2.imwrite(name, frame)
                count += 1

        current_frame += 1
    else:
        break

cap.release()
cv2.destroyAllWindows()


#----------------------------------------Mask Creation----------------------------------------
#Flip images, create masks, and resize depths, save all to /data folder
create_dirs('output/mask')
create_dirs('output/depth')
create_dirs('output/images')

for count, img in enumerate(os.listdir('intermediate/unprocessed-imgs')):   
    print("Processing image: " + img)

    #Images are coming in upside down, so we flip them
    im = Image.open('intermediate/unprocessed-imgs/'+ img)
    im=im.rotate(180, expand=True)
    im.save('output/images/'+ img)

    #Save resized depths
    im = Image.open('intermediate/unprocessed-depths/'+ img)
    im = im.resize((1800,2400))
    im.save('output/depth/' + img)


    depth = 'output/depth/' + img
    print("Processing depth: " + depth)

    image_input = cv2.imread(depth, cv2.IMREAD_GRAYSCALE)

    # Calculate the mean of each channel and use that to calculate threshold
    mean_intensity = cv2.mean(image_input)
    thresh = mean_intensity[0]

    th, im_thesh = cv2.threshold(image_input, thresh, 255, cv2.THRESH_BINARY_INV)

    im_floodfill = im_thesh.copy()
    h, w = im_thesh.shape[:2]
    mask = np.zeros((h+2, w+2), np.uint8)

    # Invert image
    im_inv = cv2.bitwise_not(im_th)
    im_floodfill = im_inv.copy()

    # Floodfill from point (0, 0)
    cv2.floodFill(im_floodfill, mask, (0,0), 255)

    # & the images to fill in the gaps
    mask = im_thesh & im_floodfill
    mask = cv2.bitwise_not(mask)

    #resize mask to be 1800 x 2400
    mask = cv2.resize(mask, (1800,2400))

    #Smooth the mask
    smoothed = cv2.medianBlur(mask, 31)

    mask_name = 'output/mask/'+ img
    print("Creating mask: " + mask_name)

    cv2.imwrite(mask_name, smoothed)