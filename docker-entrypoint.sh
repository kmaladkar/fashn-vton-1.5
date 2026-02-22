#!/bin/bash
set -e
# Weights are baked into the image at build time; no download on start.
exec "$@"
