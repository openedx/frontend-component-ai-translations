export TRANSIFEX_RESOURCE = frontend-component-ai-translations
transifex_resource = frontend-component-ai-translations
transifex_langs = "ar,fr,es_419,zh_CN,pt,it,de,uk,ru,hi,fr_CA"

transifex_utils = ./node_modules/.bin/transifex-utils.js
i18n = ./src/i18n
transifex_input = $(i18n)/transifex_input.json

# This directory must match .babelrc .
transifex_temp = ./temp/babel-plugin-formatjs

build:
	rm -rf ./dist
	./node_modules/.bin/fedx-scripts babel src --out-dir dist --source-maps --ignore **/*.test.jsx,**/__mocks__,**/__snapshots__,**/setupTest.js --copy-files
	@# --copy-files will bring in everything else that wasn't processed by babel. Remove what we don't want.
	@rm -rf dist/*.test.jsx
	@rm -rf dist/**/*.test.jsx
	@rm -rf dist/**/__snapshots__
	@rm -rf dist/__mocks__

requirements:
	npm install

test:
	npm run test

i18n.extract:
	# Pulling display strings from .jsx files into .json files...
	rm -rf $(transifex_temp)
	npm run-script i18n_extract

i18n.concat:
	# Gathering JSON messages into one file...
	$(transifex_utils) $(transifex_temp) $(transifex_input)

extract_translations: | requirements i18n.extract i18n.concat

# Despite the name, we actually need this target to detect changes in the incoming translated message files as well.
detect_changed_source_translations:
	# Checking for changed translations...
	git diff --exit-code $(i18n)

# Pushes translations to Transifex.  You must run make extract_translations first.
push_translations:
	# Pushing strings to Transifex...
	tx push -s
	# Fetching hashes from Transifex...
	./node_modules/@edx/reactifex/bash_scripts/get_hashed_strings_v3.sh
	# Writing out comments to file...
	$(transifex_utils) $(transifex_temp) --comments --v3-scripts-path
	# Pushing comments to Transifex...
	./node_modules/@edx/reactifex/bash_scripts/put_comments_v3.sh

ifeq ($(OPENEDX_ATLAS_PULL),)
# Pulls translations from Transifex.
pull_translations:
	tx pull -t -f --mode reviewed --languages=$(transifex_langs)
else
# Pulls translations using atlas.
pull_translations:
	rm -rf src/i18n/messages
	mkdir src/i18n/messages
	cd src/i18n/messages \
	   && atlas pull --filter=$(transifex_langs) \
	            translations/paragon/src/i18n/messages:paragon \
	            translations/frontend-component-footer/src/i18n/messages:frontend-component-footer \
	            translations/frontend-component-header/src/i18n/messages:frontend-component-header \
	            translations/frontend-template-application/src/i18n/messages:frontend-template-application

	$(intl_imports) paragon frontend-component-header frontend-component-footer frontend-template-application
endif

# This target is used by Travis.
validate-no-uncommitted-package-lock-changes:
	# Checking for package-lock.json changes...
	git diff --exit-code package-lock.json
