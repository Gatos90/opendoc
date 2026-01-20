#!/usr/bin/env bun

import { $ } from "bun"
import path from "path"
import { fileURLToPath } from "url"
import * as prompts from "@clack/prompts"

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const dir = path.resolve(__dirname, "..")

process.chdir(dir)

const args = process.argv.slice(2)
const dryRun = args.includes("--dry-run")
const skipRegistries = args.includes("--skip-registries")
const versionArg = args.find((arg) => !arg.startsWith("--"))

async function getVersionBump(): Promise<{ bump?: string; version?: string }> {
  if (versionArg) {
    // Check if it's a semver version (x.y.z)
    if (/^\d+\.\d+\.\d+/.test(versionArg)) {
      return { version: versionArg }
    }
    // Check if it's a bump type
    if (["major", "minor", "patch"].includes(versionArg)) {
      return { bump: versionArg }
    }
    console.error(`Invalid version argument: ${versionArg}`)
    console.error("Expected: major, minor, patch, or a semver version (e.g., 1.2.3)")
    process.exit(1)
  }

  // Prompt for version bump type
  const result = await prompts.select({
    message: "Select version bump type",
    options: [
      { value: "patch", label: "patch", hint: "Bug fixes (1.0.0 -> 1.0.1)" },
      { value: "minor", label: "minor", hint: "New features (1.0.0 -> 1.1.0)" },
      { value: "major", label: "major", hint: "Breaking changes (1.0.0 -> 2.0.0)" },
    ],
  })

  if (prompts.isCancel(result)) {
    console.log("Release cancelled")
    process.exit(0)
  }

  return { bump: result as string }
}

async function checkPrerequisites() {
  console.log("Checking prerequisites...")

  // Check gh CLI
  try {
    await $`gh auth status`.quiet()
    console.log("  gh CLI authenticated")
  } catch {
    console.error("  gh CLI not authenticated. Run: gh auth login")
    process.exit(1)
  }

  // Check npm login
  try {
    await $`npm whoami`.quiet()
    console.log("  npm authenticated")
  } catch {
    console.error("  npm not authenticated. Run: npm login")
    process.exit(1)
  }

  // Check for clean git state
  const status = await $`git status --porcelain`.text()
  if (status.trim()) {
    console.warn("  Warning: Working directory has uncommitted changes")
  } else {
    console.log("  git working directory clean")
  }
}

async function getCurrentVersion(): Promise<string> {
  try {
    const res = await fetch("https://registry.npmjs.org/opendoc-ai/latest")
    if (!res.ok) return "0.0.0"
    const data = await res.json()
    return (data as any).version ?? "0.0.0"
  } catch {
    return "0.0.0"
  }
}

function calculateNewVersion(current: string, bump: string): string {
  const [major, minor, patch] = current.split(".").map((x) => Number(x) || 0)
  if (bump === "major") return `${major + 1}.0.0`
  if (bump === "minor") return `${major}.${minor + 1}.0`
  return `${major}.${minor}.${patch + 1}`
}

