EscherRuby - HTTP request signing lib [![Build Status](https://travis-ci.org/emartech/escher-ruby.svg?branch=master)](https://travis-ci.org/emartech/escher-ruby)
=====================================

Escher helps you creating secure HTTP requests (for APIs) by signing HTTP(s) requests. It's both a server side and client side implementation. The status is work in progress.

The algorithm is based on [Amazon's _AWS Signature Version 4_](http://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-authenticating-requests.html), but we have generalized and extended it.

More details will be available at our [documentation site](http://escherauth.io/).

Check out a [working example] (https://github.com/emartech/escher-ruby-example).

### Local development

#### Running tests

```bash
make test
```
