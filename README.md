# OpenDoc

OpenDoc is a modified version of [OpenCode](https://github.com/opencode-ai/opencode) designed to act as a Documentation Agent. It provides a server-based API for interacting with AI to answer questions about documentation, websites, and knowledge bases.

## Key Differences from OpenCode

OpenDoc differs from OpenCode in several important ways:

### Documentation-Optimized Prompts

Unlike OpenCode's coding-focused prompts, OpenDoc's prompts are optimized for documentation tasks:

- **Source citation**: Answers always include references with document titles and URLs
- **User-friendly output**: References documents by title, not internal file paths
- **Truth-first approach**: Only reports information found in documentation, never fabricates
- **Cross-referencing**: Combines information from multiple sources when answering

### Real-Time Session Updates

Sessions can be updated with each message sent to the AI, enabling live modifications while chatting:

- **Delta-based streaming**: Only incremental changes are transmitted, not full message content
- **Granular updates**: Three-level hierarchy (Session → Message → Parts) allows fine-grained updates
- **Event-driven architecture**: All updates publish bus events for reactive UI updates
- **Live compaction**: Context can be optimized mid-conversation without losing state

### SSE Event Streaming

Session updates are fully supported via Server-Sent Events:

- **Permission sync**: Permissions are sent with every prompt request, keeping the session's permission rules always up to date

## Prerequisites

- **Bun** 1.3.5 or later
- **Node.js** 22+ (for type definitions)
- **Git**

## Installation

```bash
bun install
```

## Build Commands

```bash
# Build platform-specific binaries
bun run build

# Run in development mode
bun run dev

# Type check all packages
bun run typecheck
```

## Running the Server

Start the server in development mode:

```bash
bun run dev serve
```

Or if you have OpenDoc installed globally:

```bash
opendoc serve
```

The server will start and display the port it's listening on.

## API Documentation

### Interactive Documentation

- **Swagger UI**: Available at `/swagger` when the server is running
- **OpenAPI Spec**: Available at `/doc` endpoint (JSON format)

### Offline Documentation

The OpenAPI specification is also available at [`packages/sdk/openapi.json`](packages/sdk/openapi.json) for offline viewing or importing into external API tools.

## Environment Variables

### Server Authentication

- `OPENDOC_SERVER_USERNAME` - Username for basic authentication
- `OPENDOC_SERVER_PASSWORD` - Password for basic authentication

### Provider API Keys

Configure the appropriate API key for your chosen AI provider:

- `ANTHROPIC_API_KEY` - Anthropic (Claude)
- `OPENAI_API_KEY` - OpenAI
- `GOOGLE_GENERATIVE_AI_API_KEY` - Google AI
- `MISTRAL_API_KEY` - Mistral AI
- `GROQ_API_KEY` - Groq
- `XAI_API_KEY` - xAI
- `COHERE_API_KEY` - Cohere
- `PERPLEXITY_API_KEY` - Perplexity
- `TOGETHER_AI_API_KEY` - Together AI
- `DEEPINFRA_API_KEY` - DeepInfra
- `CEREBRAS_API_KEY` - Cerebras
- `OPENROUTER_API_KEY` - OpenRouter

### Azure Anthropic (Claude via Azure AI Foundry)

For running Claude models through Azure AI Foundry (Docker deployment):

- `AZURE_ANTHROPIC_API_KEY` - API key from Azure AI Foundry
- `AZURE_ANTHROPIC_API_ENDPOINT` - Endpoint URL (e.g. `https://your-resource.services.ai.azure.com/anthropic/v1`)
- `AZURE_ANTHROPIC_MODEL_ID` - Model ID (default: `claude-opus-4-6`)

### Azure OpenAI

For running OpenAI models through Azure:

- `AZURE_OPENAI_API_KEY` - Azure OpenAI API key
- `AZURE_OPENAI_API_ENDPOINT` - Azure OpenAI endpoint URL
- `AZURE_RESOURCE_NAME` - Azure resource name
- `AZURE_MODEL_ID` - Model deployment ID (default: `gpt-5.2-chat`)

See the [Azure Setup Guide](.opendoc/command/setup-azure.md) for detailed instructions.

### Secure Environment Injection

- `OPENDOC_ENV_SECRET` - 32-byte hex key (64 chars) for AES-256-GCM encryption of per-message environment variables. When set, the `environment` field in prompt requests must be encrypted. When unset, plain JSON objects are accepted (dev mode).

## Docker Image Variants

OpenDoc provides three Docker image variants, all built for `linux/amd64` and `linux/arm64`:

| Image | Tag | Size | Includes |
|-------|-----|------|----------|
| **Base** | `gatso/opendoc:1.0.9` | ~250 MB | OpenDoc server, ripgrep |
| **Browser** | `gatso/opendoc:1.0.9-browser` | ~600 MB | + [agent-browser](https://github.com/vercel-labs/agent-browser), Chromium |
| **Playwright** | `gatso/opendoc:1.0.9-playwright` | ~600 MB | + [playwright-cli](https://github.com/microsoft/playwright-cli), Chromium |

---

### Base (`gatso/opendoc:1.0.9`)

The standard image with the OpenDoc server only. Lightweight and suitable for most deployments where the AI does not need to browse the web.

```bash
docker pull gatso/opendoc:1.0.9
```

**Use this when:** You only need document Q&A (file-based and URL-based sources) without live web browsing.

---

### Browser (`gatso/opendoc:1.0.9-browser`)

Includes [agent-browser](https://github.com/vercel-labs/agent-browser) and a bundled Chromium installation. Agent-browser provides a persistent headless browser daemon that the AI can control via custom tools to navigate websites, take screenshots, click elements, and extract content.

```bash
docker pull gatso/opendoc:1.0.9-browser
```

**Use this when:** You want full browser automation with persistent sessions, screenshots, and interactive page manipulation.

**Key features:**
- Persistent browser daemon — sessions survive across tool calls
- Element targeting via `@e1`, `@e2` refs (AI-friendly identifiers)
- Screenshot support for visual page inspection
- Session isolation per chat via `--session` flag

**Docker Compose example:**

```yaml
opendoc:
  image: gatso/opendoc:1.0.9-browser
  shm_size: '512mb'  # Required for Chromium
  volumes:
    - opendoc_data:/data/opendoc
    - ./managed_docs:/docs/managed:ro
  environment:
    - AZURE_ANTHROPIC_API_KEY=${AZURE_ANTHROPIC_API_KEY}
    - AZURE_ANTHROPIC_API_ENDPOINT=${AZURE_ANTHROPIC_API_ENDPOINT}
```

**How to use:** Create a custom tool in the admin UI that calls `agent-browser` via shell exec. The tool code runs inside the container where the binary is available at global scope. Example tool code:

```javascript
const { execSync } = await import('child_process');
const session = context.sessionID;
const result = execSync(
  `agent-browser --session ${session} ${args.action} ${args.value || ''}`,
  { encoding: 'utf-8', timeout: 30000 }
);
return result;
```

---

### Playwright (`gatso/opendoc:1.0.9-playwright`)

Includes [playwright-cli](https://github.com/microsoft/playwright-cli) and a bundled Chromium installation. Playwright-cli is Microsoft's token-efficient CLI wrapper around Playwright, designed specifically for AI agents. It returns structured, compressed output optimized to minimize token usage.

```bash
docker pull gatso/opendoc:1.0.9-playwright
```

**Use this when:** You want token-efficient web browsing with structured output, ideal for AI agents that need to browse many pages without consuming excessive tokens.

**Key features:**
- Token-efficient output — structured responses designed for LLM consumption
- Element targeting via `e1`, `e2` refs (no `@` prefix)
- 60+ browser commands (navigate, click, fill, screenshot, pdf, network intercept, etc.)
- Session isolation per chat via `-s=NAME` flag
- Supports tabs, iframes, dialogs, file uploads, console logs, network monitoring

**Docker Compose example:**

```yaml
opendoc:
  image: gatso/opendoc:1.0.9-playwright
  shm_size: '512mb'  # Required for Chromium
  volumes:
    - opendoc_data:/data/opendoc
    - ./managed_docs:/docs/managed:ro
  environment:
    - AZURE_ANTHROPIC_API_KEY=${AZURE_ANTHROPIC_API_KEY}
    - AZURE_ANTHROPIC_API_ENDPOINT=${AZURE_ANTHROPIC_API_ENDPOINT}
```

**How to use:** Create a custom tool in the admin UI that calls `playwright-cli` via shell exec. Example tool code:

```javascript
const { execSync } = await import('child_process');
const session = context.sessionID;
const result = execSync(
  `npx @playwright/cli -s=${session} ${args.action} ${args.value || ''}`,
  { encoding: 'utf-8', timeout: 30000 }
);
return result;
```

**Available playwright-cli commands:**

| Category | Commands |
|----------|----------|
| Navigation | `navigate`, `go_back`, `go_forward`, `wait` |
| Interaction | `click`, `hover`, `type`, `select_option`, `check`, `uncheck` |
| Keyboard | `press_key`, `hold_key` |
| Content | `snapshot`, `screenshot`, `pdf_save` |
| Tabs | `tab_new`, `tab_select`, `tab_close`, `tab_list` |
| Dialogs | `dialog_handle` |
| Files | `file_upload` |
| Utilities | `console_logs`, `network_logs`, `network_intercept`, `network_continue` |

---

### Choosing between Browser and Playwright

| Feature | Browser (`-browser`) | Playwright (`-playwright`) |
|---------|---------------------|---------------------------|
| Token efficiency | Standard output | Optimized for LLMs |
| Element refs | `@e1`, `@e2` | `e1`, `e2` |
| Session flag | `--session NAME` | `-s=NAME` |
| Screenshot | Yes | Yes |
| PDF export | No | Yes |
| Network monitoring | No | Yes |
| Tab management | No | Yes |
| Best for | Simple browsing tasks | Complex multi-page workflows |

---

### Important notes for browser variants

- **Shared memory**: Both browser variants require `shm_size: '512mb'` (or higher) in Docker Compose. Chromium uses `/dev/shm` for rendering, and the default 64MB is insufficient.
- **Security**: Drop all capabilities and use `no-new-privileges` for production:
  ```yaml
  security_opt:
    - no-new-privileges:true
  cap_drop:
    - ALL
  ```
- **Custom tool variables**: When creating browser tools, the following variables are automatically injected by the backend:
  - `ALLOWED_URLS` — array of URLs the user is permitted to access
  - `USER_ROLES`, `USER_ID`, `USER_EMAIL`, `USER_NAME`, `USER_METADATA` — user context
  - Use `ALLOWED_URLS` to enforce URL restrictions in your tool code

---

### Building all variants

```bash
# Base image
docker buildx build --platform linux/amd64,linux/arm64 \
  -t gatso/opendoc:1.0.9 --push .

# agent-browser image
docker buildx build --platform linux/amd64,linux/arm64 \
  --build-arg WITH_BROWSER=true \
  -t gatso/opendoc:1.0.9-browser --push .

# playwright-cli image
docker buildx build --platform linux/amd64,linux/arm64 \
  --build-arg WITH_PLAYWRIGHT=true \
  -t gatso/opendoc:1.0.9-playwright --push .
```

## License

MIT
