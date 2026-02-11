{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  # https://devenv.sh/basics/
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = [
    pkgs.git
    pkgs.nodejs
    pkgs.nodePackages.pnpm
    pkgs.awscli2
    pkgs.claude-code
  ];

  claude.code.enable = true;

  # Enable formatters via git-hooks
  git-hooks.hooks = {
    nixfmt.enable = true;
    # prettier.enable = true;
  };

  claude.code.hooks = {
    # Protect sensitive files (PreToolUse hook)
    protect-secrets = {
      enable = true;
      name = "Protect sensitive files";
      hookType = "PreToolUse";
      matcher = "^(Edit|MultiEdit|Write)$";
      command = ''
        # Read the JSON input from stdin
        json=$(cat)
        file_path=$(echo "$json" | jq -r '.file_path // empty')

        if [[ "$file_path" =~ \.(env|secret)$ ]]; then
          echo "Error: Cannot edit sensitive files"
          exit 1
        fi
      '';
    };

    # Run tests after changes (PostToolUse hook)
    test-on-save = {
      enable = true;
      name = "Run tests after edit";
      hookType = "PostToolUse";
      matcher = "^(Edit|MultiEdit|Write)$";
      command = ''
        # Read the JSON input from stdin
        json=$(cat)
        file_path=$(echo "$json" | jq -r '.file_path // empty')

        if [[ "$file_path" =~ \.rs$ ]]; then
          cargo test
        fi
      '';
    };

    # Type checking (PostToolUse hook)
    typecheck = {
      enable = true;
      name = "Run type checking";
      hookType = "PostToolUse";
      matcher = "^(Edit|MultiEdit|Write)$";
      command = ''
        # Read the JSON input from stdin
        json=$(cat)
        file_path=$(echo "$json" | jq -r '.file_path // empty')

        if [[ "$file_path" =~ \.ts$ ]]; then
          npm run typecheck
        fi
      '';
    };

    # Log notifications (Notification hook)
    log-notifications = {
      enable = true;
      name = "Log Claude notifications";
      hookType = "Notification";
      command = ''echo "Claude notification received" >> claude.log'';
    };

    # Track completion (Stop hook)
    track-completion = {
      enable = true;
      name = "Track when Claude finishes";
      hookType = "Stop";
      command = ''echo "Claude finished at $(date)" >> claude-sessions.log'';
    };

    # Subagent monitoring (SubagentStop hook)
    subagent-complete = {
      enable = true;
      name = "Log subagent completion";
      hookType = "SubagentStop";
      command = ''echo "Subagent task completed" >> subagent.log'';
    };
  };

  claude.code.mcpServers = {
    # Local devenv MCP server
    devenv = {
      type = "stdio";
      command = "devenv";
      args = [ "mcp" ];
      env = {
        DEVENV_ROOT = config.devenv.root;
      };
    };

    svelte = {
      type = "stdio";
      command = "npx";
      args = [
        "-y"
        "@sveltejs/mcp"
      ];
    };

    shadcn = {
      type = "stdio";
      command = "npx";
      args = [
        "shadcn@latest"
        "mcp"
      ];
    };

    playwright = {
      type = "stdio";
      command = "npx";
      args = [ "@playwright/mcp@latest" ];
    };
  };

  # https://devenv.sh/languages/
  # languages.rust.enable = true;

  # https://devenv.sh/processes/
  # processes.dev.exec = "${lib.getExe pkgs.watchexec} -n -- ls -la";

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/scripts/
  scripts.hello.exec = ''
    echo hello from $GREET
  '';

  # https://devenv.sh/basics/
  enterShell = ''
    hello         # Run scripts directly
    git --version # Use packages
  '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';

  # https://devenv.sh/git-hooks/
  # git-hooks.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
