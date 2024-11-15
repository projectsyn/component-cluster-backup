#!/bin/bash
set -euo pipefail

output_dir="/data"

k8s-object-dumper  "-dir" "${output_dir}" "$@"

( cd "${output_dir}" && tar c . )
