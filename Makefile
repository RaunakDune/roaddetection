.PHONY: clean data clean_data lint requirements sync_train_data_to_cloud sync_raw_data_from_cloud create_data_folders

#################################################################################
# GLOBALS                                                                       #
#################################################################################

PROJECT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
BUCKET = [OPTIONAL] your-bucket-for-syncing-data (do not include 's3://')
PROFILE = default
PROJECT_NAME = roaddetection
PYTHON_INTERPRETER = python3

ifeq (,$(shell which conda))
HAS_CONDA=False
else
HAS_CONDA=True
endif

ifndef region
  region = all
endif
#################################################################################
# COMMANDS                                                                      #
#################################################################################

## Install Python Dependencies
 requirements: test_environment
	pip install -U pip setuptools wheel --user
	pip install -r requirements.txt --user



## Make Dataset
 data: requirements create_data_folders
	$(PYTHON_INTERPRETER) src/data/make_dataset.py --window_size=512 --overlap=0.25 --scaling_type=equalize_adapthist --raw_prefix=$(raw_prefix) --region=$(region) data/raw data/train

## Make test data dataset
 test_data: requirements create_data_folders
	$(PYTHON_INTERPRETER) src/data/make_dataset.py --window_size=512 --overlap=0.25 --scaling_type=equalize_adapthist --raw_prefix=$(raw_prefix) data/raw data/test

## Create all necessary data folders
 create_data_folders:
	mkdir -p data/train/sat
	mkdir -p data/train/sat_rgb
	mkdir -p data/train/map

	mkdir -p data/validate/sat
	mkdir -p data/validate/sat_rgb
	mkdir -p data/validate/map

	mkdir -p data/test/sat
	mkdir -p data/test/sat_rgb
	mkdir -p data/test/map
	mkdir -p data/test/predict

## Delete all compiled Python files
 clean:
	find . -type f -name "*.py[co]" -delete
	find . -type d -name "__pycache__" -delete

## Delete all contents of data/train/map and data/train/sat
 clean_data:
	rm -f data/train/map/*
	rm -f data/train/sat/*
	rm -f data/train/sat_rgb/*

	rm -f data/validate/map/*
	rm -f data/validate/sat/*
	rm -f data/validate/sat_rgb/*

	rm -f data/test/map/*
	rm -f data/test/sat/*
	rm -f data/test/sat_rgb/*
	rm -f data/test/predict/*

## Lint using flake8
 lint:
	flake8 src

## Upload Models to cloud
 sync_models_to_cloud: requirements
	s3cmd sync models/ s3://satellite_images/models/ --host=https://storage.googleapis.com --region=eu-west1  --exclude=".DS_Store"

## Download Models from cloud
 sync_models_from_cloud: requirements
	s3cmd sync s3://satellite_images/models/ models/  --host=https://storage.googleapis.com --region=eu-west1  --exclude=".DS_Store"

## Upload Training Data to Cloud
 sync_train_data_to_cloud: requirements
	s3cmd sync data/train/ s3://satellite_images/train/ --host=https://storage.googleapis.com --region=eu-west1  --exclude=".DS_Store"

## Download Raw Data from Cloud
 sync_raw_data_from_cloud: requirements
	s3cmd sync s3://satellite_images/raw/ data/raw/ --host=https://storage.googleapis.com --region=eu-west1 --delete-removed

## Set up python interpreter environment
 create_environment:
	ifeq (True,$(HAS_CONDA))
			@echo ">>> Detected conda, creating conda environment."
	ifeq (3,$(findstring 3,$(PYTHON_INTERPRETER)))
		conda create --name $(PROJECT_NAME) python=3
	else
		conda create --name $(PROJECT_NAME) python=2.7
	endif
			@echo ">>> New conda env created. Activate with:\nsource activate $(PROJECT_NAME)"
	else
		@pip install -q virtualenv virtualenvwrapper
		@echo ">>> Installing virtualenvwrapper if not already intalled.\nMake sure the following lines are in shell startup file\n\
		export WORKON_HOME=$$HOME/.virtualenvs\nexport PROJECT_HOME=$$HOME/Devel\nsource /usr/local/bin/virtualenvwrapper.sh\n"
		@bash -c "source `which virtualenvwrapper.sh`;mkvirtualenv $(PROJECT_NAME) --python=$(PYTHON_INTERPRETER)"
		@echo ">>> New virtualenv created. Activate with:\nworkon $(PROJECT_NAME)"
	endif

## Test python environment is setup correctly
 test_environment:
	$(PYTHON_INTERPRETER) test_environment.py

#################################################################################
# PROJECT RULES                                                                 #
#################################################################################



#################################################################################
# Self Documenting Commands                                                     #
#################################################################################

.DEFAULT_GOAL := help

# Inspired by <http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html>
# sed script explained:
# /^##/:
# 	* save line in hold space
# 	* purge line
# 	* Loop:
# 		* append newline + line to hold space
# 		* go to next line
# 		* if line starts with doc comment, strip comment character off and loop
# 	* remove target prerequisites
# 	* append hold space (+ newline) to line
# 	* replace newline plus comments by `---`
# 	* print line
# Separate expressions are necessary because labels cannot be delimited by
# semicolon; see <http://stackoverflow.com/a/11799865/1968>
.PHONY: help
help:
	@echo "$$(tput bold)Available rules:$$(tput sgr0)"
	@echo
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| LC_ALL='C' sort --ignore-case \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=19 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' \
	| more $(shell test $(shell uname) = Darwin && echo '--no-init --raw-control-chars')
