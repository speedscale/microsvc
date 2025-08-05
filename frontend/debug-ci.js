#!/usr/bin/env node

console.log('🔍 CI Debug Information:');
console.log('Node version:', process.version);
console.log('Platform:', process.platform);
console.log('Architecture:', process.arch);
console.log('Working directory:', process.cwd());
console.log('Environment variables:');
console.log('  NODE_ENV:', process.env.NODE_ENV);
console.log('  CI:', process.env.CI);
console.log('  GITHUB_ACTIONS:', process.env.GITHUB_ACTIONS);

// Check if key files exist
const fs = require('fs');
const path = require('path');

const filesToCheck = [
  'package.json',
  'next.config.ts', 
  'playwright.config.ci.ts',
  'e2e/simple.spec.ts'
];

console.log('\n📁 File existence check:');
filesToCheck.forEach(file => {
  const exists = fs.existsSync(path.join(process.cwd(), file));
  console.log(`  ${file}: ${exists ? '✅' : '❌'}`);
});

// Check available scripts
try {
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
  console.log('\n📜 Available scripts:');
  Object.keys(pkg.scripts || {}).forEach(script => {
    console.log(`  ${script}: ${pkg.scripts[script]}`);
  });
} catch (err) {
  console.log('❌ Could not read package.json');
}