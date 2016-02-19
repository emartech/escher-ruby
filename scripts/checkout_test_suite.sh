#!/usr/bin/env bash
rm -rf ./spec/emarsys_test_suite
svn export https://github.com/emartech/escher-test-suite/trunk/test_cases spec/emarsys_test_suite
