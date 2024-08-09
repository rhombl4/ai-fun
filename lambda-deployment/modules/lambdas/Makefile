# Makefile for managing Lambda deployments

ZIP_EXCLUDES = --exclude=.touch --exclude=Makefile

.PHONY: help
help:
	@echo "Usage:"
	@echo "  make help              - Show this help message"
	@echo "  make force-redeploy    - Force a Lambda redeployment by modifying .touch file"

.PHONY: force-redeploy
force-redeploy:
	@date > .touch
	@echo ".touch file has been updated. Run 'terraform apply' to redeploy."