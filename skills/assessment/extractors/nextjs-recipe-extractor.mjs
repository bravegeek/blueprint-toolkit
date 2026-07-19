#!/usr/bin/env node

/**
 * Next.js framework-implicit wiring extractor
 *
 * Usage: node nextjs-recipe-extractor.mjs <project-root>
 *
 * Outputs JSON to stdout with source:"llm-nextjs", confidence:INFERRED
 * Extracts framework-implicit edges the type system cannot resolve:
 * - File-system routes (app directory structure page.tsx)
 * - Route handlers (app directory structure route.ts)
 * - Client to API fetch edges
 * - use client boundaries
 * - next-auth wiring
 */

import * as fs from 'fs';
import * as path from 'path';

class NextjsRecipeExtractor {
  constructor(projectRoot) {
    this.projectRoot = path.resolve(projectRoot);
    this.appDir = path.join(this.projectRoot, 'app');

    this.components = new Map(); // route/handler → details
    this.edges = new Map(); // unique key → edge details
  }

  /**
   * Check if this is a Next.js project
   */
  isNextjsProject() {
    const packageJsonPath = path.join(this.projectRoot, 'package.json');
    if (!fs.existsSync(packageJsonPath)) return false;

    const pkg = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
    return !!(pkg.dependencies?.next || pkg.devDependencies?.next);
  }

  /**
   * Extract file-system routes: app directory tree page.tsx files to route paths
   */
  extractRoutes() {
    if (!fs.existsSync(this.appDir)) return;

    const walk = (dir, routePath = '') => {
      try {
        const entries = fs.readdirSync(dir, { withFileTypes: true });

        for (const entry of entries) {
          if (entry.name.startsWith('_') || entry.name.startsWith('.')) continue;

          const fullPath = path.join(dir, entry.name);
          const relPath = path.relative(this.appDir, fullPath);

          if (entry.isDirectory()) {
            // Construct route path from directory structure
            let nextRoutePath = routePath;
            if (entry.name.startsWith('[') && entry.name.endsWith(']')) {
              // Dynamic segment: [id] → :id
              const paramName = entry.name.slice(1, -1);
              nextRoutePath += `/:${paramName}`;
            } else {
              nextRoutePath += `/${entry.name}`;
            }

            walk(fullPath, nextRoutePath);

            // Check for page.tsx in this directory
            const pageFile = path.join(fullPath, 'page.tsx');
            if (fs.existsSync(pageFile)) {
              const routeSymbol = nextRoutePath || '/';
              this.components.set(`route:${nextRoutePath}`, {
                symbol: `GET ${routeSymbol}`,
                file: path.relative(this.projectRoot, pageFile).replace(/\\/g, '/'),
                kind: 'route',
                confidence: 'INFERRED',
              });
            }
          }
        }
      } catch (e) {
        // Silently skip unreadable directories
      }
    };

    walk(this.appDir);
  }

  /**
   * Extract route handlers: app directory tree route.ts files to HTTP endpoints
   */
  extractHandlers() {
    if (!fs.existsSync(this.appDir)) return;

    const walk = (dir) => {
      try {
        const entries = fs.readdirSync(dir, { withFileTypes: true });

        for (const entry of entries) {
          if (entry.name.startsWith('_') || entry.name.startsWith('.')) continue;

          const fullPath = path.join(dir, entry.name);

          if (entry.isDirectory()) {
            walk(fullPath);
          } else if (entry.name === 'route.ts') {
            const relPath = path.relative(this.appDir, dir).replace(/\\/g, '/') || '/';
            const source = fs.readFileSync(fullPath, 'utf8');

            // Extract HTTP methods defined in the route
            const methods = [];
            if (/export\s+(?:async\s+)?function\s+GET/.test(source)) methods.push('GET');
            if (/export\s+(?:async\s+)?function\s+POST/.test(source)) methods.push('POST');
            if (/export\s+(?:async\s+)?function\s+PUT/.test(source)) methods.push('PUT');
            if (/export\s+(?:async\s+)?function\s+DELETE/.test(source)) methods.push('DELETE');
            if (/export\s+(?:async\s+)?function\s+PATCH/.test(source)) methods.push('PATCH');

            for (const method of methods) {
              const routePath = relPath === '/' ? '/' : relPath;
              this.components.set(`handler:${method}:${routePath}`, {
                symbol: `${method} ${routePath}`,
                file: path.relative(this.projectRoot, fullPath).replace(/\\/g, '/'),
                kind: 'handler',
                confidence: 'INFERRED',
              });
            }
          }
        }
      } catch (e) {
        // Silently skip unreadable directories
      }
    };

    walk(this.appDir);
  }