async function main() {
  console.log("opendoc release script")
  console.log("=".repeat(50))

  if (dryRun) {
    console.log("DRY RUN MODE - No actual publishing will occur\n")
  }

  await checkPrerequisites()
  console.log()

  const { bump, version: explicitVersion } = await getVersionBump()
  const currentVersion = await getCurrentVersion()

  let newVersion: string
  if (explicitVersion) {
    newVersion = explicitVersion
  } else if (bump) {
    newVersion = calculateNewVersion(currentVersion, bump)
  } else {
    console.error("No version specified")
    process.exit(1)
  }

  console.log(`\nCurrent version: ${currentVersion}`)
  console.log(`New version:     ${newVersion}`)

  if (!dryRun) {
    const confirm = await prompts.confirm({
      message: `Proceed with release v${newVersion}?`,
    })

    if (prompts.isCancel(confirm) || !confirm) {
      console.log("Release cancelled")
      process.exit(0)
    }
  }

  // Set environment variables for the build
  process.env["OPENDOC_VERSION"] = newVersion
  process.env["OPENDOC_CHANNEL"] = "latest"

  console.log("\n" + "=".repeat(50))
  console.log("Step 1: Building and publishing to npm")
  console.log("=".repeat(50) + "\n")

  if (dryRun) {
    console.log("[DRY RUN] Would run: bun run ./script/publish.ts")
    console.log("[DRY RUN] This builds all platform binaries and publishes to npm")
  } else {
    await $`bun run ./script/publish.ts`
  }

  console.log("\n" + "=".repeat(50))
  console.log("Step 2: Creating GitHub Release")
  console.log("=".repeat(50) + "\n")

  // Collect archive files
  const archiveFiles = [
    "opendoc-linux-arm64.tar.gz",
    "opendoc-linux-x64.tar.gz",
    "opendoc-linux-arm64-musl.tar.gz",
    "opendoc-linux-x64-musl.tar.gz",
    "opendoc-linux-x64-baseline.tar.gz",
    "opendoc-linux-x64-baseline-musl.tar.gz",
    "opendoc-darwin-arm64.zip",
    "opendoc-darwin-x64.zip",
    "opendoc-darwin-x64-baseline.zip",
    "opendoc-windows-x64.zip",
    "opendoc-windows-x64-baseline.zip",
  ]
    .map((f) => `./dist/${f}`)
    .filter((f) => Bun.file(f).size > 0)

  if (dryRun) {
    console.log(`[DRY RUN] Would create GitHub release v${newVersion}`)
    console.log(`[DRY RUN] Would upload ${archiveFiles.length} archive files:`)
    for (const file of archiveFiles) {
      console.log(`  - ${file}`)
    }
  } else {
    // Check which archives exist
    const existingArchives: string[] = []
    for (const file of archiveFiles) {
      try {
        const stat = await Bun.file(file).exists()
        if (stat) {
          existingArchives.push(file)
        }
      } catch {
        // File doesn't exist, skip
      }
    }

    if (existingArchives.length === 0) {
      console.error("No archive files found in dist/")
      process.exit(1)
    }

    console.log(`Uploading ${existingArchives.length} archives to GitHub Release...`)

    const releaseNotes = `Release v${newVersion}

## Installation

### npm
\`\`\`bash
npm install -g opendoc-ai
\`\`\`

### Homebrew
\`\`\`bash
brew install sst/tap/opendoc
\`\`\`

### Arch Linux (AUR)
\`\`\`bash
yay -S opendoc-bin
\`\`\`

### Direct download
Download the appropriate archive for your platform from the assets below.
`

    await $`gh release create v${newVersion} ${existingArchives} --title "v${newVersion}" --notes ${releaseNotes}`
    console.log(`GitHub Release v${newVersion} created successfully`)
  }

  if (!skipRegistries) {
    console.log("\n" + "=".repeat(50))
    console.log("Step 3: Publishing to AUR and Homebrew")
    console.log("=".repeat(50) + "\n")

    if (dryRun) {
      console.log("[DRY RUN] Would run: bun run ./script/publish-registries.ts")
    } else {
      try {
        await $`bun run ./script/publish-registries.ts`
      } catch (e) {
        console.error("Warning: Failed to publish to registries:", e)
        console.error("You may need to run this manually later")
      }
    }
  } else {
    console.log("\nSkipping AUR/Homebrew publishing (--skip-registries)")
  }

  console.log("\n" + "=".repeat(50))
  console.log("Release complete!")
  console.log("=".repeat(50))
  console.log(`\nVersion ${newVersion} has been released.`)
  console.log("\nVerify:")
  console.log(`  - npm: https://www.npmjs.com/package/opendoc-ai`)
  console.log(`  - GitHub: https://github.com/anomalyco/opendoc/releases/tag/v${newVersion}`)
}

main().catch((e) => {
  console.error("Release failed:", e)
  process.exit(1)
})
