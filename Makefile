IMAGE := npo-poms/mds


.PHONY: docker

docker:
	docker build  -t $(IMAGE) .

test:
	docker run -it -v /tmp:/tmp -v .:/workdir $(IMAGE) /tmp/foo mihxil
