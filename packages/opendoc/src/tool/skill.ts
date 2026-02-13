import path from "path"
import z from "zod"
import { Tool } from "./tool"
import { Skill } from "../skill"
import { ConfigMarkdown } from "../config/markdown"
import { PermissionNext } from "../permission/next"

const parameters = z.object({
  name: z.string().describe("The skill identifier from available_skills (e.g., 'code-review' or 'category/helper')"),
})

export const SkillTool = Tool.define("skill", async (ctx) => {
  const filesystemSkills = await Skill.all()
  const apiSkills = ctx?.apiSkills ?? []

  // Build merged skill list: API skills override filesystem skills by name
  const allSkills = new Map<string, { name: string; description: string; source: "filesystem" | "api"; location?: string; content?: string }>()
  for (const s of filesystemSkills) {
    allSkills.set(s.name, { name: s.name, description: s.description, source: "filesystem", location: s.location })
  }
  for (const s of apiSkills) {
    allSkills.set(s.name, { name: s.name, description: s.description, source: "api", content: s.content })
  }

  // Filter skills by agent permissions if agent provided
  const agent = ctx?.agent
  const accessibleSkills = agent
    ? [...allSkills.values()].filter((skill) => {
        const rule = PermissionNext.evaluate("skill", skill.name, agent.permission)
        return rule.action !== "deny"
      })
    : [...allSkills.values()]

  const description =
    accessibleSkills.length === 0
      ? "Load a skill to get detailed instructions for a specific task. No skills are currently available."
      : [
          "IMPORTANT: You MUST call this tool BEFORE responding whenever a user's request matches an available skill.",
          "Skills provide specialized instructions for specific tasks.",
          "Check the list below and invoke matching skills proactively — do not wait to be asked.",
          "<available_skills>",
          ...accessibleSkills.flatMap((skill) => [
            `  <skill>`,
            `    <name>${skill.name}</name>`,
            `    <description>${skill.description}</description>`,
            `  </skill>`,
          ]),
          "</available_skills>",
        ].join(" ")

  return {
    description,
    parameters,
    async execute(params: z.infer<typeof parameters>, ctx) {
      // Check API skills first
      const apiSkill = apiSkills.find((s) => s.name === params.name)
      if (apiSkill) {
        await ctx.ask({
          permission: "skill",
          patterns: [params.name],
          always: [params.name],
          metadata: {},
        })

        const output = [`## Skill: ${apiSkill.name}`, "", apiSkill.content.trim()].join("\n")

        return {
          title: `Loaded skill: ${apiSkill.name}`,
          output,
          metadata: {
            name: apiSkill.name,
          },
        }
      }

      // Fall back to filesystem skill
      const skill = await Skill.get(params.name)

      if (!skill) {
        const available = [...allSkills.keys()].join(", ")
        throw new Error(`Skill "${params.name}" not found. Available skills: ${available || "none"}`)
      }

      await ctx.ask({
        permission: "skill",
        patterns: [params.name],
        always: [params.name],
        metadata: {},
      })
      // Load and parse skill content
      const parsed = await ConfigMarkdown.parse(skill.location)
      const dir = path.dirname(skill.location)

      // Format output similar to plugin pattern
      const output = [`## Skill: ${skill.name}`, "", `**Base directory**: ${dir}`, "", parsed.content.trim()].join("\n")

      return {
        title: `Loaded skill: ${skill.name}`,
        output,
        metadata: {
          name: skill.name,
        },
      }
    },
  }
})
