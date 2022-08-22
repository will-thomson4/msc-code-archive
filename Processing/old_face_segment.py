import sys
import torch
import os

from torchvision.utils import save_image
import torch
import torchvision

sys.path.append('..')

device = 'cuda' if torch.cuda.is_available() else 'cpu'

import facer
from PIL import Image

#Loop through all images in a directory
if not os.path.exists('mask'):
    os.makedirs('mask')

for count, img in enumerate(os.listdir('imgs')):   
    print("Processing image: " + img)

    #Detect face in image
    image = facer.hwc2bchw(facer.read_hwc('imgs/'+ img)
                        ).to(device=device)  # image: 1 x 3 x h x w
    face_detector = facer.face_detector('retinaface/mobilenet', device=device)
    with torch.inference_mode():
        faces = face_detector(image)

    # #Show the detected faces
    # facer.show_bchw(facer.draw_bchw(image, faces))

    face_parser = facer.face_parser('farl/lapa/448', device=device)
    with torch.inference_mode():
        faces = face_parser(image, faces)
    seg_logits = faces['seg']['logits']
    seg_probs = seg_logits.softmax(dim=1)  # nfaces x nclasses x h x w

    # Save the segmented mask as a png
    # facer.show_bhw(seg_probs.argmax(dim=1).float()/seg_logits.size(1)*255)
    # facer.show_bchw(facer.draw_bchw(image, faces))

    mask = (seg_probs.argmax(dim=1).float()/seg_logits.size(1)*255)[0]
    save_image(mask, 'mask/'+ img)

    print('Saved mask ' + str(count))