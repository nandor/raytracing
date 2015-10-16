#!/usr/bin/env python2

import numpy as np
import pyopencl as cl

from PIL import Image


WIDTH = 640
HEIGHT = 480


def main():
  """Entry point of the application."""

  # Create the platform, command queue & program.
  platforms = cl.get_platforms()
  ctx = cl.Context(devices=[platforms[0].get_devices(device_type=cl.device_type.GPU)[0]])
  queue = cl.CommandQueue(ctx)
  source = ''
  with open('rtrace.cl') as f:
    source = f.read()
  program = cl.Program(ctx, source).build()

  # Run the raytrace kernel.
  output = cl.Buffer(ctx, cl.mem_flags.WRITE_ONLY, HEIGHT * WIDTH * 3)
  program.raytraceKernel(queue, (HEIGHT, WIDTH), None, output)
  image = np.empty(HEIGHT * WIDTH * 3, dtype=np.uint8)
  cl.enqueue_read_buffer(queue, output, image).wait()
  image = image.reshape(HEIGHT, WIDTH, 3)

  # Display the image.
  Image.fromarray(image, 'RGB').show()


if __name__ == "__main__":
  main()
