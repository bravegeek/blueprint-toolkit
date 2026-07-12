#!/usr/bin/env node

/**
 * Union multiple extraction JSONs and verify disjoint-set property
 *
 * Usage: node union-extraction.mjs <tsserver-json> <recipe-json>
 */

import * as fs from 'fs';

function loadJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function unionExtractions(extractionJsons) {
  const result = {
    source: 'union',
    language: 'typescript',
    components: [],
    contracts: [],
    edges: [],
  };

  const seenComponents = new Set();
  const seenContracts = new Set();
  const seenEdges = new Set();
  const overlappingEdges = [];

  for (const extraction of extractionJsons) {
    // Merge components
    for (const comp of extraction.components || []) {
      const key = `${comp.symbol}@${comp.file}`;
      if (!seenComponents.has(key)) {
        seenComponents.add(key);
        result.components.push(comp);
      }
    }

    // Merge contracts
    for (const contract of extraction.contracts || []) {
      const key = `${contract.symbol}@${contract.file}`;
      if (!seenContracts.has(key)) {
        seenContracts.add(key);
        result.contracts.push(contract);
      }
    }

    // Merge edges and check for disjointness
    for (const edge of extraction.edges || []) {
      const key = `${edge.from}-${edge.to}-${edge.kind}`;
      if (seenEdges.has(key)) {
        overlappingEdges.push({
          edge,
          source: extraction.source,
        });
      } else {
        seenEdges.add(key);
        result.edges.push(edge);
      }
    }
  }

  return { result, overlappingEdges };
}

function main() {
  const files = process.argv.slice(2);
  if (files.length < 1) {
    console.error('Usage: node union-extraction.mjs <extraction1.json> [extraction2.json ...]');
    process.exit(1);
  }

  try {
    const extractions = files.map((file) => loadJson(file));
    const { result, overlappingEdges } = unionExtractions(extractions);

    if (overlappingEdges.length > 0) {
      console.error('Warning: Disjoint-set violation detected:');
      for (const { edge, source } of overlappingEdges) {
        console.error(`  ${source}: ${edge.from} -> ${edge.to} (${edge.kind})`);
      }
    }

    // Write JSON only to stdout
    process.stdout.write(JSON.stringify(result, null, 2) + '\n');
  } catch (error) {
    console.error('Union failed:', error.message);
    process.exit(1);
  }
}

main();
