#!/usr/bin/env python3
import sys
import zipfile
import os

def main():
    args = sys.argv[1:]
    dest = "."
    zip_file = None

    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "-d" and i + 1 < len(args):
            dest = args[i + 1]
            i += 2
        elif arg.startswith("-"):
            i += 1
        elif not zip_file:
            zip_file = arg
            i += 1
        else:
            i += 1

    if zip_file and os.path.exists(zip_file):
        os.makedirs(dest, exist_ok=True)
        with zipfile.ZipFile(zip_file, "r") as zf:
            for member in zf.infolist():
                extracted_path = zf.extract(member, dest)
                attr = member.external_attr >> 16
                if attr:
                    os.chmod(extracted_path, attr)

if __name__ == "__main__":
    main()
