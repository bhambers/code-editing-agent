#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'anthropic'

ToolDefinition = Struct.new(:name, :description, :input_schema, :function)

class Agent
  attr_reader :tools

  def initialize(client, tools)
    @client, @tools = client, tools
  end

  def run
    conversation = []
    puts "Chat with Claude (use 'ctrl-c' to quit)"

    read_user_input = true
    loop do
      if read_user_input
        print "\e[94mYou\e[0m: "
        user_input = gets.chomp

        conversation << Anthropic::Models::MessageParam.new(
          role: "user",
          content: [Anthropic::Models::TextBlockParam.new(text: user_input)]
        )
      end

      message = run_inference(conversation)
      conversation << Anthropic::Models::MessageParam.new(
        role: message.role,
        content: message.content.map { |content| convert_to_param(content) }
      )

      tool_results = []
      message[:content].each do |content|
        case content[:type]
        when :text
          puts "\e[93mClaude\e[0m: #{content[:text]}"
          read_user_input = true
        when :tool_use
          result = execute_tool(content[:id], content[:name], content[:input])
          conversation << { role: "user", content: [result] }
          read_user_input = false
        else
          puts "\e[91mError\e[0m: Unknown content type #{content[:type].inspect}"
          exit 1
        end
      end
    end
  end

  # Why doesn't the SDK have a built-in way to do this?
  def convert_to_param(content)
    case content.type
    when :text
      Anthropic::Models::TextBlockParam.new(text: content.text)
    when :tool_use
      Anthropic::Models::ToolUseBlockParam.new(
        id: content.id,
        name: content.name,
        input: content.input
      )
    else
      raise "Unknown content type #{content.type.inspect}"
    end
  end

  def execute_tool(id, name, input)
    tool = @tools.find { |tool| tool.name == name }

    unless tool
      puts "\e[92mtool not found\e[0m: #{name}(#{input})"
      return Anthropic::Models::ToolResultBlockParam.new(
        tool_use_id: id,
        content: "tool not found",
        is_error: true
      )
    end

    puts "\e[92mtool\e[0m: #{name}(#{input})"
    begin
      response = tool.function.call(input)
      Anthropic::Models::ToolResultBlockParam.new(
        tool_use_id: id,
        content: response,
        is_error: false
      )
    rescue => e
      puts "\e[91mError\e[0m: #{e.message}"
      Anthropic::Models::ToolResultBlockParam.new(
        tool_use_id: id,
        content: e.message,
        is_error: true
      )
    end
  end

  def run_inference(conversation)
    anthropic_tools = @tools.map do |tool|
      Anthropic::Models::Tool.new(
        name: tool.name,
        description: tool.description,
        input_schema: tool.input_schema
      )
    end

    @client.messages.create(
      model: "claude-3-7-sonnet-latest",
      max_tokens: 1024,
      messages: conversation,
      tools: anthropic_tools
    )
  end
end

# Tool Functions
def read_file(params)
  path = params[:path]
  raise "Path cannot be empty" if path.nil? || path.empty?

  begin
    File.read(path)
  rescue Errno::ENOENT
    raise "File not found"
  end
end

def list_files(params)
  path = params[:path] || "."
  
  files = Dir.glob("#{path}/**/*").map do |file|
    File.directory?(file) ? "#{file}/" : file
  end
  files.to_json
end

def edit_file(params)
  path, old_str, new_str = params[:path], params[:old_str] || "", params[:new_str] || ""

  raise "Path cannot be empty" if path.nil? || path.empty?
  raise "old_str and new_str cannot both be empty" if old_str == "" && new_str == ""
  raise "old_str and new_str cannot be the same" if old_str == new_str

  return create_new_file(path, new_str) if !File.exist?(path) && old_str == ""

  new_content = File.read(path).gsub(old_str, new_str)
  File.write(path, new_content)
  "OK"
end

def create_new_file(file_path, content)
  dir = File.dirname(file_path)
  FileUtils.mkdir_p(dir) if dir != "."
  File.write(file_path, content)
  "Successfully created file #{file_path}"
end

# Schema Generation (simplified for Ruby version)
def generate_schema(properties)
  {
    "type" => "object",
    "properties" => properties,
    "required" => properties.keys
  }
end

# Tool Definitions
read_file_schema = generate_schema({
  "path" => {
    "type" => "string",
    "description" => "The relative path of a file in the working directory."
  }
})

list_files_schema = generate_schema({
  "path" => {
    "type" => "string",
    "description" => "Optional relative path to list files from. Defaults to current directory if not provided."
  }
})

edit_file_schema = generate_schema({
  "path" => {
    "type" => "string",
    "description" => "The path to the file"
  },
  "old_str" => {
    "type" => "string",
    "description" => "Text to search for - must match exactly and must only have one match exactly"
  },
  "new_str" => {
    "type" => "string",
    "description" => "Text to replace old_str with"
  }
})

read_file_definition = ToolDefinition.new(
  "read_file",
  "Read the contents of a given relative file path. Use this when you want to see what's inside a file. Do not use this with directory names.",
  read_file_schema,
  method(:read_file)
)

list_files_definition = ToolDefinition.new(
  "list_files",
  "List files and directories at a given path. If no path is provided, lists files in the current directory.",
  list_files_schema,
  method(:list_files)
)

edit_file_definition = ToolDefinition.new(
  "edit_file",
  "Make edits to a text file. Replaces 'old_str' with 'new_str' in the given file. 'old_str' and 'new_str' MUST be different from each other. If the file specified with path doesn't exist, it will be created.",
  edit_file_schema,
  method(:edit_file)
)

client = Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"])
tools = [read_file_definition, list_files_definition, edit_file_definition]
agent = Agent.new(client, tools)

agent.run
