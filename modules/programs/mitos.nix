{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkIf
    mkOption
    types
    ;

  cfg = config.programs.mitos;
  tomlFormat = pkgs.formats.toml { };
in
{
  # meta.maintainers = [ lib.maintainers.Philipp-M ];

  options.programs.mitos = {
    enable = lib.mkEnableOption "mitos text editor";

    package = lib.mkPackageOption pkgs "mitos" {
      nullable = true;
      example = "pkgs.evil-mitos";
    };

    extraPackages = mkOption {
      type = with types; listOf package;
      default = [ ];
      example = literalExpression "[ pkgs.marksman ]";
      description = "Extra packages available to hx.";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Extra lines to be appended to the config file.
        Use this if you would like to maintain order for mitos settings (eg. for minor modes)
      '';
      example = literalExpression ''
        [keys.normal.g] # Reverse Alphabetical Order
        G = "goto_file_end"
        g = "goto_file_start"
      '';
    };

    defaultEditor = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to configure {command}`hx` as the default
        editor using the {env}`EDITOR` and {env}`VISUAL`
        environment variables.
      '';
    };

    settings = mkOption {
      inherit (tomlFormat) type;
      default = { };
      example = {
        theme = "base16";
        editor = {
          line-number = "relative";
          lsp.display-messages = true;
        };
        keys.normal = {
          space.space = "file_picker";
          space.w = ":w";
          space.q = ":q";
          esc = [
            "collapse_selection"
            "keep_primary_selection"
          ];
        };
      };
      description = ''
        Configuration written to
        {file}`$XDG_CONFIG_HOME/mitos/config.toml`.

        See <FIXME>
        for the full list of options.
      '';
    };

    languages = mkOption {
      type =
        with types;
        coercedTo (listOf tomlFormat.type) (language: { inherit language; }) (
          addCheck tomlFormat.type builtins.isAttrs
        );
      default = { };
      example = literalExpression ''
        {
          language-server.typescript-language-server = {
            command = "''${pkgs.typescript-language-server}/bin/typescript-language-server";
            args = [ "--stdio" ];
          };

          language = [{
            name = "rust";
            auto-format = false;
          }];
        }
      '';
      description = ''
        Language specific configuration at
        {file}`$XDG_CONFIG_HOME/mitos/languages.toml`.

        See <FIXME>
        for more information.
      '';
    };

    ignores = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        ".build/"
        "!.gitignore"
      ];
      description = ''
        List of paths that should be globally ignored for file picker.
        Supports the usual ignore and negative ignore (unignore) rules used in `.gitignore` files.
      '';
    };

    themes = mkOption {
      type = types.attrsOf (
        types.oneOf [
          tomlFormat.type
          types.path
          types.lines
        ]
      );
      default = { };
      example = literalExpression ''
        {
          base16 = let
            transparent = "none";
            gray = "#665c54";
            dark-gray = "#3c3836";
            white = "#fbf1c7";
            black = "#282828";
            red = "#fb4934";
            green = "#b8bb26";
            yellow = "#fabd2f";
            orange = "#fe8019";
            blue = "#83a598";
            magenta = "#d3869b";
            cyan = "#8ec07c";
          in {
            "ui.menu" = transparent;
            "ui.menu.selected" = { modifiers = [ "reversed" ]; };
            "ui.linenr" = { fg = gray; bg = dark-gray; };
            "ui.popup" = { modifiers = [ "reversed" ]; };
            "ui.linenr.selected" = { fg = white; bg = black; modifiers = [ "bold" ]; };
            "ui.selection" = { fg = black; bg = blue; };
            "ui.selection.primary" = { modifiers = [ "reversed" ]; };
            "comment" = { fg = gray; };
            "ui.statusline" = { fg = white; bg = dark-gray; };
            "ui.statusline.inactive" = { fg = dark-gray; bg = white; };
            "ui.help" = { fg = dark-gray; bg = white; };
            "ui.cursor" = { modifiers = [ "reversed" ]; };
            "variable" = red;
            "variable.builtin" = orange;
            "constant.numeric" = orange;
            "constant" = orange;
            "attributes" = yellow;
            "type" = yellow;
            "ui.cursor.match" = { fg = yellow; modifiers = [ "underlined" ]; };
            "string" = green;
            "variable.other.member" = red;
            "constant.character.escape" = cyan;
            "function" = blue;
            "constructor" = blue;
            "special" = blue;
            "keyword" = magenta;
            "label" = magenta;
            "namespace" = blue;
            "diff.plus" = green;
            "diff.delta" = yellow;
            "diff.minus" = red;
            "diagnostic" = { modifiers = [ "underlined" ]; };
            "ui.gutter" = { bg = black; };
            "info" = blue;
            "hint" = dark-gray;
            "debug" = dark-gray;
            "warning" = yellow;
            "error" = red;
          };
        }
      '';
      description = ''
        Each theme is written to
        {file}`$XDG_CONFIG_HOME/mitos/themes/theme-name.toml`.
        Where the name of each attribute is the theme-name (in the example "base16").

        See <FIXME>
        for the full list of options.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = lib.singleton {
      assertion = cfg.extraPackages != [ ] -> cfg.package != null;
      message = "programs.mitos.extraPackages require programs.mitos.package to not be null";
    };

    warnings = lib.optional (lib.any builtins.isList options.programs.mitos.languages.definitions) (
      lib.hm.deprecations.mkDeprecatedOptionValueWarning {
        option = [
          "programs"
          "mitos"
          "languages"
        ];
        old = "a list";
        replacement = "`programs.mitos.languages.language`";
        details = ''
          This option now generates the whole languages.toml file instead of just the language array in that file.

          Use:
            programs.mitos.languages = { language = <languages list>; }
        '';
      }
    );

    home.packages = lib.mkIf (cfg.package != null) (
      if cfg.extraPackages != [ ] then
        [
          (pkgs.symlinkJoin {
            name = "${lib.getName cfg.package}-wrapped-${lib.getVersion cfg.package}";
            paths = [ cfg.package ];
            preferLocalBuild = true;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/hx \
                --suffix PATH : ${lib.makeBinPath cfg.extraPackages}
            '';
          })
        ]
      else
        [ cfg.package ]
    );

    home.sessionVariables = mkIf cfg.defaultEditor {
      EDITOR = "hx";
      VISUAL = "hx";
    };

    xdg.configFile =
      let
        pkillPrefix = if pkgs.stdenv.hostPlatform.isDarwin then "/usr" else pkgs.procps;
        onChange = "${pkillPrefix}/bin/pkill -USR1 -u $USER -x '(hx|\\.hx-wrapped)' || true";

        settings =
          let
            hasSettings = cfg.settings != { };
            hasExtraConfig = cfg.extraConfig != "";
          in
          {
            "mitos/config.toml" = mkIf (hasSettings || hasExtraConfig) {
              inherit onChange;
              source =
                let
                  configFile = tomlFormat.generate "config.toml" cfg.settings;
                  extraConfigFile = pkgs.writeText "extra-config.toml" (
                    lib.optionalString hasSettings "\n" + cfg.extraConfig
                  );
                in
                pkgs.runCommand "mitos-config.toml" { } ''
                  cat ${configFile} ${extraConfigFile} >> $out
                '';
            };
            "mitos/languages.toml" = mkIf (cfg.languages != { }) {
              inherit onChange;
              source = tomlFormat.generate "mitos-languages-config" cfg.languages;
            };
            "mitos/ignore" = mkIf (cfg.ignores != [ ]) {
              text = lib.concatStringsSep "\n" cfg.ignores + "\n";
            };
          };

        themes = lib.mapAttrs' (
          n: v:
          lib.nameValuePair "mitos/themes/${n}.toml" {
            inherit onChange;
            source =
              if lib.isString v then
                pkgs.writeText "mitos-theme-${n}" v
              else if builtins.isPath v || lib.isStorePath v then
                v
              else
                tomlFormat.generate "mitos-theme-${n}" v;
          }
        ) cfg.themes;
      in
      settings // themes;
  };
}
