#!/usr/bin/env python3

import sys

# Total number of words in memory
TOTAL_SIZE = 1024

if __name__ == "__main__":
    _, start_addr, stop_addr, input_filename, output_filename = sys.argv

    start_word = int(start_addr, 0) // 4
    stop_word = int(stop_addr, 0) // 4

    word_index = 0
    words_written = 0

    with open(output_filename, "w") as outfile:
        with open(input_filename, "rb") as infile:
            while word := infile.read(4):
                if word_index < start_word:
                    word_index += 1
                    continue

                if word_index >= stop_word:
                    break

                if words_written >= TOTAL_SIZE:
                    assert word == b'\0' * len(word)
                    words_written += 1
                    word_index += 1
                    continue

                arr = bytearray(word.ljust(4, b'\0'))
                arr.reverse()
                outfile.write(f"{arr.hex()}\n")
                word_index += 1
                words_written += 1
        
        for i in range(TOTAL_SIZE - words_written):
            outfile.write(f"00000000\n")
