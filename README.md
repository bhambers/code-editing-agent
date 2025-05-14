# Claude CLI Agent

A command-line interface (CLI) application that lets you interact with Claude AI assistant directly from your terminal, with file system access capabilities.

## Overview

This project implements a CLI agent that connects to Anthropic's Claude API, allowing you to:

- Chat with Claude in your terminal
- Let Claude read files from your local system
- List directory contents
- Edit and create files on your local system

The agent acts as a bridge between your terminal and Claude, providing useful tools that enable Claude to help with file system operations and coding tasks.

## Features

- Interactive CLI chat interface with Claude
- Built-in tools for Claude to interact with your local file system:
  - `read_file`: Read the contents of any file
  - `list_files`: List files and directories in a specified path
  - `edit_file`: Make edits to existing files or create new ones

## Requirements

- Go 1.24 or higher
- An Anthropic API key with access to Claude 3.7 Sonnet

## Installation

1. Make sure you have Go installed on your system
2. Clone this repository
3. Install dependencies:
   ```
   go mod download
   ```
4. Set your Anthropic API key as an environment variable:
   ```
   export ANTHROPIC_API_KEY=your_api_key_here
   ```

## Usage

Run the application with:

```
go run main.go
```

Once running, you can start chatting with Claude and ask it to perform file operations. For example:

- "Show me the contents of main.go"
- "List all files in this directory"
- "Create a new file called example.txt with 'Hello World' as content"
- "Help me understand this codebase"

Press Ctrl+C to exit the application.

## Implementation Details

The agent uses Anthropic's Go SDK to communicate with Claude and implements a set of tools as defined in the Anthropic API. These tools are passed to Claude through the API, allowing it to request specific file operations which are then executed locally by the agent.

## License

[Your license information here]