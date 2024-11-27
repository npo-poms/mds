IMAGE := npo-poms/mds

S3:=mihxil


.PHONY: docker

docker:
	docker build  -t $(IMAGE) .

test:
	docker run -it -v /tmp:/tmp -v .:/workdir $(IMAGE) /tmp/$(S3) $(S3)
