#!/bin/bash

# Script to add Node.js runtime configuration to all Next.js API routes
# This ensures all API routes use Node.js runtime instead of Edge Runtime

set -e

echo "🔧 Adding Node.js runtime configuration to all API routes..."

# Find all route.ts files in the API directory
find frontend/src/app/api -name "route.ts" -type f | while read -r file; do
    echo "Processing: $file"
    
    # Check if the file already has runtime configuration
    if ! grep -q "export const runtime" "$file"; then
        # Add runtime configuration after the import statement
        sed -i '' '/^import.*NextRequest.*NextResponse.*from.*next\/server.*;$/a\
\
// Force Node.js runtime for OpenTelemetry compatibility\
export const runtime = '"'"'nodejs'"'"';\
' "$file"
        echo "  ✅ Added Node.js runtime configuration"
    else
        echo "  ⏭️  Already has runtime configuration"
    fi
done

echo "✅ Node.js runtime configuration added to all API routes" 