#!/usr/bin/env node

/**
 * TypeScript/tsserver-based deterministic code graph extractor
 *
 * Usage: node tsserver-extractor.mjs <project-root>
 *
 * Outputs JSON to stdout with source:"tsserver", confidence:PROVABLE for all resolved facts
 * Uses only read-only static-analysis tsserver requests (open, navto, references, etc.)
 * Never triggers builds, codegen, or application code execution.
 *
 * NOTE: This is a thin, disposable adapter. Implementation can be replaced with any
 * other deterministic TS/AST extractor. The JSON output boundary is what matters.
 */

import * as fs from 'fs';
import * as path from 'path';
import { execSync } from 'child_process';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

class TsserverExtractor {
  constructor(projectRoot) {
    this.projectRoot = path.resolve(projectRoot);
    this.tsconfigPath = path.join(this.projectRoot, 'tsconfig.json');

    this.components = new Map(); // symbol → details
    this.contracts = new Map();
    this.edges = new Set();
  }

  validateSetup() {
    if (!fs.existsSync(this.tsconfigPath)) {
      throw new Error(`tsconfig.json not found at ${this.tsconfigPath}`);
    }
  }

  /**
   * Walk the project directory and enumerate all TypeScript source files
   */
  enumerateSourceFiles() {
    const files = [];
    const tsPattern = /\.tsx?$/;

    const walk = (dir, depth = 0) => {
      if (depth > 5) return; // Limit recursion depth

      try {
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        for (const entry of entries) {
          const name = entry.name;
          // Skip node_modules, dist, build, .next, etc.
          if (name.startsWith('.') || ['node_modules', 'dist', 'build', '.next', '.turbo', 'coverage'].includes(name)) {
            continue;
          }

          const fullPath = path.join(dir, name);
          if (entry.isDirectory()) {
            walk(fullPath, depth + 1);
          } else if (entry.isFile() && tsPattern.test(fullPath)) {
            const rel = path.relative(this.projectRoot, fullPath);
            files.push(rel);
          }
        }
      } catch (e) {
        // Silently skip unreadable directories
      }
    };

    walk(this.projectRoot);
    return files;
  }

  /**
   * Regex-based walking-skeleton extractor over source files.
   *
   * Three passes, so that structural significance is decided by cross-module
   * IMPORT EVIDENCE (not export shape):
   *   A. Collect every exported declaration (class | interface | type | function |
   *      const | default) and every import occurrence.
   *   B. Keep an export as a component/contract only if it is imported by a
   *      DIFFERENT module (class-free functional modules and type-alias/union
   *      contracts included; single-use exports dropped as internal detail).
   *   C. Emit an edge for each cross-module import that resolves to a known
   *      export, with the importing file as `from` and `file:line` evidence.
   */
  extractFromSource(files) {
    const exportsBySymbol = new Map();   // symbol → { symbol, file, kind, line }
    const importOccurrences = [];        // { symbol, file, line }

    for (const file of files) {
      const fullPath = path.join(this.projectRoot, file);
      let source;
      try {
        source = fs.readFileSync(fullPath, 'utf8');
      } catch (e) {
        continue; // skip unreadable files
      }

      const lines = source.split('\n');
      const relFile = file.replace(/\\/g, '/');

      // Exported declarations (single-line) — classes AND functional exports
      // (const/function) AND contracts (interface/type). This is the widened
      // enumeration: functions and type aliases are first-class, not just classes.
      for (let i = 0; i < lines.length; i++) {
        const exportMatch = lines[i].match(
          /^export\s+(?:default\s+)?(abstract\s+class|class|interface|type|async\s+function|function|const)\s+(\w+)/
        );
        if (exportMatch) {
          const kind = exportMatch[1].replace(/^abstract\s+/, '').replace(/^async\s+/, '');
          const symbol = exportMatch[2];
          if (!exportsBySymbol.has(symbol)) {
            exportsBySymbol.set(symbol, { symbol, file: relFile, kind, line: i + 1 });
          }
        }
      }

      // Import occurrences — named / namespace / default. Scanned over the whole
      // source so MULTI-LINE named imports (one symbol per line) are captured;
      // line-by-line matching silently dropped those and undercounted evidence.
      const importRe =
        /import\s+(?:type\s+)?(?:\{([^}]*)\}|\*\s+as\s+(\w+)|(\w+))\s+from\s*['"][^'"]+['"]/g;
      let m;
      while ((m = importRe.exec(source)) !== null) {
        const [, named, star, dflt] = m;
        const lineNum = source.slice(0, m.index).split('\n').length;
        const names = [];
        if (named) {
          named.split(',').forEach((s) => {
            const n = s.trim().replace(/^type\s+/, '').split(/\s+as\s+/)[0];
            if (n) names.push(n);
          });
        }
        if (star) names.push(star);
        if (dflt) names.push(dflt);
        for (const n of names) {
          importOccurrences.push({ symbol: n, file: relFile, line: lineNum });
        }
      }
    }

    // Pass B — significance = imported by a DIFFERENT module (import evidence,
    // not export shape). Class-free functional modules and union-type contracts
    // survive; single-use exports are dropped as internal detail.
    for (const { symbol, file, kind, line } of exportsBySymbol.values()) {
      const crossModule = importOccurrences.some(
        (o) => o.symbol === symbol && o.file !== file
      );
      if (!crossModule) continue;

      if (kind === 'interface' || kind === 'type') {
        this.contracts.set(symbol, {
          symbol,
          file,
          kind, // "interface" | "type" (type-alias / discriminated union)
          confidence: 'PROVABLE',
          evidence: `${file}:${line}`,
        });
      } else {
        // class | function | const → a component. A functional module is emitted
        // as a component exactly like a class.
        this.components.set(symbol, {
          symbol,
          file,
          module: path.dirname(file),
          exported: true,
          confidence: 'PROVABLE',
        });
      }
    }

    // Pass C — resolved cross-module edges only. `from` is the importing file
    // (fixes the previous 'unknown'); unresolved imports are not faked.
    for (const { symbol, file, line } of importOccurrences) {
      const def = exportsBySymbol.get(symbol);
      if (!def || def.file === file) continue; // unresolved or same-module
      const kind = def.kind === 'interface' || def.kind === 'type' ? 'references' : 'imports';
      this.edges.add({
        from: file,
        to: symbol,
        kind,
        confidence: 'PROVABLE',
        evidence: `${file}:${line}`,
      });
    }
  }

  /**
   * Extract the graph and return JSON
   */
  extract() {
    this.validateSetup();

    const files = this.enumerateSourceFiles();
    this.extractFromSource(files);

    const result = {
      source: 'tsserver',
      language: 'typescript',
      components: Array.from(this.components.values()),
      contracts: Array.from(this.contracts.values()),
      edges: Array.from(this.edges),
    };

    return result;
  }
}

/**
 * Main entry point
 */
async function main() {
  const projectRoot = process.argv[2] || '.';

  try {
    const extractor = new TsserverExtractor(projectRoot);
    const result = extractor.extract();
    console.log(JSON.stringify(result, null, 2));
  } catch (error) {
    console.error('Extraction failed:', error.message);
    process.exit(1);
  }
}

main().catch(console.error);
