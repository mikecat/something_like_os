OSっぽい何か
============

BIOSからロードされ、いろいろするプログラムです。

### 前作「OS非依存プログラム集」との違い

* 前作は主にgccを使用、今回はnasmなどを使用
* 前作はビルドに独自スクリプトを使用、今回はできるだけ既存のソフトウェアを利用

([OS非依存プログラム集](https://github.com/mikecat/no_os_programs))

### 警告

無保証です。利用する際は自己責任でお願いします。

このプログラムを実行したことで、万が一パソコンやデータが破壊されても、作者は一切責任を負いません。

Programs here are with NO WARRENTLY. If you want to use these programs, use them at YOUR OWN LISK.

### 参考サイト

* [アセンブラ入門](http://www5c.biglobe.ne.jp/~ecb/assembler/assembler00.html)  
  x86命令の簡単なリファレンスとして便利。
* [０から作るOS開発](http://softwaretechnique.jp/OS_Development/index.html)  
  メモリマップ、LBA(最初のセクタを0として何セクタ目か)からCHS(BIOSでディスクにアクセスするときのパラメータ)への変換方法など。
* [FAT ファイル・システムの覚え書き](http://www.geocities.co.jp/SiliconValley-PaloAlto/2038/fat.html)  
  MBR、BPB、RDEなどのフォーマット。
* [(AT)BIOS - os-wiki](http://oswiki.osask.jp/?(AT)BIOS)  
  BIOSファンクションの簡単なリファレンス。
