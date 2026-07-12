#!/usr/bin/env node

/**
 * Pass 4 Converter: Transform extraction JSON to .c4 with confidence tags
 *
 * Usage: node pass4-converter.mjs <union-json>
 *
 * Outputs a .c4 snippet ready for integration into blueprint/model/system.c4
 */

import * as fs from 'fs';

function loadJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function groupByService(extraction) {
  const services = new Map();

  for (const comp of extraction.components || []) {
    const dir = comp.file.split('/')[0] || 'root';
    if (!services.has(dir)) services.set(dir, { components: [], contracts: [] });
    services.get(dir).components.push(comp);
  }

  for (const contract of extraction.contracts || []) {
    const dir = contract.file.split('/')[0] || 'root';
    if (!services.has(dir)) services.set(dir, { components: [], contracts: [] });
    services.get(dir).contracts.push(contract);
  }

  return services;
}

function confidenceToTag(confidence) {
  if (confidence === 'PROVABLE') return '#provable';
  if (confidence === 'INFERRED') return '#inferred';
  return '';
}

function generateC4(extraction) {
  const services = groupByService(extraction);
  let c4 = '// ── Code-Level Elements (from extraction) ──────────────\n\n';

  for (const [serviceName, elements] of services) {
    c4 += `// Service: ${serviceName}\n`;

    // Components
    for (const comp of elements.components) {
      const tag = confidenceToTag(comp.confidence);
      c4 += `component ${comp.symbol.toLowerCase()} "${comp.symbol}" {\n`;
      if (tag) c4 += `  ${tag}\n`;
      c4 += `  metadata { sourceLocation "${comp.file}#${comp.symbol}" }\n`;
      c4 += `}\n\n`;
    }

    // Contracts
    for (const contract of elements.contracts) {
      const tag = confidenceToTag(contract.confidence);
      c4 += `contract ${contract.symbol.toLowerCase()} "${contract.symbol}" {\n`;
      if (tag) c4 += `  ${tag}\n`;
      c4 += `  metadata { sourceLocation "${contract.file}#${contract.symbol}" }\n`;
      c4 += `}\n\n`;
    }
  }

  // Edges (relationships)
  c4 += '// ── Code-Level Edges (relationships) ───────────────────\n\n';
  for (const edge of extraction.edges || []) {
    const tag = confidenceToTag(edge.confidence);
    c4 += `// ${edge.from} -> ${edge.to} [${edge.kind}] ${tag}\n`;
    if (edge.evidence) {
      c4 += `// Evidence: ${edge.evidence}\n`;
    }
    c4 += `// (edge definition would reference component/contract ids)\n\n`;
  }

  return c4;
}

function main() {
  const file = process.argv[2];
  if (!file) {
    console.error('Usage: node pass4-converter.mjs <union-json>');
    process.exit(1);
  }

  try {
    const extraction = loadJson(file);

    console.log('// ============================================================');
    console.log('// Pass 4 Output: Code-Level Elements with Confidence Tags');
    console.log('// ============================================================\n');

    const c4 = generateC4(extraction);
    console.log(c4);

    // Summary stats
    console.log('// ── Extraction Summary ─────────────────────────────────');
    console.log(`// Total components: ${extraction.components?.length || 0}`);
    console.log(`// Total contracts: ${extraction.contracts?.length || 0}`);
    console.log(`// Total edges: ${extraction.edges?.length || 0}`);

    const provable = (extraction.components || []).filter((c) => c.confidence === 'PROVABLE').length;
    const inferred = (extraction.components || []).filter((c) => c.confidence === 'INFERRED').length;
    console.log(`// Components: ${provable} #provable, ${inferred} #inferred`);
  } catch (error) {
    console.error('Conversion failed:', error.message);
    process.exit(1);
  }
}

main();
