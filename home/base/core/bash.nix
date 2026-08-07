{
  programs.bash = {
    enable = true;
    enableCompletion = true;
    bashrcExtra = ''
      export PATH="$HOME/.grok/bin:$PATH:$HOME/bin:$HOME/.local/bin"
    '';
  };
}
