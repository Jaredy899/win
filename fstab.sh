#!/bin/bash

# Define the line to be added
new_entry="//10.24.24.3/Storage /mnt/jarednas cifs username=jared,password=jarjar89,iocharset=utf8,vers=3.0,noperm 0 0"

# Check if the line already exists in /etc/fstab
if grep -Fxq "$new_entry" /etc/fstab
then
    echo "The entry already exists in /etc/fstab"
else
    # Add the new entry to the end of /etc/fstab
    echo "$new_entry" | sudo tee -a /etc/fstab > /dev/null
    echo "The entry has been added to /etc/fstab"
fi
