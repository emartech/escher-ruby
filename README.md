EscherRuby - HTTP request signing lib [![Build Status](https://img.shields.io/github/actions/workflow/status/emartech/escher-ruby/ruby.yml?branch=master)](https://github.com/emartech/escher-ruby/actions/workflows/ruby.yml)
=====================================

Escher helps you creating secure HTTP requests (for APIs) by signing HTTP(s) requests. It's both a server side and client side implementation. The status is work in progress.

The algorithm is based on [Amazon's _AWS Signature Version 4_](http://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-authenticating-requests.html), but we have generalized and extended it.

More details will be available at our [documentation site](http://escherauth.io/).

Check out a [working example] (https://github.com/emartech/escher-ruby-example).

### Local development

To ensure you have all submodules (including test suites), please clone the repository with the `--recursive` flag:

```bash
git clone --recursive https://github.com/emartech/escher-ruby.git
```

#### Running tests

```bash
make test
```
