DOCKER_BAZEL_IMG=gcr.io/cloud-marketplace-containers/google/bazel
DOCKER_RK_SCHED_IMG=repository-master.rubrik.com:5000/bazel/bb_scheduler
DOCKER_RK_WORKER_IMG=repository-master.rubrik.com:5000/bazel/bb_worker

SRC_DIR=$(CURDIR)
DOCKER_WORK_DIR=/src/workspace
OUT_DIR=/tmp/bazel-output
DOCKER_OUT_DIR=/tmp/bazel-output

BAZEL_RESULT_DIR=$(CURDIR)/bazel-result

BAZEL_CLIENT_CFG=--output_user_root=$(DOCKER_OUT_DIR)

WORKER_TARGET=bb_worker_container.tar
SCHEDULER_TARGET=bb_scheduler_container.tar

all: clean bb-worker bb-scheduler

.NOTPARALLEL:

bb-worker:
	mkdir -p $(OUT_DIR)
	docker run \
		-v $(SRC_DIR):$(DOCKER_WORK_DIR) \
		-v $(OUT_DIR):$(DOCKER_OUT_DIR) \
		-w $(DOCKER_WORK_DIR) \
		-it $(DOCKER_BAZEL_IMG) \
		$(BAZEL_CLIENT_CFG) build //cmd/bb_worker:$(WORKER_TARGET)
	mkdir -p $(BAZEL_RESULT_DIR)
	cp bazel-bin/cmd/bb_worker/$(WORKER_TARGET) $(BAZEL_RESULT_DIR)

bb-scheduler:
	mkdir -p $(OUT_DIR)
	docker run \
		-v $(SRC_DIR):$(DOCKER_WORK_DIR) \
		-v $(OUT_DIR):$(DOCKER_OUT_DIR) \
		-w $(DOCKER_WORK_DIR) \
		-it $(DOCKER_BAZEL_IMG) \
		$(BAZEL_CLIENT_CFG) build //cmd/bb_scheduler:$(SCHEDULER_TARGET)
	mkdir -p $(BAZEL_RESULT_DIR)
	cp bazel-bin/cmd/bb_scheduler/$(SCHEDULER_TARGET) $(BAZEL_RESULT_DIR)

bb-docker-push:
	$(eval timestamp := $(shell date +%s))
	$(eval githash := $(shell git rev-parse --short HEAD))
	$(eval dockertag := $(timestamp)_$(githash))
	# TODO/sarath: don't push if githash is the same
	docker import $(BAZEL_RESULT_DIR)/$(SCHEDULER_TARGET) $(DOCKER_RK_SCHED_IMG):$(dockertag)
	docker import $(BAZEL_RESULT_DIR)/$(WORKER_TARGET) $(DOCKER_RK_WORKER_IMG):$(dockertag)
	docker push $(DOCKER_RK_SCHED_IMG):$(dockertag)
	docker push $(DOCKER_RK_WORKER_IMG):$(dockertag)

clean:
	rm -rf $(BAZEL_RESULT_DIR) bazel-bin bazel-workspace bazel-testlogs bazel-out
