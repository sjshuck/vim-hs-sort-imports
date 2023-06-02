#! /usr/bin/env bash
set -e

cd "$(dirname "$BASH_SOURCE")/.."

exec lua test/test.lua
