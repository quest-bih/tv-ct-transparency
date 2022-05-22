import argparse
import subprocess
import os
import pandas as pd


def main():
    parser = argparse.ArgumentParser(description='Create email package')
    parser.add_argument('data', metavar='DATA', type=str,
                        help='The data to use (.csv file)')
    parser.add_argument('--letters_dir', metavar='DIR', type=str,
                        default=os.getcwd(), dest="letters_dir",
                        help='Where to get the invitation letters from (default: current work dir)')
    parser.add_argument('--reports_dir', metavar='DIR', type=str,
                        default=os.getcwd(), dest="reports_dir",
                        help='Where to get the report cards from (default: current work dir)')
    parser.add_argument('--outdir', metavar='DIR', type=str,
                        default=os.getcwd(), dest="outdir",
                        help='Where to store the final attachments (default: current work dir)')

    args = parser.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    # Read dataset with email parameters
    data = pd.read_csv(args.data)

    # Iterate over each contact and select the correct files to merge
    for _, row in data.iterrows():
        name = row['name_for_file']
        letter_to_merge = os.path.join(args.letters_dir, f"{name}.pdf")
        merged = os.path.join(args.outdir, f"{name}.pdf")
        rc = row['ids']
        rc_split = rc.split(";")
        trials = []
        for trial in rc_split:
            trial = trial.strip()
            reports_to_merge = os.path.join(args.reports_dir, f"{trial}.pdf")
            trials.append(reports_to_merge)

        subprocess.run(["pdfunite", letter_to_merge] + trials + ["infosheet.pdf", merged], check=True)


if __name__ == "__main__":
    main()