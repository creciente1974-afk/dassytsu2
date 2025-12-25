#!/bin/bash
# mobile_scanner-Swift.hのobjc_ownershipエラーを修正
HEADER_FILE="${TARGET_BUILD_DIR}/mobile_scanner/mobile_scanner.framework/Headers/mobile_scanner-Swift.h"
if [ -f "$HEADER_FILE" ]; then
  sed -i '' 's/__attribute__((objc_ownership([^)]*))) *CVPixelBufferRef/CVPixelBufferRef/g' "$HEADER_FILE"
  sed -i '' 's/CVPixelBufferRef *__attribute__((objc_ownership([^)]*)))/CVPixelBufferRef/g' "$HEADER_FILE"
fi
