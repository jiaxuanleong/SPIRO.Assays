#!/usr/bin/env python
# Script to rename image files when captured with incorrect date/time set,
# such as when running SPIRO without access to NTP and without battery-backed RTC.
# Credit: L-103 <Loïc Talide>

import os
from datetime import datetime, timedelta

def rename_files(start_date, start_time, directory):
    # Convert start_date and start_time to datetime object
    start_datetime = datetime.strptime(start_date + start_time, '%Y%m%d%H:%M:%S')
    
    # Find the minimum datetime among all files
    min_datetime = None
    if not os.path.isdir(directory):
        raise OSError('Directory not found')

    for root, dirs, files in os.walk(directory):
        for filename in files:
            if filename.endswith('.png'):
                parts = filename.split('-')
                file_datetime = datetime.strptime(parts[1] + parts[2], '%Y%m%d%H%M%S')
                if min_datetime is None or file_datetime < min_datetime:
                    min_datetime = file_datetime
                
    # Iterate through files in directory and subdirectories
    for root, dirs, files in os.walk(directory):
        for filename in files:
            if filename.endswith('.png'):
                parts = filename.split('-')
                plate_number = parts[0]
                dayornight = parts[3]
                file_datetime = datetime.strptime(parts[1] + parts[2], '%Y%m%d%H%M%S')

                # Calculate time difference between start and current file
                time_difference = file_datetime - min_datetime

                # Calculate new timestamp for the file
                new_datetime = start_datetime +  time_difference

                # Rename the file with new timestamp
                new_filename = f'{plate_number}-{new_datetime.strftime("%Y%m%d-%H%M%S")}-{dayornight}'
                os.rename(os.path.join(root, filename), os.path.join(root, new_filename))

    print("Files renamed successfully!")

# Example usage:
start_date = input("Enter start date (YYYYMMDD): ")
start_time = input("Enter start time (HH:MM:SS): ")
directory = input("Enter path to folder (Use forward slashes as directory separators): ")
if not directory.endswith('/') or not directory.endswith('\\'): directory += '/'

rename_files(start_date, start_time, directory)
