FROM ubuntu:24.04


RUN apt-get update ; apt-get install -y s3cmd inotify-tools

WORKDIR workdir

ENTRYPOINT ["/workdir/sync-to-s3.sh"]