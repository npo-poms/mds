#!/bin/bash -e

key() {
  echo ${1//\//_}
}

temp_source() {
  echo "/tmp/$(key "$1")"
}

archive_dir() {
  echo "/tmp/archive/$(key "$1")"
}

# $1 source directory
# $2 s3-bucket destination
copy_to_s3() {
  source=$1
  s3=$2
  tempdir=$(temp_source $1)
  mkdir -p $tempdir
  rm -rf "${tempdir:?}/*"
  mv  "$source/*"  "$tempdir" | :
  echo "copying to s3"
  ls "$tempdir"
  s3cmd -c "$s3.cfg" -v sync "$tempdir/" --no-delete-removed "s3://$s3"  | tee -a "/tmp/$(key "$1").log"
}

# watches a directory, and copies all appearing (valid) xml files to temp_source
# $1 source directory to watch for
watch_to_copy() {
  source=$1
  tempdir=$(temp_source $source)
  mkdir -p "$tempdir"
  mkdir -p "$source"
  inotifywait "$source" --monitor -e modify --format "%f:%e" | \
    while  IFS=':' read -r file event; do
      echo "considering $event $source/$file"
      if xmllint --noout "$source"/"$file" ; then
        mv "$source/$file" "$tempdir"
      else
        echo "$source/$file" seems not ready yet
      fi

    done
}

# watches temp directory, and moves all appearing (valid) xml files to temp_source
# $1 source directory to watch for
watch_temp() {
  tempdir=$(temp_source $1)
  s3s=$2
  archive=$(archive_dir $source)
  mkdir -p "$archive"
  inotifywait "$tempdir" --monitor -e moved_to --format "%f" | \
    while read -r file; do
      full_path="$tempdir/$file"
      for s3 in $s3s ; do
        s3cmd -c "$s3".cfg -v put "$full_path" "s3://$s3"  | tee -a "/tmp/$(key "$1").log"
      done
      mv "$full_path" "$archive" | tee -a "/tmp/$(key "$1").log"
    done
}

# start with copying files already there
copy_to_s3 "$1" "$2"

# appearing files are moved to a auxiliary temp dir
watch_to_copy "$1" &

# and that directory is watched to copy to s3 (and then move the file to archive)
watch_temp "$1" "$2"
