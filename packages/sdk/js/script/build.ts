#!/usr/bin/env bun

const dir = new URL("..", import.meta.url).pathname
process.chdir(dir)

import { $ } from "bun"
import fs from "fs"
import path from "path"

import { createClient } from "@hey-api/openapi-ts"

const shouldGenerate = process.argv.includes("--generate")

if (shouldGenerate) {
  await $`bun dev generate > ${dir}/openapi.json`.cwd(path.resolve(dir, "../../opendoc"))
} else {
  // Use committed openapi.json from parent directory
  const committedPath = path.resolve(dir, "../openapi.json")
  const localPath = path.resolve(dir, "openapi.json")
  fs.copyFileSync(committedPath, localPath)
}

await createClient({
  input: "./openapi.json",
  output: {
    path: "./src/v2/gen",
    tsConfigPath: path.join(dir, "tsconfig.json"),
    clean: true,
  },
  plugins: [
    {
      name: "@hey-api/typescript",
      exportFromIndex: false,
    },
    {
      name: "@hey-api/sdk",
      instance: "OpencodeClient",
      exportFromIndex: false,
      auth: false,
      paramsStructure: "flat",
    },
    {
      name: "@hey-api/client-fetch",
      exportFromIndex: false,
      baseUrl: "http://localhost:4096",
    },
  ],
})

await $`bun prettier --write src/gen`
await $`bun prettier --write src/v2`
await $`rm -rf dist`
await $`bun tsc`
await $`rm openapi.json`
