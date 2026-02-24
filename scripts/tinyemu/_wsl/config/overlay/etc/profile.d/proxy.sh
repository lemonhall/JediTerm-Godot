#!/bin/sh

# Default proxy for lemon uncle's host environment.
# Override by exporting http_proxy/https_proxy before launching.

: "${http_proxy:=http://192.168.50.250:7897}"
: "${https_proxy:=$http_proxy}"

export http_proxy https_proxy HTTP_PROXY="$http_proxy" HTTPS_PROXY="$https_proxy"

