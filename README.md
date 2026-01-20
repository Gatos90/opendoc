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

## License

MIT
