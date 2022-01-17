import sys

if len(sys.argv) < 3:
    print("Usage: file.raw audio.coe")
    sys.exit()
    
input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, 'rb') as f:
    bytes = f.read()


with open(output_file, 'w') as f:
    f.write("memory_initialization_radix=16;\n")
    f.write("memory_initialization_vector=\n")
    # 224000 = 8000 (sample rate) * 28 (second)
    n = len(bytes)
    print("music length is",n)
    if (n > 224000):
        n = 224000
    for i in range (n):
        f.write( '{:0>2}'.format(hex(bytes[i])[2:]) )
        f.write(",\n")


# command python audio_trans.py <file_name>.raw audio.coe