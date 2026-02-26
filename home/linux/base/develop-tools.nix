{
  pkgs,
  pkgs-unstable,
  ...
}:
{
  home.packages =
    with pkgs;
    [
      # Rust 核心工具
      rustc
      cargo
      rust-analyzer
      rustfmt
      clippy

      # 调试与链接加速
      lldb # 调试必备
      lld # 链接加速器 (推荐使用)

      # C/C++ 工具链 (处理 C 扩展依赖)
      clang
      pkg-config # 也是 Rust 开发中经常需要的
    ]
    ++ [
      nodejs_24
      typescript
      typescript-language-server
    ]
    ++ [
      python3
      ruff
      uv
    ]
    ++ [
      pkgs-unstable.claude-code
    ];
}
