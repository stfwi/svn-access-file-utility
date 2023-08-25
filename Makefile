#------------------------------------------------------------------------
PROGRAM_NAME=svn-access
BINARY_EXTENSION=.exe
BINARY=$(PROGRAM_NAME)$(BINARY_EXTENSION)
DJS=djs-min
#------------------------------------------------------------------------
.PHONY: binary clean test run

binary: build/$(BINARY)

clean:
	@rm -rf build

run:
	@./build/$(BINARY) $(TEST_ARGS)

# Tests to be refined if the script shall get a bit more complex.
test: binary
	@echo "### help ----------------" >>./build/test.log 2>&1
	./build/$(BINARY) -v --help >>./build/test.log 2>&1
	./build/$(BINARY) -v -h >/dev/null 2>&1
	./build/$(BINARY) -v help >/dev/null 2>&1
	@echo "### read ----------------" >>./build/test.log 2>&1
	./build/$(BINARY) -v read test/data/example-access >>./build/test.log 2>&1
	@echo "### sort ----------------" >>./build/test.log 2>&1
	./build/$(BINARY) -v sort test/data/example-access >>./build/test.log 2>&1
	@echo "#--" >>./build/test.log 2>&1
	./build/$(BINARY) -v sort --json test/data/example-access >>./build/test.log 2>&1
	@echo "### sections ----------------" >>./build/test.log 2>&1
	./build/$(BINARY) -v sections test/data/example-access >>./build/test.log 2>&1
	@echo "#--" >>./build/test.log 2>&1
	./build/$(BINARY) -v --json sections test/data/example-access >>./build/test.log 2>&1
	@echo "### groups ----------------" >>./build/test.log 2>&1
	./build/$(BINARY) -v groups test/data/example-access >>./build/test.log 2>&1
	@echo "#--" >>./build/test.log 2>&1
	./build/$(BINARY) -v groups --json test/data/example-access >>./build/test.log 2>&1
	@echo "### group ----------------" >>./build/test.log 2>&1
	./build/$(BINARY) -v group test/data/example-access user >>./build/test.log 2>&1
	@echo "#--" >>./build/test.log 2>&1
	./build/$(BINARY) -v group --json test/data/example-access user >>./build/test.log 2>&1
	@echo "### user ----------------" >>./build/test.log 2>&1
	./build/$(BINARY) -v user test/data/example-access nobody@example.com >>./build/test.log 2>&1
	@echo "#--" >>./build/test.log 2>&1
	./build/$(BINARY) -v user --json test/data/example-access nobody@example.com >>./build/test.log 2>&1

build/$(BINARY): src/main.djs
	@mkdir -p build
	@rm -f $@
	@$(DJS) -e "sys.app.attachment.write('$@', fs.readfile('$<'))"

-include dev.mk
