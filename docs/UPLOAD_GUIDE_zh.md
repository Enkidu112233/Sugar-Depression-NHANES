# 新 GitHub 仓库上传说明

1. 公开发布前，先确认你有权分享下载来的 `1127回归.do`，并在 `docs/PROVENANCE.md` 补上原作者、来源和适用的许可或授权。
2. 解压 `NHANES-1127-GitHub.zip`，打开其中的 `NHANES-1127-Replication` 文件夹。
3. 到新 GitHub 仓库的上传页面，把这一层内的内容上传到仓库根目录。提交前确认 `README.md`、`code/`、`data/`、`docs/`、`tools/` 和 `vendor/` 都在根目录，并保留 `.gitignore` 与 `.gitattributes`。`vendor/gologit2/` 包含运行第 4 项所需的 3.2.8 版扩展源码，应一并上传。
4. 提交说明可填 `Add NHANES 1127 replication package`。提交后确认仓库首页显示 README，`data/processed/` 有三个 DTA，`vendor/gologit2/` 有 `gologit2.ado` 与 `gsvy.ado`。

有访问权限的读者可以点 **Code → Download ZIP**。在 Stata 18 中把工作目录设为包含 README 的文件夹，再运行 `do code/00_master.do`。日志在 `output/logs/analysis.log`，导出的数据和结果表在 `output/analysis/`。使用包里的处理后数据不需要原始 XPT。

如需复现清洗过程，按 `data/README.md` 准备原始 XPT，再运行 `do code/00_master.do full`。只重建数据时运行 `do code/00_master.do rebuild`。每次运行会覆盖相同模式下的同名日志和结果文件。
