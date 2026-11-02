#!/usr/bin/env node
// Validate Mermaid diagram syntax with the actual Mermaid parser, not a regex heuristic.
// CI installs a pinned mermaid version as a validation-only dependency.
import { readFile } from 'node:fs/promises';
import { JSDOM } from 'jsdom';

// Mermaid's label sanitizer needs a DOM even for syntax-only parsing.
// Install one BEFORE importing Mermaid so DOMPurify initializes correctly.
const dom = new JSDOM('<!doctype html><html><body></body></html>');
globalThis.window = dom.window;
globalThis.document = dom.window.document;
globalThis.Node = dom.window.Node;
globalThis.Element = dom.window.Element;
globalThis.HTMLElement = dom.window.HTMLElement;
globalThis.SVGElement = dom.window.SVGElement;
const { default: mermaid } = await import('mermaid');

const paths = process.argv.slice(2);
if (!paths.length) paths.push('docs/GUIA_VISUAL_ORQUESTACION.md');
let failures = 0;
let total = 0;
for (const path of paths) {
  let markdown;
  try {
    markdown = await readFile(path, 'utf8');
  } catch (error) {
    console.error(`Cannot read ${path}: ${error.message}`);
    failures++;
    continue;
  }
  const diagrams = [...markdown.matchAll(/^```mermaid[ \t]*\r?\n([\s\S]*?)^```[ \t]*$/gm)];
  if (!diagrams.length) {
    console.error(`No Mermaid diagrams found in ${path}`);
    failures++;
    continue;
  }
  for (const [index, match] of diagrams.entries()) {
    const source = match[1].trim();
    total++;
    const line = markdown.slice(0, match.index).split('\n').length;
    try {
      await mermaid.parse(source);
      console.log(`OK ${path} diagram ${index + 1} (starting line ${line})`);
    } catch (error) {
      failures++;
      console.error(`INVALID ${path} diagram ${index + 1} (starting line ${line}): ${error.message}`);
    }
  }
}
if (failures) {
  console.error(`Mermaid validation failed: ${failures} issue(s) across ${total} diagram(s).`);
  process.exitCode = 1;
} else {
  console.log(`Mermaid validation passed: ${total} diagram(s).`);
}
