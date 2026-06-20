#!/usr/bin/env python3
"""
Generate test CSV data for FSxN Data Analytics verification.

Usage (from NFS-mounted EC2 or locally):
  python3 generate-test-data.py /mnt/fsxn/sample

Usage (upload via S3 AP after generation):
  python3 generate-test-data.py /tmp/testdata
  aws s3 cp /tmp/testdata/ s3://<s3-ap-alias>/sample/ --recursive
"""

import csv
import datetime
import os
import random
import sys


def generate_csv(filepath: str, start_id: int, count: int, base_date: datetime.datetime) -> None:
    """Generate a CSV file with synthetic data."""
    with open(filepath, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['id', 'name', 'category', 'value', 'timestamp'])
        for i in range(start_id, start_id + count):
            writer.writerow([
                i,
                f'item_{i:06d}',
                random.choice(['A', 'B', 'C', 'D']),
                round(random.uniform(1.0, 1000.0), 2),
                (base_date + datetime.timedelta(minutes=i - start_id)).isoformat(),
            ])


def main():
    if len(sys.argv) < 2:
        print(f'Usage: {sys.argv[0]} <output-directory>')
        sys.exit(1)

    output_dir = sys.argv[1]
    os.makedirs(output_dir, exist_ok=True)

    files = [
        ('data_001.csv', 0, 100000, datetime.datetime(2025, 1, 1)),
        ('data_002.csv', 100000, 100000, datetime.datetime(2025, 7, 1)),
        ('data_003.csv', 200000, 100000, datetime.datetime(2026, 1, 1)),
    ]

    for filename, start_id, count, base_date in files:
        filepath = os.path.join(output_dir, filename)
        generate_csv(filepath, start_id, count, base_date)
        size_mb = os.path.getsize(filepath) / (1024 * 1024)
        print(f'Generated: {filepath} ({count} rows, {size_mb:.1f} MB)')

    print(f'\nTotal: {len(files)} files, 300,000 rows')
    print(f'Output directory: {output_dir}')


if __name__ == '__main__':
    main()