  /**
   * Extract client→API edges: fetch calls to handlers
   */
  extractClientApiEdges() {
    const components = path.join(this.projectRoot, 'components');
    if (!fs.existsSync(components)) return;

    const walk = (dir) => {
      try {
        const entries = fs.readdirSync(dir, { withFileTypes: true });

        for (const entry of entries) {
          if (entry.name.startsWith('.')) continue;

          const fullPath = path.join(dir, entry.name);
          const relPath = path.relative(this.projectRoot, fullPath).replace(/\\/g, '/');

          if (entry.isDirectory()) {
            walk(fullPath);
          } else if (entry.isFile() && /\.(tsx?|jsx)$/.test(entry.name)) {
            const source = fs.readFileSync(fullPath, 'utf8');

            // Look for fetch calls
            const fetchMatches = source.matchAll(/fetch\(['"]([^'"]+)['"]/g);
            for (const match of fetchMatches) {
              const url = match[1];

              // Try to match against known handlers
              if (url.startsWith('/api/')) {
                const routePath = url.split('?')[0]; // Remove query params
                const method = this.inferMethodFromContext(source, match.index) || 'POST';
                const handlerKey = `handler:${method}:${routePath}`;

                if (this.components.has(handlerKey)) {
                  const componentName = this.extractComponentName(source, match.index);
                  const edgeKey = `${componentName}→${method}:${routePath}`;

                  this.edges.set(edgeKey, {
                    from: componentName || path.basename(relPath, path.extname(relPath)),
                    to: `${method} ${routePath}`,
                    kind: 'fetches',
                    confidence: 'INFERRED',
                  });
                }
              }
            }
          }
        }
      } catch (e) {
        // Silently skip unreadable directories
      }
    };

    walk(components);
  }

  /**
   * Infer HTTP method from fetch context
   */
  inferMethodFromContext(source, index) {
    const before = source.substring(Math.max(0, index - 200), index);
    if (/method:\s*['"]POST['"]/.test(before)) return 'POST';
    if (/method:\s*['"]PUT['"]/.test(before)) return 'PUT';
    if (/method:\s*['"]DELETE['"]/.test(before)) return 'DELETE';
    if (/method:\s*['"]PATCH['"]/.test(before)) return 'PATCH';
    return 'GET';
  }

  /**
   * Extract component name from source around fetch call
   */
  extractComponentName(source, index) {
    const before = source.substring(Math.max(0, index - 500), index);
    const funcMatch = before.match(/^(?:export\s+)?(?:async\s+)?function\s+(\w+)/m);
    if (funcMatch) return funcMatch[1];

    const compMatch = before.match(/^export\s+function\s+(\w+)/m);
    if (compMatch) return compMatch[1];

    return null;
  }

  /**
   * Extract 'use client' boundaries
   */
  extractUseClientBoundaries() {
    // Simplified: mark components in files with 'use client' directive as client-side
    // Full implementation would track which modules cross the boundary
    // For now, just document the pattern in edges
    // Deferred to full implementation during validation
  }

  /**
   * Extract next-auth wiring
   */
  extractAuthWiring() {
    const authPath = path.join(this.appDir, 'api', 'auth');
    if (!fs.existsSync(authPath)) return;

    const walk = (dir) => {
      try {
        const entries = fs.readdirSync(dir, { withFileTypes: true });

        for (const entry of entries) {
          if (entry.name === '[...nextauth]') {
            const routePath = path.join(dir, entry.name, 'route.ts');
            if (fs.existsSync(routePath)) {
              const relPath = path.relative(this.projectRoot, routePath).replace(/\\/g, '/');
              this.components.set('auth:nextauth', {
                symbol: 'NextAuth Handler',
                file: relPath,
                kind: 'auth-handler',
                confidence: 'INFERRED',
              });
            }
          }
        }
      } catch (e) {}
    };

    walk(authPath);
  }

  /**
   * Extract the recipe and return JSON
   */
  extract() {
    if (!this.isNextjsProject()) {
      return {
        source: 'llm-nextjs',
        language: 'typescript',
        components: [],
        contracts: [],
        edges: [],
      };
    }

    this.extractRoutes();
    this.extractHandlers();
    this.extractClientApiEdges();
    this.extractUseClientBoundaries();
    this.extractAuthWiring();

    const result = {
      source: 'llm-nextjs',
      language: 'typescript',
      components: Array.from(this.components.values()),
      contracts: [],
      edges: Array.from(this.edges.values()),
    };

    return result;
  }
}

/**
 * Main entry point
 */
function main() {
  const projectRoot = process.argv[2] || '.';

  try {
    const extractor = new NextjsRecipeExtractor(projectRoot);
    const result = extractor.extract();
    console.log(JSON.stringify(result, null, 2));
  } catch (error) {
    console.error('Extraction failed:', error.message);
    process.exit(1);
  }
}

main();
