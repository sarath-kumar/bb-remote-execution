DOCKER_BAZEL_IMG=gcr.io/cloud-marketplace-containers/google/bazel:1.0.0
DOCKER_RK_SCHED_IMG=repository-master.rubrik.com:5000/bazel/bb_scheduler
DOCKER_RK_WORKER_IMG=repository-master.rubrik.com:5000/bazel/bb_worker

SRC_DIR=$(CURDIR)
DOCKER_WORK_DIR=/src/workspace
OUT_DIR=/tmp/bazel-output
DOCKER_OUT_DIR=/tmp/bazel-output
DOCKER_LOAD_WORKER_IMG=bazel/cmd/bb_worker:bb_worker_container
DOCKER_LOAD_SCHED_IMG=bazel/cmd/bb_scheduler:bb_scheduler_container

BAZEL_RESULT_DIR=$(CURDIR)/bazel-result

BAZEL_CLIENT_CFG=--output_user_root=$(DOCKER_OUT_DIR)

WORKER_TARGET=bb_worker_container.tar
SCHEDULER_TARGET=bb_scheduler_container.tar

all: clean bb-worker bb-scheduler

.NOTPARALLEL:

bb-worker:
	docker run \
		-v $(SRC_DIR):$(DOCKER_WORK_DIR) \
		-v $(OUT_DIR):$(DOCKER_OUT_DIR) \
		-w $(DOCKER_WORK_DIR) \
		-it $(DOCKER_BAZEL_IMG) \
		$(BAZEL_CLIENT_CFG) build //cmd/bb_worker:$(WORKER_TARGET)
	mkdir -p $(BAZEL_RESULT_DIR)
	cp bazel-bin/cmd/bb_worker/$(WORKER_TARGET) $(BAZEL_RESULT_DIR)

bb-scheduler:
	docker run \
		-v $(SRC_DIR):$(DOCKER_WORK_DIR) \
		-v $(OUT_DIR):$(DOCKER_OUT_DIR) \
		-w $(DOCKER_WORK_DIR) \
		-it $(DOCKER_BAZEL_IMG) \
		$(BAZEL_CLIENT_CFG) build //cmd/bb_scheduler:$(SCHEDULER_TARGET)
	mkdir -p $(BAZEL_RESULT_DIR)
	cp bazel-bin/cmd/bb_scheduler/$(SCHEDULER_TARGET) $(BAZEL_RESULT_DIR)

bb-docker-push:
	$(eval timestamp := $(shell date -u +%Y%m%dT%H%M%SZ))
	$(eval githash := $(shell git rev-parse --short HEAD))
	$(eval dockertag := $(timestamp)_$(githash))
	# TODO/sarath: don't push if githash is the same
	docker load -i $(BAZEL_RESULT_DIR)/$(WORKER_TARGET)
	docker image tag $(DOCKER_LOAD_WORKER_IMG) $(DOCKER_RK_WORKER_IMG):$(dockertag)
	docker load -i $(BAZEL_RESULT_DIR)/$(SCHEDULER_TARGET)
	docker image tag $(DOCKER_LOAD_SCHED_IMG) $(DOCKER_RK_SCHED_IMG):$(dockertag)
	docker push $(DOCKER_RK_WORKER_IMG):$(dockertag)
	docker push $(DOCKER_RK_SCHED_IMG):$(dockertag)

clean:
	rm -rf $(BAZEL_RESULT_DIR) bazel-bin bazel-workspace bazel-testlogs bazel-out
