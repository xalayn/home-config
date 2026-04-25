{ pkgs, ... }:
{
  gtk = {
    enable = true;
    
    # Specify a theme that supports dark mode
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  home.packages = with pkgs; [
    gsettings-desktop-schemas
  ];

  # This helps ensure apps respect the dark preference via dconf
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
}