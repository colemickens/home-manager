{ config, lib, pkgs, ... }:

with lib;

let cfg = config.services.wluma;

in {
  meta.maintainers = [ hm.maintainers.matrss ];

  options.services.wluma = {
    enable = mkEnableOption "wluma";

    package = mkOption {
      type = types.package;
      default = pkgs.wluma;
      defaultText = "pkgs.wluma";
      description = ''
        wluma derivation to use.
      '';
    };

    systemdTarget = mkOption {
      type = types.str;
      default = "graphical-session.target";
      description = ''
        Systemd target to bind to.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      (lib.hm.assertions.assertPlatform "services.wluma" pkgs
        lib.platforms.linux)
    ];

    home.configFile."wluma/config.toml".text = # frm toml;
    ''
    '';

    systemd.user.packages = with pkgs; [ wluma ];
    
    # systemd.user.services.wluma = {
    #   Unit = {
    #     Description = "Automatic brightness adjustment based on screen contents and ALS";
    #     PartOf = [ "graphical-session.target" ];
    #     BindsTo = [ "graphical-session.target" ];
    #     After = [ "graphical-session.target" ];
    #   };

    #   Service = {
    #     ExecStart = let
    #       args = [
    #         "-l ${cfg.latitude}"
    #         "-L ${cfg.longitude}"
        #     "-t ${toString cfg.temperature.night}"
        #     "-T ${toString cfg.temperature.day}"
        #     "-g ${cfg.gamma}"
        #   ];
        # in "${cfg.package}/bin/wluma ${concatStringsSep " " args}";
    #   };

    #   Install = { WantedBy = [ cfg.systemdTarget ]; };
    # };
  };
}
