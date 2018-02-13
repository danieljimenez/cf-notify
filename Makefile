# Your favorite rapper's favorite wrapper.
.PHONY: check_defined _check_defined
check_defined = \
    $(strip $(foreach 1,$1, \
        $(call _check_defined,$1,$(strip $(value 2)))))
_check_defined = \
    $(if $(value $1),, \
        $(error Undefined argument $1$(if $2, ($2))))

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
temp_dir := $(shell mktemp -d)
# End Wrapper

.PHONY: default clean build deploy

default: build deploy

build: build/venv/bin/activate

build/venv/bin/activate: requirements.txt
	$(call check_defined, s3_bucket)
	@ echo "Building in '$(temp_dir)/build/venv'..."
	cp -R '$(mkfile_dir)/' $(temp_dir)
	test -d $(temp_dir)/venv || virtualenv -q $(temp_dir)/venv
	$(temp_dir)/venv/bin/pip install -Ur ${mkfile_dir}/requirements.txt -t $(temp_dir)
	touch $(temp_dir)/venv/bin/activate
	aws cloudformation package \
		--s3-bucket $(s3_bucket) \
		--s3-prefix lambda \
		--template-file $(temp_dir)/lambda-cloudformation.transform.yaml \
		--output-template-file ${temp_dir}/cloudformation.yaml \
		--force-upload &>/dev/null

deploy: build
	$(call check_defined, slack_target)
	$(call check_defined, webhook_url)
	aws cloudformation deploy \
		--template-file $(temp_dir)/cloudformation.yaml \
		--capabilities CAPABILITY_IAM \
		--stack-name cf-notify-$(subst @,,$(subst #,,$(slack_target))) \
		--parameter-overrides WebHookURL=$(webhook_url) Target=$(slack_target)