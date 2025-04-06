import os
import sys
from datetime import datetime

# 出力ファイル（適宜パスを変更可能）
output_file = "args_output.txt"

# ログファイルが存在しなければ作成してヘッダーを書き込む
if not os.path.exists(output_file):
    with open(output_file, "w", encoding="utf-8") as f:
        f.write("=== ログファイル作成 ===\n")

# 引数（スクリプト名を除く）
args = sys.argv[1:]

# 時刻付きでログ出力（追記モード）
with open(output_file, "a", encoding="utf-8") as f:
    f.write(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Args: {args}\n")