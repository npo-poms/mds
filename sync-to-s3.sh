#!/bin/bash -e

key() {
  echo ${1//\//_}
}

temp_source() {
  echo /tmp/$(key $1)
}

copy_to_s3() {
  source=$1
  s3=$2
  tempdir=$(temp_source $1)
  mkdir -p $tempdir
  rm -rf "${tempdir}"/*
  mv  $source/*  $tempdir | :
  echo "copying to s3"
  ls $tempdir

  s3cmd -c $s3.cfg -v sync $tempdir/ --no-delete-removed s3://$s3  | tee -a /tmp/rsync.log
}
watch_to_copy() {
  source=$1
  tempdir=$(temp_source $1)
  mkdir -p $tempdir
  mkdir -p $source

  inotifywait $source --monitor -e modify --format "%f:%e" | \
    while  IFS=':' read  file event; do
      echo "considering $event $source/$file"
      if xmllint --noout $source/$file ; then
        mv $source/$file $tempdir
      else
        echo $source/$file seems not ready yet
      fi

    done

}

watch_temp() {
  tempdir=$(temp_source $1)
  s3=$2
  echo s3 $s3

  inotifywait $tempdir --monitor -e moved_to --format "%f" | \
    while read  file; do
        s3cmd -c $s3.cfg -v put $tempdir/$file s3://$s3  | tee -a /tmp/rsync.log
    done
}


copy_to_s3 $1 $2
watch_to_copy $1 &
watch_temp $1 $2
