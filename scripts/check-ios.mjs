import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const swift = fs.readdirSync(path.join(root, 'ios/Rajya')).filter(name => name.endsWith('.swift'));
const app = swift.map(name => read('ios/Rajya/' + name)).join('\n');
assert(!/import\s+WebKit|WKWebView|UIWebView|loadHTMLString|evaluateJavaScript/.test(app), 'Native app must not embed the website');
const actions = [...app.matchAll(/(?:request\(|authenticate\()[\s\n]*"([a-z_]+)"/g)].map(match => match[1]);
const serverFiles = ['api.php', 'platform.php', 'account-actions.php', 'subscriptions.php'];
if (serverFiles.every(file => fs.existsSync(path.join(root, file)))) {
  const server = serverFiles.map(read).join('\n');
  for (const action of actions) assert(server.includes(`'${action}'`), 'Unknown API action: ' + action);
} else {
  console.log('Standalone native checkout: PHP API implementation checks skipped; verify the live service separately.');
}
assert(app.includes('X-CSRF-Token') && app.includes('URLSessionConfiguration.ephemeral'), 'Native session safeguards missing');
assert(app.includes('delete_account') && app.includes('report_ai_content'), 'Deletion/reporting flow missing');
assert(!/bank_payment_info|submit_bank|billing-attachment\.php/.test(app), 'Bank checkout is not approved for this iOS build');
const resources = path.join(root, 'ios/Rajya/Resources');
const catalog = JSON.parse(read('ios/Rajya/Resources/catalog.json'));
assert.equal(catalog.books.length, 3);
assert.equal(catalog.books.reduce((sum, book) => sum + book.pages, 0), 977);
for (const book of catalog.books) {
  const file = fs.readFileSync(path.join(resources, book.slug + '.pdf'));
  assert.equal(crypto.createHash('sha256').update(file).digest('hex'), book.sha256);
}
const icon = fs.readFileSync(path.join(resources, 'Assets.xcassets/AppIcon.appiconset/AppIcon.png'));
assert.equal(icon.readUInt32BE(16), 1024); assert.equal(icon.readUInt32BE(20), 1024);
assert.equal(icon[25], 2, 'App Store icon must use RGB without alpha');
assert(read('ios/project.yml').includes('B5U69WW3Q3'));
assert(read('codemagic.yaml').includes('xcodebuild test'));
assert(!read('codemagic.yaml').includes('submit_to_app_store: true'));
console.log(`PASS native source/API contract checks: ${swift.length} Swift files, ${new Set(actions).size} API actions, 3 original PDF hashes, 977 pages, 1024px icon, Codemagic test workflow.`);
console.log('These source checks do not compile Swift or replace Xcode/device testing.');
