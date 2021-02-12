#!/usr/bin/env python3

import sys

# Total number of words in memory
TOTAL_SIZE = 1024

if __name__ == "__main__":
    _, input_filename, output_filename = sys.argv

    word_index = 0

    with open(output_filename, "w") as outfile:
        with open(input_filename, "rb") as infile:
            while word := infile.read(4):
                arr = bytearray(word)
                arr.reverse()
                outfile.write(f"{arr.hex()}\n")
                word_index += 1
        
        for i in range(TOTAL_SIZE - word_index):
            outfile.write(f"00000000\n")
