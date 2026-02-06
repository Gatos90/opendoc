#!/bin/bash
set -e

echo "[entrypoint] Starting OpenDoc entrypoint script..."
echo "[entrypoint] Debug mode: DEBUG=$DEBUG, OPENCODE_LOG_LEVEL=$OPENCODE_LOG_LEVEL"

# Configuration directory
CONFIG_DIR="/root/.config/opendoc"
CONFIG_FILE="$CONFIG_DIR/config.json"

mkdir -p "$CONFIG_DIR"

# Show relevant environment variables (mask sensitive values)
echo "[entrypoint] Environment check:"
echo "  AZURE_OPENAI_API_KEY: ${AZURE_OPENAI_API_KEY:+[SET]}"
echo "  AZURE_OPENAI_API_ENDPOINT: $AZURE_OPENAI_API_ENDPOINT"
echo "  AZURE_RESOURCE_NAME: $AZURE_RESOURCE_NAME"
echo "  AZURE_MODEL_ID: $AZURE_MODEL_ID"
echo "  AZURE_ANTHROPIC_API_KEY: ${AZURE_ANTHROPIC_API_KEY:+[SET]}"
echo "  AZURE_ANTHROPIC_API_ENDPOINT: $AZURE_ANTHROPIC_API_ENDPOINT"
echo "  AZURE_ANTHROPIC_MODEL_ID: $AZURE_ANTHROPIC_MODEL_ID"
echo "  OPENAI_API_KEY: ${OPENAI_API_KEY:+[SET]}"
echo "  OPENAI_MODEL_ID: $OPENAI_MODEL_ID"

# Build OpenCode config from environment variables
if [ -n "$AZURE_OPENAI_API_KEY" ]; then
  # Azure provider configuration
  PROVIDER_ID="azure"
  MODEL_ID="${AZURE_MODEL_ID:-gpt-5.2-chat}"

  # Export env vars that @ai-sdk/azure expects
  export AZURE_API_KEY="$AZURE_OPENAI_API_KEY"
  export AZURE_RESOURCE_NAME="${AZURE_RESOURCE_NAME}"
  echo "[entrypoint] Exported AZURE_API_KEY and AZURE_RESOURCE_NAME for @ai-sdk/azure"

  cat > "$CONFIG_FILE" << EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "model": "${PROVIDER_ID}/${MODEL_ID}",
  "theme": "opencode",
  "autoupdate": false,
  "provider": {
    "azure": {
      "options": {
        "apiKey": "${AZURE_OPENAI_API_KEY}",
        "baseURL": "${AZURE_OPENAI_API_ENDPOINT}",
        "resourceName": "${AZURE_RESOURCE_NAME}",
        "useCompletionUrls": true
      },
      "models": {
        "${MODEL_ID}": {
          "name": "${MODEL_ID}",
          "id": "${MODEL_ID}"
        }
      }
    }
  }
}
EOF
  echo "[entrypoint] Generated Azure OpenCode config: model=${PROVIDER_ID}/${MODEL_ID}"

elif [ -n "$AZURE_ANTHROPIC_API_KEY" ]; then
  # Azure Anthropic Foundry provider configuration
  # AZURE_ANTHROPIC_API_ENDPOINT should end with /anthropic/v1
  # e.g. https://your-resource.services.ai.azure.com/anthropic/v1
  PROVIDER_ID="azure-anthropic"
  MODEL_ID="${AZURE_ANTHROPIC_MODEL_ID:-claude-opus-4-6}"

  # Ensure endpoint ends with /v1 (SDK appends /messages to baseURL)
  ANTHROPIC_ENDPOINT="${AZURE_ANTHROPIC_API_ENDPOINT%/}"
  if [[ "$ANTHROPIC_ENDPOINT" != */v1 ]]; then
    ANTHROPIC_ENDPOINT="${ANTHROPIC_ENDPOINT}/v1"
  fi

  cat > "$CONFIG_FILE" << EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "model": "${PROVIDER_ID}/${MODEL_ID}",
  "theme": "opencode",
  "autoupdate": false,
  "provider": {
    "azure-anthropic": {
      "npm": "@ai-sdk/anthropic",
      "models": {
        "${MODEL_ID}": {
          "name": "${MODEL_ID}",
          "reasoning": true,
          "tool_call": true,
          "attachment": true,
          "temperature": false,
          "limit": { "context": 200000, "output": 128000 },
          "modalities": {
            "input": ["text", "image", "pdf"],
            "output": ["text"]
          }
        }
      },
      "options": {
        "apiKey": "${AZURE_ANTHROPIC_API_KEY}",
        "baseURL": "${ANTHROPIC_ENDPOINT}"
      }
    }
  }
}
EOF
  echo "[entrypoint] Generated Azure Anthropic config: model=${PROVIDER_ID}/${MODEL_ID}"

elif [ -n "$OPENAI_API_KEY" ]; then
  # OpenAI provider configuration
  PROVIDER_ID="openai"
  MODEL_ID="${OPENAI_MODEL_ID:-gpt-4o}"

  cat > "$CONFIG_FILE" << EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "model": "${PROVIDER_ID}/${MODEL_ID}",
  "small_model": "${PROVIDER_ID}/${MODEL_ID}",
  "theme": "opencode",
  "autoupdate": false
}
EOF
  echo "[entrypoint] Generated OpenAI OpenCode config: model=${PROVIDER_ID}/${MODEL_ID}"

else
  echo "[entrypoint] WARNING: No API key found (AZURE_OPENAI_API_KEY, AZURE_ANTHROPIC_API_KEY, or OPENAI_API_KEY)"
fi

# Show generated config for debugging
if [ -f "$CONFIG_FILE" ]; then
  echo "[entrypoint] Config file location: $CONFIG_FILE"
  echo "[entrypoint] Config file contents:"
  cat "$CONFIG_FILE"
  echo ""
fi

# Start opendoc server
echo "[entrypoint] Starting opendoc server..."
exec opendoc serve --hostname "${OPENDOC_HOST:-0.0.0.0}" --port "${OPENDOC_PORT:-4096}" --log-level DEBUG --print-logs
