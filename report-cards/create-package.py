import argparse
import subprocess
import os
import pandas as pd


def main():
    parser = argparse.ArgumentParser(description='Create email package')
    parser.add_argument('data', metavar='DATA', type=str,
                        help='The data to use (.csv file)')
    parser.add_argument('--letters_dir', metavar='DIR', type=str,
                        default=os.getcwd(), dest="letter_dir",
                        help='Where to get the invitation letters from (default: current work dir)')
    parser.add_argument('--reports_dir', metavar='DIR', type=str,
                        default=os.getcwd(), dest="reports_dir",
                        help='Where to get the report cards from (default: current work dir)')
    parser.add_argument('--outdir', metavar='DIR', type=str,
                        default=os.getcwd(), dest="outdir",
                        help='Where to store the final attachments (default: current work dir)')

    args = parser.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    outpdf = os.path.join(args.outdir, f"{name}-materials.pdf")

# Convert modified SVG to PDF with inkscape (open source)
#         subprocess.run([
#             "/Applications/Inkscape.app/Contents/MacOS/inkscape",
#             f"--export-filename={outpdf}",
#             outfile,
#         ], check=True)

if __name__ == "__main__":
    main()