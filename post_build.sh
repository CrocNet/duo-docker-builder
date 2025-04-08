#!/bin/bash

#Executed by Buildroot, during build process

set -x
set -e

TROOTFS="${BR_DIR}/output/${BR_BOARD}/target"


DIRS_TO_MERGE=("/bin" "/lib" "/sbin")
for dir in "${DIRS_TO_MERGE[@]}"; do
    target_dir="/usr$dir"
    relative_target="usr$dir" # For relative symlink

    echo "Processing $dir..."

    # Check if it's NOT a symbolic link
    if [[ ! -L "${TROOTFS}/$dir" ]]; then
        # Check if it IS a directory before proceeding
        if [[ -d "${TROOTFS}/$dir" ]]; then
            echo "  -> $dir is a directory, not a symlink. Merging..."

            # 1. Move contents (using find for better handling of files/links)
            echo "     Moving contents of $dir to $target_dir..."
            find "${TROOTFS}/$dir" -mindepth 1 -maxdepth 1 -exec mv -t "${TROOTFS}/$target_dir/" {} +
            if [[ $? -ne 0 ]]; then
                 echo "     ERROR: Failed to move contents from $dir. Stopping process for $dir."
                 continue # Skip to next directory in the loop
            fi

            # 2. Remove the now-empty original directory.
            echo "     Removing original directory $dir..."
            rmdir "${TROOTFS}/$dir"
             if [[ $? -ne 0 ]]; then
                 echo "     ERROR: Failed to remove directory $dir (might not be empty?). Stopping process for $dir."
                 continue # Skip to next directory in the loop
            fi

            # 3. Create the relative symbolic link.
            echo "     Creating symlink $dir -> $relative_target..."
            ln -s "$relative_target" "${TROOTFS}/$dir"
             if [[ $? -ne 0 ]]; then
                 echo "     ERROR: Failed to create symlink for $dir."
                 continue # Skip to next directory in the loop
            fi

            echo "  -> Merge completed for $dir."
        else
            echo "  -> $dir is not a directory or a symlink. Skipping."
        fi
    else
        echo "  -> $dir is already a symbolic link. Skipping."
    fi
done


# Create a ld.so.conf to includes the .d directory
printf "%s\n" "include /etc/ld.so.conf.d/*.conf" >> ${TROOTFS}/etc/ld.so.conf
chmod 644 ${TROOTFS}/etc/ld.so.conf

# Create the .d directory
mkdir -p ${TROOTFS}/etc/ld.so.conf.d
chmod 755 ${TROOTFS}/etc/ld.so.conf.d

# Create the specific conf file pointing to /usr/lib
printf "%s\n" "/usr/lib" > ${TROOTFS}/etc/ld.so.conf.d/libc.conf
chmod 644 ${TROOTFS}/etc/ld.so.conf.d/libc.conf

dirs=(${TROOTFS}/usr/lib/*-linux-gnu)
if [ -d "${dirs[0]}" ]; then
  ARCHDIR="/usr/lib/${dirs[0]##*/}"  
  rsync -a --remove-source-files ${TROOTFS}${ARCHDIR}/ ${TROOTFS}/usr/lib/
  
  echo ${TROOTFS}${ARCHDIR}  | tee -a ${TROOTFS}/etc/ld.so.conf.d/arch.conf > /dev/null
  chmod 644 ${TROOTFS}/etc/ld.so.conf.d/arch.conf  
fi

# Run ldconfig, using proot (chroot-lite)
proot -S "${TROOTFS}" -q ${QEMU} /sbin/ldconfig -v
