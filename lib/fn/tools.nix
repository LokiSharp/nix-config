{ ... }:
{
  replaceHyphens =
    str:
    let
      replaced = builtins.replaceStrings [ "-" ] [ "_" ] str;
    in
    replaced;
}
