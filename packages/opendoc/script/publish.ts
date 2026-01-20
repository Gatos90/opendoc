#!/usr/bin/env bun
import { $ } from "bun"
import pkg from "../package.json"
import { Script } from "@opendoc-ai/script"
import { fileURLToPath } from "url"

const dir = fileURLToPath(new URL("..", import.meta.url))
process.chdir(dir)

const { binaries } = await import("./build.ts")
{
  const name = `${pkg.name}-${process.platform}-${process.arch}`
  console.log(`smoke test: running dist/${name}/bin/opendoc --version`)
  await $`./dist/${name}/bin/opendoc --version`
}

await $`mkdir -p ./dist/${pkg.name}`
await $`cp -r ./bin ./dist/${pkg.name}/bin`
await $`cp ./script/postinstall.mjs ./dist/${pkg.name}/postinstall.mjs`

await Bun.file(`./dist/${pkg.name}/package.json`).write(
  JSON.stringify(
    {
      name: pkg.name + "-ai",
      bin: {
        [pkg.name]: `./bin/${pkg.name}`,
      },
      scripts: {
        postinstall: "bun ./postinstall.mjs || node ./postinstall.mjs",
      },
      version: Script.version,
      optionalDependencies: binaries,
    },
    null,
    2,
  ),
)

const tags = [Script.channel]

// Set npm auth token from environment
const npmToken = process.env.NPM_TOKEN
if (!npmToken) {
  console.error("Error: NPM_TOKEN environment variable is required")
  process.exit(1)
}

// Write .npmrc to each dist directory to avoid workspace issues
const npmrcContent = `//registry.npmjs.org/:_authToken=${npmToken}\n`

const tasks = Object.entries(binaries).map(async ([name]) => {
  if (process.platform !== "win32") {
    await $`chmod -R 755 .`.cwd(`./dist/${name}`)
  }
  await Bun.file(`./dist/${name}/.npmrc`).write(npmrcContent)
  await $`bun pm pack`.cwd(`./dist/${name}`)
  for (const tag of tags) {
    try {
      await $`npm publish *.tgz --access public --tag ${tag}`.cwd(`./dist/${name}`)
    } catch (e) {
      console.error(`Failed to publish ${name} with tag ${tag}:`, e instanceof Error ? e.message : e)
    }
  }
})
await Promise.all(tasks)

// Write .npmrc to main package directory
await Bun.file(`./dist/${pkg.name}/.npmrc`).write(npmrcContent)
for (const tag of tags) {
  try {
    await $`cd ./dist/${pkg.name} && bun pm pack && npm publish *.tgz --access public --tag ${tag}`
  } catch (e) {
    console.error(`Failed to publish ${pkg.name} with tag ${tag}:`, e instanceof Error ? e.message : e)
  }
}

if (!Script.preview) {
  // Create archives for GitHub release
  for (const key of Object.keys(binaries)) {
    if (key.includes("linux")) {
      await $`tar -czf ../../${key}.tar.gz *`.cwd(`dist/${key}/bin`)
    } else {
      await $`zip -r ../../${key}.zip *`.cwd(`dist/${key}/bin`)
    }
  }
}
