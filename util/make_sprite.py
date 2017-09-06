import sys
import struct

def main():
    if len(sys.argv) < 6:
        print('Usage: out_filename bmp_filename width height color_key_index anim_count anim_frames... anim_fps...')
        exit(1)

    with open('{0}.spr'.format(sys.argv[1]), 'wb+') as out:
        # write bmp source filename and sizes
        out.write(struct.pack('256sHH', sys.argv[2].encode('ascii'), int(sys.argv[3]), int(sys.argv[4])))

        # write color key
        out.write(struct.pack('H', int(sys.argv[5])))

        # write anims
        anim_count = int(sys.argv[6])
        out.write(struct.pack('H', anim_count))

        anim_frame_count = [0 for _ in range(10)]
        for i in range(anim_count):
            anim_frame_count[i] = int(sys.argv[7+i])
        out.write(struct.pack('10H', *anim_frame_count))

        anim_fps = [0 for _ in range(10)]
        for i in range(anim_count):
            anim_fps[i] = int(sys.argv[7+anim_count+i])
        out.write(struct.pack('10H', *anim_fps))

if __name__ == '__main__':
    main()
