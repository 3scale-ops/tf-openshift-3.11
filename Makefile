TEST_DOCKER_IMAGE = quay.io/3scale/soyuz:v0.3.0-ci
TEST_DOCKER_RUN = docker run -ti --rm -w /src -v $(PWD):/src $(TEST_DOCKER_IMAGE)

help: ## Print this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install-test-tools: ## Install test dependencies
	GO111MODULE=on go get github.com/raviqqe/liche

update-test-tools: ## Update test dependencies
	GO111MODULE=on go get -u github.com/raviqqe/liche

test: test-docs test-terraform ## Run all tests

docker-test: docker-test-docs docker-test-terraform ## Run all tests with docker

test-terraform: test-terraform-fmt ## Run all terraform tests

docker-test-terraform: docker-test-terraform-fmt ## Run all terraform tests with docker

TF_FMT_CHECK_CMD = terraform fmt -check -diff -recursive .

test-terraform-fmt: ## Run terraform format test
	$(TF_FMT_CHECK_CMD)

docker-test-terraform-fmt: ## Run terraform format test with docker
	$(TEST_DOCKER_RUN) $(TF_FMT_CHECK_CMD)

test-docs: test-docs-relative-links ## Run all documentation tests

docker-test-docs: docker-test-docs-relative-links ## Run all documentation tests with docker

DOCS_LICHE_CMD = liche -r . --exclude http.*

test-docs-relative-links: ## Run documentation relative links tests
	$(DOCS_LICHE_CMD)

docker-test-docs-relative-links: ## Run documentation relative links tests with docker
	$(TEST_DOCKER_RUN) $(DOCS_LICHE_CMD)
