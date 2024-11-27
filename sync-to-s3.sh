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
  mv -f $source/* $tempdir || echo "ok (no files found?)"
  echo "copying to s3"
  ls $tempdir

  s3cmd -c $s3.cfg -v sync $tempdir --no-delete-removed s3://$s3  | tee -a /tmp/rsync.log

}
watch() {
  echo $$ > /tmp/$(key $1).pid
  source=$1
  mkdir -p $source
  s3=$2
  while true
  do
    inotifywait $source -e create
    copy_to_s3 $1 $2
  done
}


copy_to_s3 $1 $2
watch $1 $2