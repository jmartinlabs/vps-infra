import { Plugin } from "@opencode/plugin"
import { spawn } from "node:child_process"
import { join } from "node:path"

type QueryInput = {
  group?: string
  operation?: string
  options?: Record<string, string | number | boolean>
}

type QueryResult = {
  code: number
  stdout: string
  stderr: string
}

function runWrapper(directory: string, args: string[]): Promise<QueryResult> {
  return new Promise((resolve) => {
    const child = spawn("python3", [join(directory, "scripts/review-read"), ...args], {
      cwd: directory,
      shell: false,
      env: { ...process.env, GIT_PAGER: "cat", GH_PAGER: "cat", NO_COLOR: "1" },
      stdio: ["ignore", "pipe", "pipe"],
    })
    let stdout = ""
    let stderr = ""
    const timer = setTimeout(() => child.kill("SIGKILL"), 35_000)
    child.stdout.setEncoding("utf8")
    child.stderr.setEncoding("utf8")
    child.stdout.on("data", (chunk: string) => { stdout += chunk })
    child.stderr.on("data", (chunk: string) => { stderr += chunk })
    child.on("error", (error) => {
      clearTimeout(timer)
      resolve({ code: 3, stdout, stderr: `UNAVAILABLE: ${error.message}` })
    })
    child.on("close", (code) => {
      clearTimeout(timer)
      resolve({ code: code ?? 4, stdout, stderr })
    })
  })
}

function buildArgs(input: QueryInput): string[] {
  const group = input.group
  if (group === "describe") {
    if (input.operation || input.options) throw new Error("describe takes no operation or options")
    return ["describe"]
  }
  if (group !== "git" && group !== "github" && group !== "file") {
    throw new Error("group must be git, github, file or describe")
  }
  if (!input.operation || !/^[a-z][a-z0-9-]*$/.test(input.operation)) {
    throw new Error("operation must be a lowercase name")
  }
  const args = [group, input.operation]
  const options = input.options ?? {}
  if (Object.keys(options).length > 6) throw new Error("too many options")
  for (const [name, value] of Object.entries(options)) {
    if (!/^[a-z][a-z0-9-]*$/.test(name)) throw new Error(`invalid option name: ${name}`)
    if (typeof value === "boolean") {
      if (!value) throw new Error(`boolean option must be true: ${name}`)
      args.push(`--${name}`)
    } else if (typeof value === "string" || typeof value === "number") {
      if (typeof value === "number" && !Number.isSafeInteger(value)) {
        throw new Error(`unsafe integer for ${name}; pass large identifiers as strings`)
      }
      args.push(`--${name}`, String(value))
    } else {
      throw new Error(`invalid option value: ${name}`)
    }
  }
  return args
}

export default Plugin.define({
  id: "review-read",
  async setup(ctx) {
    const directory = ctx.location.directory
    await ctx.tool.transform((editor) => {
      editor.namespace({
        name: "review",
        description: "Validated read-only evidence queries for code, Git, PR and CI review.",
      })
      editor.add({
        name: "query",
        description:
          "Run one validated read-only file, Git or GitHub query. No shell, writes, pushes or arbitrary commands.",
        input: {
          type: "object",
          properties: {
            group: { type: "string", enum: ["git", "github", "file", "describe"] },
            operation: { type: "string" },
            options: {
              type: "object",
              additionalProperties: { type: ["string", "number", "boolean"] },
            },
          },
          required: ["group"],
          additionalProperties: false,
        },
        options: { namespace: "review", codemode: false },
        execute: async (raw) => {
          let args: string[]
          try {
            args = buildArgs(raw as QueryInput)
          } catch (error) {
            return { content: `exit 2\nINVALID: ${(error as Error).message}` }
          }
          const result = await runWrapper(directory, args)
          if (result.code === 0) return { content: result.stdout }
          return {
            content: `exit ${result.code}\n${result.stdout}${result.stderr}`.trim(),
          }
        },
      })
    })
  },
})
