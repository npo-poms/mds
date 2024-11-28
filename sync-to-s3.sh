#!/bin/bash -e
LOGS=${LOGS:-/tmp}
ARCHIVE=${ARCHIVE:-/tmp/archive}

KEY=${1//\//_}
LOG_FILE="${LOGS}/$KEY.log"
ARCHIVE_DIR="$ARCHIVE/$KEY"
TEMP_DIR="/tmp/$KEY.tmpdir"
SOURCE_DIR=$1
S3S=$2

# Just directly sync to s3. If the input directory is well behaved, this may be enough
# just schedule it sometimes.

copy_to_s3() {
  mkdir -p "$TEMP_DIR"
  mv  -v "$SOURCE_DIR/"*.xml  "$TEMP_DIR" | tee -a "$LOG_FILE"
  echo "copying to s3"
  for s3 in $S3S ; do
     s3cmd -c "$s3.cfg" -v sync "$TEMP_DIR/" --no-delete-removed "s3://$s3"  | tee -a "$LOG_FILE"
  done
  echo moving
  mv -v "$TEMP_DIR/"* "$ARCHIVE_DIR" | tee -a "$LOG_FILE"

}


## watching though of course has the advantage that the files will be moved asap!

# watches a directory, and copies all appearing (valid) xml files to temp_source
# $1 source directory to watch for
watch_to_copy() {
  mkdir -p "$TEMP_DIR"
  mkdir -p "$SOURCE_DIR"
  inotifywait "$SOURCE_DIR" --monitor -e modify --format "%f:%e" | \
    while  IFS=':' read -r file event; do
      #echo "considering $event $source/$file"
      if xmllint --noout "$SOURCE_DIR/$file" ; then
        mv -v "$SOURCE_DIR/$file" "$TEMP_DIR" | tee -a "$LOG_FILE"
      else
        echo "$SOURCE_DIR/$file" seems not ready yet
      fi
    done
}

# watches temp directory, and moves all appearing (valid) xml files to temp_source
# I doubt whether this is actually needed. rsync will use temp-file, and then move to correct file name. So the include .xml should perhaps have been sufficient.

watch_temp() {
  mkdir -p "$ARCHIVE_DIR"
  inotifywait "$TEMP_DIR" --include '.*\.xml$' --monitor -e moved_to --format "%f" | \
    while read -r file; do
      full_path="$TEMP_DIR/$file"
      for s3 in $S3S ; do
        s3cmd -c "$s3".cfg --no-check-md5 --preserve --stats    put "$full_path" "s3://$s3"  | tee -a "$LOG_FILE"
      done
      mv -v "$full_path" "$ARCHIVE_DIR" | tee -a "$LOG_FILE"
    done
}

start() {
  mkdir -p "$LOGS"
  echo "Logging to $LOG_FILE"
  # start with copying files already there
  copy_to_s3

  # temp directory is watched to copy to s3 (and then move the file to archive)
  watch_temp  &

  # appearing files are moved to  temp dir
  watch_to_copy
}

start
