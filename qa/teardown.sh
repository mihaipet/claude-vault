#!/usr/bin/env bash
# Clean up the QA temp environment.
# Run this after testing to remove the temp home directory.

if [ -z "$QA_HOME" ]; then
  echo "No QA environment active (QA_HOME not set). Nothing to clean up."
  exit 0
fi

if [ ! -d "$QA_HOME" ]; then
  echo "QA_HOME directory not found: $QA_HOME"
  exit 0
fi

echo "Removing QA environment: $QA_HOME"
rm -rf "$QA_HOME"
echo "Done. Your real HOME is restored when you close this shell."
